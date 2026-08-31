import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

// ============================================================
// CONFLITO DE HORÁRIO
// ============================================================

class AppointmentConflictException
    implements Exception {
  final String message;

  const AppointmentConflictException([
    this.message =
        'Este horário não está mais disponível.',
  ]);

  @override
  String toString() => message;
}

// ============================================================
// CANCELAMENTO
// ============================================================

class AppointmentCancellationException
    implements Exception {
  final String message;

  const AppointmentCancellationException([
    this.message =
        'Não foi possível cancelar este agendamento.',
  ]);

  @override
  String toString() => message;
}

// ============================================================
// REAGENDAMENTO
// ============================================================

class AppointmentRescheduleException
    implements Exception {
  final String message;
  final String? code;

  const AppointmentRescheduleException(
    this.message, {
    this.code,
  });

  @override
  String toString() => message;
}

// ============================================================
// REPOSITORY
// ============================================================

class AppointmentRepository {
  // ============================================================
  // CONFIGURAÇÕES
  // ============================================================

  /// Android Emulator -> computador Windows.
  static const String _baseUrl =
      'http://10.0.2.2:8080';

  /// Os horários são bloqueados internamente
  /// em blocos de 15 minutos.
  static const int bookingSlotMinutes =
      15;

  /// Tempo máximo reservado para pagamento.
  ///
  /// IMPORTANTE:
  /// valor oficial do projeto = 2 minutos.
  static const int paymentReservationMinutes =
      2;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AppointmentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore =
           firestore ??
           FirebaseFirestore.instance,
       _auth =
           auth ??
           FirebaseAuth.instance;

  // ============================================================
  // AGENDAMENTOS DO USUÁRIO
  // ============================================================

  Stream<List<BarbershopAppointment>>
  watchCurrentUserAppointments() {
    final user =
        _auth.currentUser;

    if (user == null) {
      return Stream.error(
        Exception(
          'Nenhum usuário autenticado.',
        ),
      );
    }

    return _firestore
        .collection(
          'appointments',
        )
        .where(
          'userId',
          isEqualTo:
              user.uid,
        )
        .snapshots()
        .map(
          (snapshot) {
            final appointments =
                snapshot.docs
                    .map(
                      BarbershopAppointment
                          .fromDocument,
                    )
                    .toList();

            appointments.sort(
              (a, b) =>
                  a.startAt
                      .compareTo(
                    b.startAt,
                  ),
            );

            return appointments;
          },
        );
  }

  // ============================================================
  // OBSERVAR SLOTS OCUPADOS
  // ============================================================
  //
  // confirmed
  //   -> sempre ocupado
  //
  // pending_payment + válido
  //   -> ocupado
  //
  // pending_payment + expirado
  //   -> livre
  //
  // cancelled / expired
  //   -> livre
  //
  // Slots antigos sem status
  //   -> ocupados por segurança.
  // ============================================================

