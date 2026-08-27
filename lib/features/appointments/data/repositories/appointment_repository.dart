import 'dart:async';

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
  // ============================================================
  // CONFIGURAÇÕES
  // ============================================================

  /// Os horários são bloqueados internamente em blocos de 15 minutos.
  static const int bookingSlotMinutes = 15;

  /// Tempo máximo reservado para o cliente realizar o pagamento.
  static const int paymentReservationMinutes = 3;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // AGENDAMENTOS DO USUÁRIO
  // ============================================================

  Stream<List<BarbershopAppointment>> watchCurrentUserAppointments() {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream.error(
        Exception('Nenhum usuário autenticado.'),
      );
    }

    return _firestore
        .collection('appointments')
        .where(
          'userId',
          isEqualTo: user.uid,
        )
        .snapshots()
        .map((snapshot) {
          final appointments = snapshot.docs
              .map(
                BarbershopAppointment.fromDocument,
              )
              .toList();

          appointments.sort(
            (a, b) => a.startAt.compareTo(
              b.startAt,
            ),
          );

          return appointments;
        });
  }

  // ============================================================
  // OBSERVAR SLOTS OCUPADOS
  // ============================================================
  //
  // REGRAS:
  //
  // confirmed
  //   -> sempre ocupado
  //
  // pending_payment + ainda válido
  //   -> ocupado
  //
  // pending_payment + expirado
  //   -> livre
  //
  // cancelled / expired
  //   -> livre
  //
  // Slots antigos sem campo "status"
  //   -> considerados ocupados por segurança
  //
  // O Timer abaixo NÃO gera novas leituras no Firestore.
  // Ele apenas reavalia localmente os documentos que o snapshot
  // já trouxe. Assim o horário reaparece automaticamente quando
  // paymentExpiresAt vencer.
  // ============================================================

  Stream<Set<int>> watchBookedSlotMinutes({
    required String professionalId,
    required DateTime date,
  }) {
    final dateKey = _dateKey(date);

    final slotsQuery = _firestore
        .collection('professionals')
        .doc(professionalId)
        .collection('booked_days')
        .doc(dateKey)
        .collection('slots');

    StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>
    >?
    firestoreSubscription;

    Timer? expirationTimer;

    var latestDocuments =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    late final StreamController<Set<int>> controller;

    Set<int> calculateOccupiedSlots() {
      final now = DateTime.now();

      final occupiedSlots = <int>{};

      for (final document in latestDocuments) {
        final data = document.data();

        final startMinutes =
            (data['startMinutes'] as num?)?.toInt();

        if (startMinutes == null) {
          continue;
        }

        final status = (data['status'] as String?)?.trim();

        // ======================================================
        // COMPATIBILIDADE COM SLOTS ANTIGOS
        // ======================================================
        //
        // Antes da implementação de pending_payment os slots
        // não possuíam o campo "status".
        //
        // Por segurança eles continuam sendo considerados
        // ocupados.
        // ======================================================

        if (status == null || status.isEmpty) {
          occupiedSlots.add(startMinutes);
          continue;
        }

        // ======================================================
        // AGENDAMENTO CONFIRMADO
        // ======================================================

        if (status == 'confirmed') {
          occupiedSlots.add(startMinutes);
          continue;
        }

        // ======================================================
        // RESERVA PENDENTE DE PAGAMENTO
        // ======================================================

        if (status == 'pending_payment') {
          final paymentExpiresAtValue =
              data['paymentExpiresAt'];

          if (paymentExpiresAtValue is! Timestamp) {
            // Falha segura:
            //
            // se um documento pending_payment estiver malformado,
            // não liberamos o horário automaticamente.
            occupiedSlots.add(startMinutes);
            continue;
          }

          final paymentExpiresAt =
              paymentExpiresAtValue.toDate();

          // Reserva ainda está válida.
          if (paymentExpiresAt.isAfter(now)) {
            occupiedSlots.add(startMinutes);
          }

          // Se paymentExpiresAt <= agora:
          //
          // NÃO adicionamos o slot.
          //
          // Portanto ele volta a aparecer como disponível.
          continue;
        }

        // ======================================================
        // CANCELADO OU EXPIRADO
        // ======================================================

        if (status == 'cancelled' ||
            status == 'expired') {
          continue;
        }

        // ======================================================
        // STATUS DESCONHECIDO
        // ======================================================
        //
        // Por segurança, qualquer status que o app ainda não
        // reconheça continua bloqueando o horário.
        // ======================================================

        occupiedSlots.add(startMinutes);
      }

      return occupiedSlots;
    }

    void emitCurrentSlots() {
      if (controller.isClosed) {
        return;
      }

      controller.add(
        calculateOccupiedSlots(),
      );
    }

    controller = StreamController<Set<int>>(
      onListen: () {
        // ======================================================
        // FIRESTORE
        // ======================================================

        firestoreSubscription =
            slotsQuery.snapshots().listen(
              (snapshot) {
                latestDocuments = snapshot.docs;

                emitCurrentSlots();
              },
              onError: (
                Object error,
                StackTrace stackTrace,
              ) {
                if (!controller.isClosed) {
                  controller.addError(
                    error,
                    stackTrace,
                  );
                }
              },
            );

        // ======================================================
        // REAVALIAR EXPIRAÇÕES
        // ======================================================
        //
        // Não consulta o Firestore novamente.
        //
        // Apenas olha o paymentExpiresAt dos documentos que já
        // estão na memória.
        // ======================================================

        expirationTimer = Timer.periodic(
          const Duration(seconds: 5),
          (_) {
            emitCurrentSlots();
          },
        );
      },

      onCancel: () async {
        expirationTimer?.cancel();

        await firestoreSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  // ============================================================
  // CRIAR AGENDAMENTO / RESERVA TEMPORÁRIA
  // ============================================================

  Future<String> createAppointment({
    required BarbershopService service,
    required Professional professional,
    required DateTime date,
    required int startMinutes,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Nenhum usuário autenticado.',
      );
    }

    if (service.durationMinutes <= 0) {
      throw Exception(
        'Duração do serviço inválida.',
      );
    }

    if (service.priceCents <= 0) {
      throw Exception(
        'Valor do serviço inválido.',
      );
    }

    // ==========================================================
    // NORMALIZAR DATA
    // ==========================================================

    final normalizedDate = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final dateKey = _dateKey(
      normalizedDate,
    );

    final endMinutes =
        startMinutes +
        service.durationMinutes;

    if (startMinutes < 0 ||
        startMinutes >= 1440 ||
        endMinutes <= startMinutes ||
        endMinutes > 1440) {
      throw Exception(
        'Horário de agendamento inválido.',
      );
    }

    // ==========================================================
    // HORÁRIO DO ATENDIMENTO
    // ==========================================================

    final startAt = normalizedDate.add(
      Duration(
        minutes: startMinutes,
      ),
    );

    final endAt = normalizedDate.add(
      Duration(
        minutes: endMinutes,
      ),
    );

    // ==========================================================
    // EXPIRAÇÃO DA RESERVA
    // ==========================================================

    final paymentExpiresAt = DateTime.now().add(
      const Duration(
        minutes: paymentReservationMinutes,
      ),
    );

    // ==========================================================
    // REFERÊNCIA DO AGENDAMENTO
    // ==========================================================

    final appointmentReference = _firestore
        .collection('appointments')
        .doc();

    final batch = _firestore.batch();

    // ==========================================================
    // AGENDAMENTO PENDENTE
    // ==========================================================

    batch.set(
      appointmentReference,
      {
        'userId': user.uid,

        'serviceId': service.id,
        'serviceName': service.name,

        'professionalId': professional.id,
        'professionalName': professional.name,

        'dateKey': dateKey,

        'startMinutes': startMinutes,
        'endMinutes': endMinutes,

        'durationMinutes':
            service.durationMinutes,

        'priceCents':
            service.priceCents,

        'status':
            'pending_payment',

        'paymentExpiresAt':
            Timestamp.fromDate(
          paymentExpiresAt,
        ),

        'startAt':
            Timestamp.fromDate(
          startAt,
        ),

        'endAt':
            Timestamp.fromDate(
          endAt,
        ),

        'createdAt':
            FieldValue.serverTimestamp(),
      },
    );

    // ==========================================================
    // LOCKS DE 15 MINUTOS
    // ==========================================================

    final slotStarts = _slotStartsForInterval(
      startMinutes: startMinutes,
      endMinutes: endMinutes,
    );

    for (final slotStart in slotStarts) {
      final slotId = slotStart
          .toString()
          .padLeft(
            4,
            '0',
          );

      final slotReference = _firestore
          .collection('professionals')
          .doc(professional.id)
          .collection('booked_days')
          .doc(dateKey)
          .collection('slots')
          .doc(slotId);

      batch.set(
        slotReference,
        {
          'appointmentId':
              appointmentReference.id,

          'professionalId':
              professional.id,

          'dateKey':
              dateKey,

          'startMinutes':
              slotStart,

          'status':
              'pending_payment',

          'paymentExpiresAt':
              Timestamp.fromDate(
            paymentExpiresAt,
          ),

          'createdAt':
              FieldValue.serverTimestamp(),
        },
      );
    }

    // ==========================================================
    // COMMIT
    // ==========================================================

    try {
      await batch.commit();

      return appointmentReference.id;
    } on FirebaseException catch (e) {
      debugPrintFirebaseError(e);

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

    final cancellableStatuses = <String>{
      'pending_payment',
      'confirmed',
    };

    if (!cancellableStatuses.contains(
      appointment.status,
    )) {
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

    batch.update(
      appointmentReference,
      {
        'status':
            'cancelled',

        'cancelledAt':
            FieldValue.serverTimestamp(),
      },
    );

    // ==========================================================
    // LIBERAR SLOTS
    // ==========================================================

    final slotStarts = _slotStartsForInterval(
      startMinutes:
          appointment.startMinutes,

      endMinutes:
          appointment.endMinutes,
    );

    for (final slotStart in slotStarts) {
      final slotId = slotStart
          .toString()
          .padLeft(
            4,
            '0',
          );

      final slotReference = _firestore
          .collection('professionals')
          .doc(
            appointment.professionalId,
          )
          .collection('booked_days')
          .doc(
            appointment.dateKey,
          )
          .collection('slots')
          .doc(slotId);

      batch.delete(
        slotReference,
      );
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

  String _dateKey(
    DateTime date,
  ) {
    final year = date.year
        .toString()
        .padLeft(
          4,
          '0',
        );

    final month = date.month
        .toString()
        .padLeft(
          2,
          '0',
        );

    final day = date.day
        .toString()
        .padLeft(
          2,
          '0',
        );

    return '$year-$month-$day';
  }

  void debugPrintFirebaseError(
    FirebaseException error,
  ) {
    // ignore: avoid_print
    print(
      'APPOINTMENT FIREBASE ERROR -> '
      '${error.code}: ${error.message}',
    );
  }
}