import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class AppointmentConflictException implements Exception {
  final String message;

  const AppointmentConflictException([
    this.message = 'Este horário não está mais disponível.',
  ]);

  @override
  String toString() => message;
}

class AppointmentCancellationException implements Exception {
  final String message;

  const AppointmentCancellationException([
    this.message = 'Não foi possível cancelar este agendamento.',
  ]);

  @override
  String toString() => message;
}

class AppointmentRepository {
  static const int bookingSlotMinutes = 15;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppointmentRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // AGENDAMENTOS DO USUÁRIO
  // ============================================================

  Stream<List<BarbershopAppointment>> watchCurrentUserAppointments() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(Exception('Nenhum usuário autenticado.'));
    }

    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final appointments = snapshot.docs
              .map(BarbershopAppointment.fromDocument)
              .toList();

          appointments.sort((a, b) => a.startAt.compareTo(b.startAt));

          return appointments;
        });
  }

  // ============================================================
  // OBSERVAR SLOTS OCUPADOS
  // ============================================================

  Stream<Set<int>> watchBookedSlotMinutes({
    required String professionalId,
    required DateTime date,
  }) {
    final dateKey = _dateKey(date);

    return _firestore
        .collection('professionals')
        .doc(professionalId)
        .collection('booked_days')
        .doc(dateKey)
        .collection('slots')
        .snapshots()
        .map((snapshot) {
          final slots = <int>{};

          for (final document in snapshot.docs) {
            final data = document.data();

            final startMinutes = (data['startMinutes'] as num?)?.toInt();

            if (startMinutes != null) {
              slots.add(startMinutes);
            }
          }

          return slots;
        });
  }

  // ============================================================
  // CRIAR AGENDAMENTO
  // ============================================================

  Future<String> createAppointment({
    required BarbershopService service,
    required Professional professional,
    required DateTime date,
    required int startMinutes,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Nenhum usuário autenticado.');
    }

    if (service.durationMinutes <= 0) {
      throw Exception('Duração do serviço inválida.');
    }

    final normalizedDate = DateTime(date.year, date.month, date.day);

    final dateKey = _dateKey(normalizedDate);

    final endMinutes = startMinutes + service.durationMinutes;

    if (startMinutes < 0 ||
        startMinutes >= 1440 ||
        endMinutes <= startMinutes ||
        endMinutes > 1440) {
      throw Exception('Horário de agendamento inválido.');
    }

    final startAt = normalizedDate.add(Duration(minutes: startMinutes));

    final endAt = normalizedDate.add(Duration(minutes: endMinutes));

    final appointmentReference = _firestore.collection('appointments').doc();

    final batch = _firestore.batch();

    // ==========================================================
    // AGENDAMENTO
    // ==========================================================

    batch.set(appointmentReference, {
      'userId': user.uid,
      'serviceId': service.id,
      'serviceName': service.name,
      'professionalId': professional.id,
      'professionalName': professional.name,
      'dateKey': dateKey,
      'startMinutes': startMinutes,
      'endMinutes': endMinutes,
      'durationMinutes': service.durationMinutes,
      'priceCents': service.priceCents,
      'status': 'confirmed',
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // ==========================================================
    // LOCKS DE 15 MINUTOS
    // ==========================================================

    final slotStarts = _slotStartsForInterval(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );

    for (final slotStart in slotStarts) {
      final slotId = slotStart.toString().padLeft(4, '0');

      final slotReference = _firestore
          .collection('professionals')
          .doc(professional.id)
          .collection('booked_days')
          .doc(dateKey)
          .collection('slots')
          .doc(slotId);

      batch.set(slotReference, {
        'appointmentId': appointmentReference.id,
        'professionalId': professional.id,
        'dateKey': dateKey,
        'startMinutes': slotStart,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();

      return appointmentReference.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AppointmentConflictException();
      }

      rethrow;
    }
  }

  // ============================================================
  // CANCELAR AGENDAMENTO
  // ============================================================

  Future<void> cancelAppointment({
    required BarbershopAppointment appointment,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AppointmentCancellationException(
        'Nenhum usuário autenticado.',
      );
    }

    if (appointment.userId != user.uid) {
      throw const AppointmentCancellationException(
        'Este agendamento não pertence ao usuário atual.',
      );
    }

    if (appointment.status != 'confirmed') {
      throw const AppointmentCancellationException(
        'Este agendamento não pode mais ser cancelado.',
      );
    }

    final now = DateTime.now();

    if (!appointment.startAt.isAfter(now)) {
      throw const AppointmentCancellationException(
        'Não é possível cancelar um atendimento que já começou.',
      );
    }

    final appointmentReference = _firestore
        .collection('appointments')
        .doc(appointment.id);

    final batch = _firestore.batch();

    // ==========================================================
    // ALTERAR STATUS
    // ==========================================================

    batch.update(appointmentReference, {
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    // ==========================================================
    // LIBERAR OS SLOTS
    // ==========================================================

    final slotStarts = _slotStartsForInterval(
      startMinutes: appointment.startMinutes,
      endMinutes: appointment.endMinutes,
    );

    for (final slotStart in slotStarts) {
      final slotId = slotStart.toString().padLeft(4, '0');

      final slotReference = _firestore
          .collection('professionals')
          .doc(appointment.professionalId)
          .collection('booked_days')
          .doc(appointment.dateKey)
          .collection('slots')
          .doc(slotId);

      batch.delete(slotReference);
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrintFirebaseError(e);

      throw const AppointmentCancellationException();
    }
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  List<int> _slotStartsForInterval({
    required int startMinutes,
    required int endMinutes,
  }) {
    final slots = <int>[];

    var current = startMinutes;

    while (current < endMinutes) {
      slots.add(current);

      current += bookingSlotMinutes;
    }

    return slots;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  void debugPrintFirebaseError(FirebaseException error) {
    // ignore: avoid_print
    print(
      'APPOINTMENT FIREBASE ERROR -> '
      '${error.code}: ${error.message}',
    );
  }
}