  Stream<Set<int>> watchBookedSlotMinutes({
    required String professionalId,
    required DateTime date,
  }) {
    final dateKey =
        _dateKey(
      date,
    );

    final slotsQuery =
        _firestore
            .collection(
              'professionals',
            )
            .doc(
              professionalId,
            )
            .collection(
              'booked_days',
            )
            .doc(
              dateKey,
            )
            .collection(
              'slots',
            );

    StreamSubscription<
      QuerySnapshot<Map<String, dynamic>>
    >?
    firestoreSubscription;

    Timer? expirationTimer;

    var latestDocuments =
        <
          QueryDocumentSnapshot<
            Map<String, dynamic>
          >
        >[];

    late final StreamController<
      Set<int>
    >
    controller;

    Set<int>
    calculateOccupiedSlots() {
      final now =
          DateTime.now();

      final occupiedSlots =
          <int>{};

      for (
        final document
        in latestDocuments
      ) {
        final data =
            document.data();

        final startMinutes =
            (
              data['startMinutes']
                  as num?
            )?.toInt();

        if (
          startMinutes ==
          null
        ) {
          continue;
        }

        final status =
            (
              data['status']
                  as String?
            )?.trim();

        // ======================================================
        // COMPATIBILIDADE COM SLOTS ANTIGOS
        // ======================================================

        if (
          status == null ||
          status.isEmpty
        ) {
          occupiedSlots.add(
            startMinutes,
          );

          continue;
        }

        // ======================================================
        // CONFIRMADO
        // ======================================================

        if (
          status ==
          'confirmed'
        ) {
          occupiedSlots.add(
            startMinutes,
          );

          continue;
        }

        // ======================================================
        // PENDENTE DE PAGAMENTO
        // ======================================================

        if (
          status ==
          'pending_payment'
        ) {
          final paymentExpiresAtValue =
              data[
                'paymentExpiresAt'
              ];

          if (
            paymentExpiresAtValue
            is! Timestamp
          ) {
            // Falha segura.
            occupiedSlots.add(
              startMinutes,
            );

            continue;
          }

          final paymentExpiresAt =
              paymentExpiresAtValue
                  .toDate();

          if (
            paymentExpiresAt
                .isAfter(
              now,
            )
          ) {
            occupiedSlots.add(
              startMinutes,
            );
          }

          continue;
        }

        // ======================================================
        // CANCELADO OU EXPIRADO
        // ======================================================

        if (
          status ==
              'cancelled' ||
          status ==
              'expired'
        ) {
          continue;
        }

        // ======================================================
        // STATUS DESCONHECIDO
        // ======================================================

        occupiedSlots.add(
          startMinutes,
        );
      }

      return occupiedSlots;
    }

    void emitCurrentSlots() {
      if (
        controller.isClosed
      ) {
        return;
      }

      controller.add(
        calculateOccupiedSlots(),
      );
    }

    controller =
        StreamController<
          Set<int>
        >(
          onListen:
              () {
                firestoreSubscription =
                    slotsQuery
                        .snapshots()
                        .listen(
                          (
                            snapshot,
                          ) {
                            latestDocuments =
                                snapshot
                                    .docs;

                            emitCurrentSlots();
                          },
                          onError:
                              (
                                Object error,
                                StackTrace
                                stackTrace,
                              ) {
                                if (
                                  !controller
                                      .isClosed
                                ) {
                                  controller
                                      .addError(
                                    error,
                                    stackTrace,
                                  );
                                }
                              },
                        );

                // =================================================
                // REAVALIAR EXPIRAÇÃO LOCALMENTE
                // =================================================

                expirationTimer =
                    Timer.periodic(
                  const Duration(
                    seconds:
                        5,
                  ),
                  (_) {
                    emitCurrentSlots();
                  },
                );
              },

          onCancel:
              () async {
                expirationTimer
                    ?.cancel();

                await firestoreSubscription
                    ?.cancel();
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
    final user =
        _auth.currentUser;

    if (user == null) {
      throw Exception(
        'Nenhum usuário autenticado.',
      );
    }

    if (
      service.durationMinutes <=
      0
    ) {
      throw Exception(
        'Duração do serviço inválida.',
      );
    }

    if (
      service.priceCents <=
      0
    ) {
      throw Exception(
        'Valor do serviço inválido.',
      );
    }

    // ==========================================================
    // NORMALIZAR DATA
    // ==========================================================

    final normalizedDate =
        DateTime(
      date.year,
      date.month,
      date.day,
    );

    final dateKey =
        _dateKey(
      normalizedDate,
    );

    final endMinutes =
        startMinutes +
        service.durationMinutes;

    if (
      startMinutes < 0 ||
      startMinutes >= 1440 ||
      endMinutes <=
          startMinutes ||
      endMinutes > 1440
    ) {
      throw Exception(
        'Horário de agendamento inválido.',
      );
    }

    // ==========================================================
    // HORÁRIO
    // ==========================================================

    final startAt =
        normalizedDate.add(
      Duration(
        minutes:
            startMinutes,
      ),
    );

    final endAt =
        normalizedDate.add(
      Duration(
        minutes:
            endMinutes,
      ),
    );

    // ==========================================================
    // EXPIRAÇÃO — 2 MINUTOS
    // ==========================================================

    final paymentExpiresAt =
        DateTime.now().add(
      const Duration(
        minutes:
            paymentReservationMinutes,
      ),
    );

    // ==========================================================
    // APPOINTMENT
    // ==========================================================

    final appointmentReference =
        _firestore
            .collection(
              'appointments',
            )
            .doc();

    final batch =
        _firestore.batch();

    batch.set(
      appointmentReference,
      {
        'userId':
            user.uid,

        'serviceId':
            service.id,

        'serviceName':
            service.name,

        'professionalId':
            professional.id,

        'professionalName':
            professional.name,

        'dateKey':
            dateKey,

        'startMinutes':
            startMinutes,

        'endMinutes':
            endMinutes,

        'durationMinutes':
            service
                .durationMinutes,

        'priceCents':
            service
                .priceCents,

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
            FieldValue
                .serverTimestamp(),
      },
    );

    // ==========================================================
    // LOCKS DE 15 MINUTOS
    // ==========================================================

    final slotStarts =
        _slotStartsForInterval(
      startMinutes:
          startMinutes,

      endMinutes:
          endMinutes,
    );

    for (
      final slotStart
      in slotStarts
    ) {
      final slotId =
          slotStart
              .toString()
              .padLeft(
                4,
                '0',
              );

      final slotReference =
          _firestore
              .collection(
                'professionals',
              )
              .doc(
                professional.id,
              )
              .collection(
                'booked_days',
              )
              .doc(
                dateKey,
              )
              .collection(
                'slots',
              )
              .doc(
                slotId,
              );

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
              FieldValue
                  .serverTimestamp(),
        },
      );
    }

    // ==========================================================
    // COMMIT
    // ==========================================================

    try {
      await batch.commit();

      return appointmentReference.id;
    } on FirebaseException catch (
      e
    ) {
      debugPrintFirebaseError(
        e,
      );

      if (
        e.code ==
        'permission-denied'
      ) {
        throw const AppointmentConflictException();
      }

      rethrow;
    }
  }

