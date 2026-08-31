import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/data/models/professional_availability.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/availability_repository.dart';

class RescheduleAppointmentPage extends StatefulWidget {
  final BarbershopAppointment appointment;

  const RescheduleAppointmentPage({
    super.key,
    required this.appointment,
  });

  @override
  State<RescheduleAppointmentPage> createState() =>
      _RescheduleAppointmentPageState();
}

class _RescheduleAppointmentPageState
    extends State<RescheduleAppointmentPage> {
  final AppointmentRepository _appointmentRepository =
      AppointmentRepository();

  final AvailabilityRepository _availabilityRepository =
      AvailabilityRepository();

  DateTime? _selectedDate;

  int? _selectedStartMinutes;

  Future<ProfessionalAvailability?>? _availabilityFuture;

  bool _isRescheduling = false;

  late final DateTime _today;
  late final DateTime _lastAllowedDate;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    _lastAllowedDate = _today.add(
      const Duration(
        days: 30,
      ),
    );
  }

  // ============================================================
  // FORMATAR HORÁRIO
  // ============================================================

  String _formatTime(
    int minutes,
  ) {
    final hour =
        minutes ~/ 60;

    final minute =
        minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // FORMATAR DATA
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // VALOR
  // ============================================================

  String _formatPrice(
    int priceCents,
  ) {
    final reais =
        priceCents ~/ 100;

    final cents =
        (priceCents % 100)
            .toString()
            .padLeft(
              2,
              '0',
            );

    return 'R\$ $reais,$cents';
  }

  // ============================================================
  // DIA DA SEMANA
  // ============================================================

  String _weekdayName(
    DateTime date,
  ) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Segunda-feira';

      case DateTime.tuesday:
        return 'Terça-feira';

      case DateTime.wednesday:
        return 'Quarta-feira';

      case DateTime.thursday:
        return 'Quinta-feira';

      case DateTime.friday:
        return 'Sexta-feira';

      case DateTime.saturday:
        return 'Sábado';

      case DateTime.sunday:
        return 'Domingo';

      default:
        return '';
    }
  }

  String _shortWeekday(
    DateTime date,
  ) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'SEG';

      case DateTime.tuesday:
        return 'TER';

      case DateTime.wednesday:
        return 'QUA';

      case DateTime.thursday:
        return 'QUI';

      case DateTime.friday:
        return 'SEX';

      case DateTime.saturday:
        return 'SÁB';

      case DateTime.sunday:
        return 'DOM';

      default:
        return '';
    }
  }

  // ============================================================
  // DATE KEY
  // ============================================================

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

  // ============================================================
  // MESMO DIA
  // ============================================================

  bool _isSameDay(
    DateTime first,
    DateTime second,
  ) {
    return first.year ==
            second.year &&
        first.month ==
            second.month &&
        first.day ==
            second.day;
  }

  // ============================================================
  // SELECIONAR DATA
  // ============================================================

  void _selectDate(
    DateTime date,
  ) {
    final normalizedDate =
        DateTime(
      date.year,
      date.month,
      date.day,
    );

    setState(() {
      _selectedDate =
          normalizedDate;

      _selectedStartMinutes =
          null;

      _availabilityFuture =
          _availabilityRepository
              .getAvailabilityForDate(
        professionalId:
            widget.appointment
                .professionalId,

        date:
            normalizedDate,
      );
    });
  }

  // ============================================================
  // CALENDÁRIO
  // ============================================================

  Future<void> _openCalendar() async {
    final pickedDate =
        await showDatePicker(
      context:
          context,

      initialDate:
          _selectedDate ??
          _today,

      firstDate:
          _today,

      lastDate:
          _lastAllowedDate,

      helpText:
          'Escolha a nova data',

      cancelText:
          'CANCELAR',

      confirmText:
          'CONFIRMAR',
    );

    if (
      pickedDate ==
      null
    ) {
      return;
    }

    _selectDate(
      pickedDate,
    );
  }

  // ============================================================
  // RETIRAR OS SLOTS DO PRÓPRIO AGENDAMENTO
  // ============================================================

  Set<int> _removeCurrentAppointmentSlots({
    required Set<int> occupiedSlots,
    required DateTime selectedDate,
  }) {
    final effective =
        <int>{
      ...occupiedSlots,
    };

    // Se a nova data é diferente,
    // os slots antigos não interferem.

    if (
      _dateKey(
            selectedDate,
          ) !=
          widget.appointment
              .dateKey
    ) {
      return effective;
    }

    // ==========================================================
    // MESMO DIA DO AGENDAMENTO ATUAL
    //
    // Os slots ocupados pelo PRÓPRIO appointment podem ser
    // reutilizados.
    //
    // Exemplo:
    //
    // atual = 08:00 - 08:30
    //
    // reagendamento = 08:15 - 08:45
    //
    // O slot 08:15 é do próprio appointment, portanto não
    // deve bloquear a escolha na interface.
    //
    // O backend fará novamente a validação final.
    // ==========================================================

    var current =
        widget.appointment
            .startMinutes;

    while (
      current <
      widget.appointment
          .endMinutes
    ) {
      effective.remove(
        current,
      );

      current +=
          AppointmentRepository
              .bookingSlotMinutes;
    }

    return effective;
  }

  // ============================================================
  // HORÁRIO OCUPADO
  // ============================================================

  bool _hasOccupiedSlot({
    required int startMinutes,
    required int endMinutes,
    required Set<int> occupiedSlots,
  }) {
    var current =
        startMinutes;

    while (
      current <
      endMinutes
    ) {
      if (
        occupiedSlots
            .contains(
          current,
        )
      ) {
        return true;
      }

      current +=
          AppointmentRepository
              .bookingSlotMinutes;
    }

    return false;
  }

  // ============================================================
  // HORÁRIO PASSADO
  // ============================================================

  bool _isPastTime(
    DateTime date,
    int startMinutes,
  ) {
    final candidate =
        DateTime(
      date.year,
      date.month,
      date.day,
    ).add(
      Duration(
        minutes:
            startMinutes,
      ),
    );

    return !candidate.isAfter(
      DateTime.now(),
    );
  }

  // ============================================================
  // GERAR HORÁRIOS
  // ============================================================

  List<int> _generateAvailableTimes(
    ProfessionalAvailability availability,
    Set<int> occupiedSlots,
    DateTime date,
  ) {
    if (
      !availability.enabled
    ) {
      return [];
    }

    if (
      availability.startMinutes >=
      availability.endMinutes
    ) {
      return [];
    }

    final duration =
        widget.appointment
            .durationMinutes;

    if (
      duration <=
      0
    ) {
      return [];
    }

    final interval =
        availability
                    .intervalMinutes >
                0
            ? availability
                .intervalMinutes
            : 30;

    final times =
        <int>[];

    var current =
        availability
            .startMinutes;

    while (
      current +
              duration <=
          availability
              .endMinutes
    ) {
      final endMinutes =
          current +
          duration;

      // O backend da Etapa 37 trabalha
      // em slots de 15 minutos.

      final aligned =
          current %
                  AppointmentRepository
                      .bookingSlotMinutes ==
              0;

      final hasConflict =
          _hasOccupiedSlot(
        startMinutes:
            current,

        endMinutes:
            endMinutes,

        occupiedSlots:
            occupiedSlots,
      );

      final isPast =
          _isPastTime(
        date,
        current,
      );

      final sameSchedule =
          _dateKey(
                date,
              ) ==
              widget.appointment
                  .dateKey &&
          current ==
              widget.appointment
                  .startMinutes;

      if (
        aligned &&
        !hasConflict &&
        !isPast &&
        !sameSchedule
      ) {
        times.add(
          current,
        );
      }

      current +=
          interval;
    }

    return times;
  }

  // ============================================================
  // SELECIONAR HORÁRIO
  // ============================================================

  void _selectTime(
    int minutes,
  ) {
    setState(() {
      _selectedStartMinutes =
          minutes;
    });
  }

  // ============================================================
  // CONFIRMAR REAGENDAMENTO
  // ============================================================

  Future<void> _confirmReschedule() async {
    if (
      _isRescheduling
    ) {
      return;
    }

    final date =
        _selectedDate;

    final startMinutes =
        _selectedStartMinutes;

    if (
      date == null ||
      startMinutes == null
    ) {
      return;
    }

    final newEndMinutes =
        startMinutes +
        widget.appointment
            .durationMinutes;

    final confirmed =
        await showDialog<bool>(
      context:
          context,

      builder:
          (
            dialogContext,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'Confirmar reagendamento?',
              ),

              content:
                  Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seu horário atual:',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    '${_formatDate(widget.appointment.startAt)} • '
                    '${_formatTime(widget.appointment.startMinutes)} às '
                    '${_formatTime(widget.appointment.endMinutes)}',
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'Novo horário:',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    '${_formatDate(date)} • '
                    '${_formatTime(startMinutes)} às '
                    '${_formatTime(newEndMinutes)}',
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  const Text(
                    'O pagamento já realizado será mantido.',
                    style:
                        TextStyle(
                      fontSize:
                          12,
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
                      false,
                    );
                  },
                  child:
                      const Text(
                    'VOLTAR',
                  ),
                ),

                FilledButton(
                  onPressed:
                      () {
                    Navigator.of(
                      dialogContext,
                    ).pop(
                      true,
                    );
                  },
                  child:
                      const Text(
                    'CONFIRMAR',
                  ),
                ),
              ],
            );
          },
    );

    if (
      confirmed !=
          true ||
      !mounted
    ) {
      return;
    }

    setState(() {
      _isRescheduling =
          true;
    });

    try {
      await _appointmentRepository
          .rescheduleAppointment(
        appointment:
            widget.appointment,

        newDate:
            date,

        newStartMinutes:
            startMinutes,
      );

      if (
        !mounted
      ) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Agendamento reagendado com sucesso.',
          ),
        ),
      );

      Navigator.of(
        context,
      ).pop(
        true,
      );
    } on AppointmentRescheduleException catch (
      e
    ) {
      if (
        !mounted
      ) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            e.message,
          ),
        ),
      );
    } catch (
      e
    ) {
      debugPrint(
        'RESCHEDULE UI ERROR -> $e',
      );

      if (
        !mounted
      ) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Não foi possível reagendar o atendimento.',
          ),
        ),
      );
    } finally {
      if (
        mounted
      ) {
        setState(() {
          _isRescheduling =
              false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final nextDates =
        List<DateTime>.generate(
      14,
      (
        index,
      ) =>
          _today.add(
        Duration(
          days:
              index,
        ),
      ),
    );

    final canContinue =
        _selectedDate !=
            null &&
        _selectedStartMinutes !=
            null &&
        !_isRescheduling;

    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar:
          AppBar(
        title:
            const Text(
          'Reagendar',
        ),
      ),

      body:
          SafeArea(
        child:
            Column(
          children: [
            Expanded(
              child:
                  ListView(
                padding:
                    const EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  30,
                ),
                children: [
                  // =============================================
                  // AGENDAMENTO ATUAL
                  // =============================================

                  _CurrentAppointmentCard(
                    appointment:
                        widget.appointment,

                    date:
                        _formatDate(
                      widget.appointment.startAt,
                    ),

                    time:
                        '${_formatTime(widget.appointment.startMinutes)} às '
                        '${_formatTime(widget.appointment.endMinutes)}',

                    price:
                        _formatPrice(
                      widget.appointment.priceCents,
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  const Text(
                    'Escolha a nova data',
                    style:
                        TextStyle(
                      color:
                          AppColors.textPrimary,
                      fontSize:
                          21,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  const Text(
                    'Você pode reagendar mantendo o mesmo '
                    'serviço e profissional.',
                    style:
                        TextStyle(
                      color:
                          AppColors.textSecondary,
                      fontSize:
                          12,
                      height:
                          1.4,
                    ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SizedBox(
                    height:
                        92,
                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,

                      itemCount:
    nextDates.length,

separatorBuilder:
    (_, _) =>
        const SizedBox(
  width:
      10,
),

itemBuilder:
    (
      context,
      index,
    ) {
                            final date =
                                nextDates[
                                  index
                                ];

                            final selected =
                                _selectedDate !=
                                        null &&
                                    _isSameDay(
                                      _selectedDate!,
                                      date,
                                    );

                            return _DateCard(
                              date:
                                  date,

                              weekday:
                                  _shortWeekday(
                                date,
                              ),

                              selected:
                                  selected,

                              onTap:
                                  () {
                                _selectDate(
                                  date,
                                );
                              },
                            );
                          },
                    ),
                  ),

                  const SizedBox(
                    height: 15,
                  ),

                  OutlinedButton.icon(
                    onPressed:
                        _openCalendar,

                    icon:
                        const Icon(
                      Icons
                          .calendar_month_outlined,
                    ),

                    label:
                        const Text(
                      'VER CALENDÁRIO COMPLETO',
                    ),
                  ),

                  if (
                    _selectedDate !=
                    null
                  ) ...[
                    const SizedBox(
                      height: 28,
                    ),

                    _SelectedDateCard(
                      weekday:
                          _weekdayName(
                        _selectedDate!,
                      ),

                      date:
                          _formatDate(
                        _selectedDate!,
                      ),
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    const Text(
                      'Escolha o novo horário',
                      style:
                          TextStyle(
                        color:
                            AppColors.textPrimary,
                        fontSize:
                            21,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    _buildAvailableTimes(
                      _selectedDate!,
                    ),
                  ],
                ],
              ),
            ),

            // =================================================
            // BOTÃO
            // =================================================

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                18,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.surface,
                border:
                    Border(
                  top:
                      BorderSide(
                    color:
                        AppColors.border,
                  ),
                ),
              ),
              child:
                  SizedBox(
                width:
                    double.infinity,
                height:
                    52,
                child:
                    FilledButton.icon(
                  onPressed:
                      canContinue
                          ? _confirmReschedule
                          : null,

                  icon:
                      _isRescheduling
                          ? const SizedBox(
                              width:
                                  18,
                              height:
                                  18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .event_repeat_rounded,
                            ),

                  label:
                      Text(
                    _isRescheduling
                        ? 'REAGENDANDO...'
                        : 'CONFIRMAR NOVO HORÁRIO',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HORÁRIOS DISPONÍVEIS
  // ============================================================

  Widget _buildAvailableTimes(
    DateTime date,
  ) {
    final availabilityFuture =
        _availabilityFuture;

    if (
      availabilityFuture ==
      null
    ) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<
      ProfessionalAvailability?
    >(
      future:
          availabilityFuture,

      builder:
          (
            context,
            availabilitySnapshot,
          ) {
            if (
              availabilitySnapshot
                      .connectionState ==
                  ConnectionState.waiting
            ) {
              return const Padding(
                padding:
                    EdgeInsets.all(
                  30,
                ),
                child:
                    Center(
                  child:
                      CircularProgressIndicator(),
                ),
              );
            }

            if (
              availabilitySnapshot.hasError
            ) {
              return const _MessageCard(
                icon:
                    Icons.error_outline,

                title:
                    'Não foi possível carregar os horários.',
              );
            }

            final availability =
                availabilitySnapshot
                    .data;

            if (
              availability ==
                  null ||
              !availability.enabled
            ) {
              return const _MessageCard(
                icon:
                    Icons
                        .event_busy_outlined,

                title:
                    'Sem atendimento nesta data.',

                subtitle:
                    'Escolha outra data para continuar.',
              );
            }

            return StreamBuilder<
              Set<int>
            >(
              stream:
                  _appointmentRepository
                      .watchBookedSlotMinutes(
                professionalId:
                    widget.appointment
                        .professionalId,

                date:
                    date,
              ),

              builder:
                  (
                    context,
                    bookedSnapshot,
                  ) {
                    if (
                      bookedSnapshot
                              .connectionState ==
                          ConnectionState.waiting
                    ) {
                      return const Padding(
                        padding:
                            EdgeInsets.all(
                          30,
                        ),
                        child:
                            Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (
                      bookedSnapshot.hasError
                    ) {
                      return const _MessageCard(
                        icon:
                            Icons
                                .error_outline,

                        title:
                            'Não foi possível consultar os horários.',
                      );
                    }

                    final rawOccupied =
                        bookedSnapshot
                                .data ??
                            <int>{};

                    final occupied =
                        _removeCurrentAppointmentSlots(
                      occupiedSlots:
                          rawOccupied,

                      selectedDate:
                          date,
                    );

                    final times =
                        _generateAvailableTimes(
                      availability,
                      occupied,
                      date,
                    );

                    if (
                      times.isEmpty
                    ) {
                      return const _MessageCard(
                        icon:
                            Icons
                                .schedule_outlined,

                        title:
                            'Nenhum horário disponível.',

                        subtitle:
                            'Escolha outra data para continuar.',
                      );
                    }

                    final selected =
                        _selectedStartMinutes;

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Atendimento de '
                          '${_formatTime(availability.startMinutes)} '
                          'até '
                          '${_formatTime(availability.endMinutes)}.',
                          style:
                              const TextStyle(
                            color:
                                AppColors.textSecondary,
                            fontSize:
                                11,
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        GridView.builder(
                          shrinkWrap:
                              true,

                          physics:
                              const NeverScrollableScrollPhysics(),

                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                3,

                            crossAxisSpacing:
                                10,

                            mainAxisSpacing:
                                10,

                            childAspectRatio:
                                2.2,
                          ),

                          itemCount:
                              times.length,

                          itemBuilder:
                              (
                                context,
                                index,
                              ) {
                                final time =
                                    times[
                                      index
                                    ];

                                return _TimeCard(
                                  time:
                                      _formatTime(
                                    time,
                                  ),

                                  selected:
                                      selected ==
                                      time,

                                  onTap:
                                      () {
                                    _selectTime(
                                      time,
                                    );
                                  },
                                );
                              },
                        ),

                        if (
                          selected !=
                          null
                        ) ...[
                          const SizedBox(
                            height: 20,
                          ),

                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets.all(
                              16,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors.successSoft,
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                            ),
                            child:
                                Row(
                              children: [
                                const Icon(
                                  Icons
                                      .check_circle_rounded,
                                  color:
                                      AppColors.success,
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                      Text(
                                    'Novo horário: '
                                    '${_formatTime(selected)} às '
                                    '${_formatTime(
                                      selected +
                                          widget
                                              .appointment
                                              .durationMinutes,
                                    )}',
                                    style:
                                        const TextStyle(
                                      color:
                                          AppColors.textPrimary,
                                      fontWeight:
                                          FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
            );
          },
    );
  }
}

// ============================================================
// AGENDAMENTO ATUAL
// ============================================================

class _CurrentAppointmentCard
    extends StatelessWidget {
  final BarbershopAppointment appointment;

  final String date;
  final String time;
  final String price;

  const _CurrentAppointmentCard({
    required this.appointment,
    required this.date,
    required this.time,
    required this.price,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.black,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'AGENDAMENTO ATUAL',
            style:
                TextStyle(
              color:
                  AppColors.gold,
              fontSize:
                  10,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  0.8,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            appointment
                .serviceName,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  20,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            appointment
                .professionalName,
            style:
                const TextStyle(
              color:
                  Color(
                0xFFC4C0BA,
              ),
              fontSize:
                  12,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          const Divider(
            color:
                AppColors.graphite,
          ),

          const SizedBox(
            height: 8,
          ),

          _CurrentInfo(
            icon:
                Icons
                    .calendar_month_outlined,
            value:
                date,
          ),

          const SizedBox(
            height: 10,
          ),

          _CurrentInfo(
            icon:
                Icons
                    .schedule_outlined,
            value:
                time,
          ),

          const SizedBox(
            height: 10,
          ),

          _CurrentInfo(
            icon:
                Icons
                    .payments_outlined,
            value:
                price,
          ),
        ],
      ),
    );
  }
}

class _CurrentInfo
    extends StatelessWidget {
  final IconData icon;
  final String value;

  const _CurrentInfo({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size:
              18,
          color:
              AppColors.gold,
        ),

        const SizedBox(
          width: 10,
        ),

        Text(
          value,
          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize:
                12,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DATA
// ============================================================

class _DateCard
    extends StatelessWidget {
  final DateTime date;
  final String weekday;
  final bool selected;
  final VoidCallback onTap;

  const _DateCard({
    required this.date,
    required this.weekday,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          selected
              ? AppColors.black
              : AppColors.surfaceSecondary,

      borderRadius:
          BorderRadius.circular(
        16,
      ),

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            SizedBox(
          width:
              68,
          child:
              Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style:
                    TextStyle(
                  color:
                      selected
                          ? AppColors.gold
                          : AppColors.textSecondary,
                  fontSize:
                      10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                '${date.day}',
                style:
                    TextStyle(
                  color:
                      selected
                          ? Colors.white
                          : AppColors.textPrimary,
                  fontSize:
                      23,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DATA SELECIONADA
// ============================================================

class _SelectedDateCard
    extends StatelessWidget {
  final String weekday;
  final String date;

  const _SelectedDateCard({
    required this.weekday,
    required this.date,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.goldSoft,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          Row(
        children: [
          const Icon(
            Icons
                .event_available_outlined,
            color:
                AppColors.goldDark,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  weekday,
                  style:
                      const TextStyle(
                    color:
                        AppColors.textSecondary,
                    fontSize:
                        10,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  date,
                  style:
                      const TextStyle(
                    color:
                        AppColors.textPrimary,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .check_circle_rounded,
            color:
                AppColors.goldDark,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HORÁRIO
// ============================================================

class _TimeCard
    extends StatelessWidget {
  final String time;
  final bool selected;
  final VoidCallback onTap;

  const _TimeCard({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          selected
              ? AppColors.black
              : AppColors.surfaceSecondary,

      borderRadius:
          BorderRadius.circular(
        13,
      ),

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          13,
        ),

        child:
            Center(
          child:
              Text(
            time,
            style:
                TextStyle(
              color:
                  selected
                      ? AppColors.gold
                      : AppColors.textPrimary,
              fontSize:
                  15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MENSAGEM
// ============================================================

class _MessageCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _MessageCard({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        22,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surfaceSecondary,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child:
          Column(
        children: [
          Icon(
            icon,
            size:
                36,
            color:
                AppColors.textSecondary,
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          if (
            subtitle !=
            null
          ) ...[
            const SizedBox(
              height: 6,
            ),

            Text(
              subtitle!,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize:
                    11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}