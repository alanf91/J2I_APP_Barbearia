import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

class AppointmentRepository {
  static const int bookingSlotMinutes = 15;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppointmentRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // OBSERVAR HORÁRIOS JÁ OCUPADOS
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
    // DOCUMENTO PRINCIPAL DO AGENDAMENTO
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
    // BLOQUEIOS DE 15 MINUTOS
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
}