  // ============================================================
  // ETAPA 37.2
  // REAGENDAR AGENDAMENTO CONFIRMADO
  // ============================================================

  Future<void> rescheduleAppointment({
    required BarbershopAppointment appointment,
    required DateTime newDate,
    required int newStartMinutes,
  }) async {
    // ==========================================================
    // USUÁRIO
    // ==========================================================

    final user =
        _auth.currentUser;

    if (user == null) {
      throw const AppointmentRescheduleException(
        'Sua sessão expirou. Entre novamente.',
        code:
            'NOT_AUTHENTICATED',
      );
    }

    // ==========================================================
    // PROPRIEDADE
    // ==========================================================

    if (
      appointment.userId !=
      user.uid
    ) {
      throw const AppointmentRescheduleException(
        'Este agendamento não pertence ao usuário atual.',
        code:
            'FORBIDDEN',
      );
    }

    // ==========================================================
    // STATUS
    // ==========================================================

    if (
      appointment.status
              .trim()
              .toLowerCase() !=
          'confirmed'
    ) {
      throw const AppointmentRescheduleException(
        'Somente agendamentos confirmados podem ser reagendados.',
        code:
            'APPOINTMENT_NOT_CONFIRMED',
      );
    }

    // ==========================================================
    // AGENDAMENTO ATUAL PRECISA ESTAR NO FUTURO
    // ==========================================================

    if (
      !appointment.startAt
          .isAfter(
        DateTime.now(),
      )
    ) {
      throw const AppointmentRescheduleException(
        'Não é possível reagendar um atendimento que já começou.',
        code:
            'APPOINTMENT_ALREADY_STARTED',
      );
    }

    // ==========================================================
    // NORMALIZAR NOVA DATA
    // ==========================================================

    final normalizedDate =
        DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
    );

    // ==========================================================
    // VALIDAR NOVO HORÁRIO
    // ==========================================================

    final newEndMinutes =
        newStartMinutes +
        appointment
            .durationMinutes;

    if (
      newStartMinutes < 0 ||
      newStartMinutes >=
          1440 ||
      newStartMinutes %
              bookingSlotMinutes !=
          0 ||
      newEndMinutes <=
          newStartMinutes ||
      newEndMinutes >
          1440
    ) {
      throw const AppointmentRescheduleException(
        'O novo horário é inválido.',
        code:
            'INVALID_START_TIME',
      );
    }

    // ==========================================================
    // DATA/HORA LOCAL DO NOVO ATENDIMENTO
    // ==========================================================

    final localStart =
        normalizedDate.add(
      Duration(
        minutes:
            newStartMinutes,
      ),
    );

    if (
      !localStart.isAfter(
        DateTime.now(),
      )
    ) {
      throw const AppointmentRescheduleException(
        'Escolha um novo horário no futuro.',
        code:
            'NEW_TIME_NOT_FUTURE',
      );
    }

    // ==========================================================
    // NÃO ENVIAR A MESMA DATA/HORA
    // ==========================================================

    final newDateKey =
        _dateKey(
      normalizedDate,
    );

    if (
      newDateKey ==
          appointment.dateKey &&
      newStartMinutes ==
          appointment.startMinutes
    ) {
      throw const AppointmentRescheduleException(
        'Escolha uma data ou horário diferente do atual.',
        code:
            'SAME_SCHEDULE',
      );
    }

    // ==========================================================
    // TOKEN FIREBASE
    // ==========================================================

    try {
      final idToken =
          await user
              .getIdToken(
                true,
              );

      if (
        idToken == null ||
        idToken.isEmpty
      ) {
        throw const AppointmentRescheduleException(
          'Não foi possível validar sua sessão.',
          code:
              'INVALID_TOKEN',
        );
      }

      // ========================================================
      // FUSO HORÁRIO
      // ========================================================
      //
      // Usamos o offset referente à NOVA data/hora.
      //
      // No Brasil normalmente:
      // -180 = UTC-3.
      //
      // ========================================================

      final timezoneOffsetMinutes =
          localStart
              .timeZoneOffset
              .inMinutes;

      // ========================================================
      // BACKEND
      // ========================================================

      final response =
          await http
              .post(
                Uri.parse(
                  '$_baseUrl/v1/appointments/reschedule',
                ),
                headers: {
                  'Content-Type':
                      'application/json; charset=UTF-8',

                  'Authorization':
                      'Bearer $idToken',
                },
                body:
                    jsonEncode(
                  {
                    'appointmentId':
                        appointment.id,

                    'dateKey':
                        newDateKey,

                    'startMinutes':
                        newStartMinutes,

                    'timezoneOffsetMinutes':
                        timezoneOffsetMinutes,
                  },
                ),
              )
              .timeout(
                const Duration(
                  seconds:
                      20,
                ),
              );

      // ========================================================
      // RESPOSTA
      // ========================================================

      final data =
          _decodeResponse(
        response,
      );

      // ========================================================
      // ERRO HTTP
      // ========================================================

      if (
        response.statusCode <
            200 ||
        response.statusCode >=
            300
      ) {
        throw AppointmentRescheduleException(
          _readBackendMessage(
            data,
            fallback:
                'Não foi possível reagendar o atendimento.',
          ),
          code:
              data['code']
                  ?.toString(),
        );
      }

      // ========================================================
      // BACKEND NÃO CONFIRMOU
      // ========================================================

      if (
        data['ok'] !=
        true
      ) {
        throw AppointmentRescheduleException(
          _readBackendMessage(
            data,
            fallback:
                'O servidor não confirmou o reagendamento.',
          ),
          code:
              data['code']
                  ?.toString(),
        );
      }

      // ========================================================
      // VALIDAÇÃO DA RESPOSTA
      // ========================================================

      if (
        data[
              'rescheduled'
            ] !=
            true ||
        data[
                  'appointmentId'
                ]
                ?.toString()
                .trim() !=
            appointment.id
      ) {
        throw const AppointmentRescheduleException(
          'O servidor retornou uma confirmação de reagendamento inválida.',
          code:
              'INVALID_RESCHEDULE_RESPONSE',
        );
      }

      // ========================================================
      // SUCESSO
      // ========================================================
      //
      // Não precisamos atualizar o Firestore manualmente aqui.
      //
      // O BACKEND já fez a transação.
      //
      // watchCurrentUserAppointments() receberá automaticamente
      // o novo documento atualizado.
      // ========================================================

      return;
    }

    // ==========================================================
    // ERRO CONHECIDO
    // ==========================================================

    on AppointmentRescheduleException {
      rethrow;
    }

    // ==========================================================
    // TIMEOUT
    // ==========================================================

    on TimeoutException {
      throw const AppointmentRescheduleException(
        'O servidor demorou muito para responder. '
        'Verifique sua conexão e tente novamente.',
        code:
            'TIMEOUT',
      );
    }

    // ==========================================================
    // CONEXÃO
    // ==========================================================

    on http.ClientException {
      throw const AppointmentRescheduleException(
        'Não foi possível conectar ao servidor.',
        code:
            'CONNECTION_ERROR',
      );
    }

    // ==========================================================
    // ERRO DESCONHECIDO
    // ==========================================================

    catch (e) {
      throw AppointmentRescheduleException(
        'Não foi possível reagendar o atendimento. '
        'Detalhes: $e',
        code:
            'UNKNOWN_RESCHEDULE_ERROR',
      );
    }
  }

  // ============================================================
  // CANCELAR AGENDAMENTO
  // ============================================================

  Future<void> cancelAppointment({
    required BarbershopAppointment appointment,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw const AppointmentCancellationException(
        'Nenhum usuário autenticado.',
      );
    }

    if (
      appointment.userId !=
      user.uid
    ) {
      throw const AppointmentCancellationException(
        'Este agendamento não pertence ao usuário atual.',
      );
    }

    // ==========================================================
    // SOMENTE RESERVA PENDENTE PODE SER CANCELADA DIRETAMENTE
    // ==========================================================
    //
    // Confirmed não pode ser liberado diretamente pelo cliente.
    // ==========================================================

    if (
      appointment.status !=
      'pending_payment'
    ) {
      throw const AppointmentCancellationException(
        'Este agendamento não pode mais ser cancelado diretamente.',
      );
    }

    final now =
        DateTime.now();

    if (
      !appointment.startAt
          .isAfter(
        now,
      )
    ) {
      throw const AppointmentCancellationException(
        'Não é possível cancelar um atendimento que já começou.',
      );
    }

    final appointmentReference =
        _firestore
            .collection(
              'appointments',
            )
            .doc(
              appointment.id,
            );

    final batch =
        _firestore.batch();

    // ==========================================================
    // STATUS
    // ==========================================================

    batch.update(
      appointmentReference,
      {
        'status':
            'cancelled',

        'cancelledAt':
            FieldValue
                .serverTimestamp(),
      },
    );

    // ==========================================================
    // LIBERAR SLOTS
    // ==========================================================

    final slotStarts =
        _slotStartsForInterval(
      startMinutes:
          appointment
              .startMinutes,

      endMinutes:
          appointment
              .endMinutes,
    );

    for (
      final slotStart
      in slotStarts
    ) {
      final slotId =
          slotStart
              .toString()
              .padLeft(
                4,
                '0',
              );

      final slotReference =
          _firestore
              .collection(
                'professionals',
              )
              .doc(
                appointment
                    .professionalId,
              )
              .collection(
                'booked_days',
              )
              .doc(
                appointment
                    .dateKey,
              )
              .collection(
                'slots',
              )
              .doc(
                slotId,
              );

      batch.delete(
        slotReference,
      );
    }

    try {
      await batch.commit();
    } on FirebaseException catch (
      e
    ) {
      debugPrintFirebaseError(
        e,
      );

      throw const AppointmentCancellationException();
    }
  }

  // ============================================================
  // JSON DO BACKEND
  // ============================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (
      response.bodyBytes
          .isEmpty
    ) {
      return <String, dynamic>{};
    }

    try {
      final decoded =
          jsonDecode(
        utf8.decode(
          response.bodyBytes,
        ),
      );

      if (
        decoded is Map
      ) {
        return Map<
          String,
          dynamic
        >.from(
          decoded,
        );
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  // ============================================================
  // MENSAGEM DO BACKEND
  // ============================================================

  String _readBackendMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message =
        data['message']
            ?.toString()
            .trim();

    if (
      message == null ||
      message.isEmpty
    ) {
      return fallback;
    }

    return message;
  }

  // ============================================================
  // UTILITÁRIOS
  // ============================================================

  List<int> _slotStartsForInterval({
    required int startMinutes,
    required int endMinutes,
  }) {
    final slots =
        <int>[];

    var current =
        startMinutes;

    while (
      current <
      endMinutes
    ) {
      slots.add(
        current,
      );

      current +=
          bookingSlotMinutes;
    }

    return slots;
  }

  String _dateKey(
    DateTime date,
  ) {
    final year =
        date.year
            .toString()
            .padLeft(
              4,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final day =
        date.day
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