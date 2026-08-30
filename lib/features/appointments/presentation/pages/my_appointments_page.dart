import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({
    super.key,
  });

  @override
  State<MyAppointmentsPage> createState() =>
      _MyAppointmentsPageState();
}

class _MyAppointmentsPageState
    extends State<MyAppointmentsPage> {
  final AppointmentRepository _repository =
      AppointmentRepository();

  final Set<String> _cancellingIds = {};

  // ============================================================
  // FORMATAR HORÁRIO
  // ============================================================

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // FORMATAR VALOR
  // ============================================================

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents =
        (priceCents % 100)
            .toString()
            .padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

  // ============================================================
  // FORMATAR DATA
  // ============================================================

  String _formatDate(DateTime date) {
    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // DIA CURTO
  // ============================================================

  String _shortMonth(int month) {
    switch (month) {
      case 1:
        return 'JAN';
      case 2:
        return 'FEV';
      case 3:
        return 'MAR';
      case 4:
        return 'ABR';
      case 5:
        return 'MAI';
      case 6:
        return 'JUN';
      case 7:
        return 'JUL';
      case 8:
        return 'AGO';
      case 9:
        return 'SET';
      case 10:
        return 'OUT';
      case 11:
        return 'NOV';
      case 12:
        return 'DEZ';
      default:
        return '';
    }
  }

  // ============================================================
  // DIA DA SEMANA
  // ============================================================

  String _weekdayName(DateTime date) {
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

  // ============================================================
  // CANCELAR AGENDAMENTO
  // ============================================================

  Future<void> _cancelAppointment(
    BarbershopAppointment appointment,
  ) async {
    if (_cancellingIds.contains(appointment.id)) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: Container(
            width: 62,
            height: 62,
            decoration:
                const BoxDecoration(
              color: AppColors.errorSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_outlined,
              color: AppColors.error,
              size: 30,
            ),
          ),
          title: const Text(
            'Cancelar agendamento?',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appointment.serviceName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                '${_formatDate(appointment.startAt)}\n'
                '${_formatTime(appointment.startMinutes)} às '
                '${_formatTime(appointment.endMinutes)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              const Text(
                'O horário será liberado novamente '
                'para outros clientes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text(
                'VOLTAR',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.error,
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'CANCELAR AGENDAMENTO',
              ),
            ),
          ],
        );
      },
    );

    if (
      confirmed != true ||
      !mounted
    ) {
      return;
    }

    setState(() {
      _cancellingIds.add(
        appointment.id,
      );
    });

    try {
      await _repository.cancelAppointment(
        appointment: appointment,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Agendamento cancelado. '
            'O horário foi liberado.',
          ),
        ),
      );
    } on AppointmentCancellationException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'CANCEL APPOINTMENT ERROR -> $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível cancelar '
            'o agendamento.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingIds.remove(
            appointment.id,
          );
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:
          StreamBuilder<
              List<BarbershopAppointment>>(
        stream:
            _repository
                .watchCurrentUserAppointments(),

        builder:
            (
              context,
              snapshot,
            ) {
          // ======================================================
          // CARREGANDO
          // ======================================================

          if (
            snapshot.connectionState ==
            ConnectionState.waiting
          ) {
            return const _AppointmentsLoading();
          }

          // ======================================================
          // ERRO
          // ======================================================

          if (snapshot.hasError) {
            debugPrint(
              'MY APPOINTMENTS ERROR -> '
              '${snapshot.error}',
            );

            return const _AppointmentsError();
          }

          final appointments =
              snapshot.data ?? [];

          // ======================================================
          // NENHUM
          // ======================================================

          if (appointments.isEmpty) {
            return const _EmptyAppointments();
          }

          final now =
              DateTime.now();

          // ======================================================
          // PRÓXIMOS CONFIRMADOS
          // ======================================================

          final upcoming =
              appointments
                  .where(
                    (appointment) =>
                        appointment.status ==
                            'confirmed' &&
                        appointment.endAt
                            .isAfter(now),
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.startAt.compareTo(
                    b.startAt,
                  ),
                );

          // ======================================================
          // AGUARDANDO PAGAMENTO
          // ======================================================

          final pendingPayment =
              appointments
                  .where(
                    (appointment) =>
                        appointment.status ==
                        'pending_payment',
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.startAt.compareTo(
                    b.startAt,
                  ),
                );

          // ======================================================
          // HISTÓRICO
          // ======================================================

          final history =
              appointments
                  .where(
                    (appointment) {
                      if (
                        appointment.status ==
                        'pending_payment'
                      ) {
                        return false;
                      }

                      if (
                        appointment.status ==
                            'confirmed' &&
                        appointment.endAt
                            .isAfter(now)
                      ) {
                        return false;
                      }

                      return true;
                    },
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      b.startAt.compareTo(
                    a.startAt,
                  ),
                );

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              32,
            ),
            children: [
              // =================================================
              // CABEÇALHO
              // =================================================

              const _AgendaHeader(),

              const SizedBox(
                height: 26,
              ),

              // =================================================
              // RESUMO
              // =================================================

              _AgendaOverview(
                upcoming:
                    upcoming.length,
                pending:
                    pendingPayment.length,
                history:
                    history.length,
              ),

              const SizedBox(
                height: 30,
              ),

              // =================================================
              // PRÓXIMOS
              // =================================================

              _SectionTitle(
                icon:
                    Icons
                        .event_available_outlined,
                title:
                    'Próximos',
                count:
                    upcoming.length,
              ),

              const SizedBox(
                height: 12,
              ),

              if (upcoming.isEmpty)
                const _NoUpcomingAppointments()
              else
                ...upcoming.map(
                  (appointment) {
                    final canCancel =
                        appointment.status ==
                                'confirmed' &&
                            appointment
                                .startAt
                                .isAfter(now);

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child:
                          _AppointmentCard(
                        appointment:
                            appointment,
                        date:
                            _formatDate(
                          appointment.startAt,
                        ),
                        weekday:
                            _weekdayName(
                          appointment.startAt,
                        ),
                        month:
                            _shortMonth(
                          appointment
                              .startAt
                              .month,
                        ),
                        time:
                            '${_formatTime(appointment.startMinutes)} às '
                            '${_formatTime(appointment.endMinutes)}',
                        price:
                            _formatPrice(
                          appointment.priceCents,
                        ),
                        canCancel:
                            canCancel,
                        isCancelling:
                            _cancellingIds.contains(
                          appointment.id,
                        ),
                        onCancel:
                            () {
                          _cancelAppointment(
                            appointment,
                          );
                        },
                      ),
                    );
                  },
                ),

              // =================================================
              // AGUARDANDO PAGAMENTO
              // =================================================

              if (
                pendingPayment.isNotEmpty
              ) ...[
                const SizedBox(
                  height: 22,
                ),

                _SectionTitle(
                  icon:
                      Icons
                          .hourglass_top_rounded,
                  title:
                      'Aguardando pagamento',
                  count:
                      pendingPayment.length,
                ),

                const SizedBox(
                  height: 12,
                ),

                ...pendingPayment.map(
                  (appointment) =>
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child:
                        _AppointmentCard(
                      appointment:
                          appointment,
                      date:
                          _formatDate(
                        appointment.startAt,
                      ),
                      weekday:
                          _weekdayName(
                        appointment.startAt,
                      ),
                      month:
                          _shortMonth(
                        appointment
                            .startAt
                            .month,
                      ),
                      time:
                          '${_formatTime(appointment.startMinutes)} às '
                          '${_formatTime(appointment.endMinutes)}',
                      price:
                          _formatPrice(
                        appointment.priceCents,
                      ),
                    ),
                  ),
                ),
              ],

              // =================================================
              // HISTÓRICO
              // =================================================

              if (history.isNotEmpty) ...[
                const SizedBox(
                  height: 22,
                ),

                _SectionTitle(
                  icon:
                      Icons
                          .history_rounded,
                  title:
                      'Histórico',
                  count:
                      history.length,
                ),

                const SizedBox(
                  height: 12,
                ),

                ...history.map(
                  (appointment) =>
                      Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child:
                        _AppointmentCard(
                      appointment:
                          appointment,
                      date:
                          _formatDate(
                        appointment.startAt,
                      ),
                      weekday:
                          _weekdayName(
                        appointment.startAt,
                      ),
                      month:
                          _shortMonth(
                        appointment
                            .startAt
                            .month,
                      ),
                      time:
                          '${_formatTime(appointment.startMinutes)} às '
                          '${_formatTime(appointment.endMinutes)}',
                      price:
                          _formatPrice(
                        appointment.priceCents,
                      ),
                      historical:
                          true,
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 18,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CABEÇALHO
// ============================================================

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration:
              BoxDecoration(
            color:
                AppColors.black,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child:
              const Icon(
            Icons
                .calendar_month_rounded,
            color:
                AppColors.gold,
            size: 27,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          'Seus agendamentos',
          style:
              Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
        ),

        const SizedBox(
          height: 6,
        ),

        Text(
          'Acompanhe seus próximos horários '
          'e consulte seu histórico de atendimentos.',
          style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// RESUMO DA AGENDA
// ============================================================

class _AgendaOverview extends StatelessWidget {
  final int upcoming;
  final int pending;
  final int history;

  const _AgendaOverview({
    required this.upcoming,
    required this.pending,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.black,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child:
                _OverviewItem(
              value:
                  '$upcoming',
              label:
                  'PRÓXIMOS',
              highlighted:
                  true,
            ),
          ),

          const _OverviewDivider(),

          Expanded(
            child:
                _OverviewItem(
              value:
                  '$pending',
              label:
                  'PENDENTES',
            ),
          ),

          const _OverviewDivider(),

          Expanded(
            child:
                _OverviewItem(
              value:
                  '$history',
              label:
                  'HISTÓRICO',
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final String value;
  final String label;
  final bool highlighted;

  const _OverviewItem({
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style:
              TextStyle(
            color:
                highlighted
                    ? AppColors.gold
                    : Colors.white,
            fontSize: 24,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        Text(
          label,
          style:
              const TextStyle(
            color:
                Color(
              0xFFBDB9B3,
            ),
            fontSize: 8.5,
            fontWeight:
                FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _OverviewDivider extends StatelessWidget {
  const _OverviewDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color:
          AppColors.graphite,
    );
  }
}

// ============================================================
// CARD DO AGENDAMENTO
// ============================================================

class _AppointmentCard extends StatelessWidget {
  final BarbershopAppointment appointment;

  final String date;
  final String weekday;
  final String month;
  final String time;
  final String price;

  final bool historical;
  final bool canCancel;
  final bool isCancelling;

  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.date,
    required this.weekday,
    required this.month,
    required this.time,
    required this.price,
    this.historical = false,
    this.canCancel = false,
    this.isCancelling = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle =
        _AppointmentStatusStyle.from(
      appointment.status,
      historical: historical,
    );

    return Container(
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Column(
        children: [
          // =====================================================
          // CABEÇALHO
          // =====================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              15,
              15,
              15,
              13,
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =================================================
                // DATA
                // =================================================

                Container(
                  width: 61,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 9,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        historical
                            ? AppColors
                                .surfaceSecondary
                            : AppColors.black,
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  child:
                      Column(
                    children: [
                      Text(
                        '${appointment.startAt.day}',
                        style:
                            TextStyle(
                          color:
                              historical
                                  ? AppColors
                                      .textPrimary
                                  : Colors.white,
                          fontSize:
                              23,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 1,
                      ),

                      Text(
                        month,
                        style:
                            TextStyle(
                          color:
                              historical
                                  ? AppColors
                                      .textSecondary
                                  : AppColors.gold,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing:
                              0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 13,
                ),

                // =================================================
                // SERVIÇO
                // =================================================

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _StatusChip(
                        style:
                            statusStyle,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        appointment.serviceName,
                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .textPrimary,
                          fontSize:
                              16,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .person_outline_rounded,
                            size:
                                15,
                            color:
                                AppColors
                                    .textSecondary,
                          ),

                          const SizedBox(
                            width: 5,
                          ),

                          Expanded(
                            child: Text(
                              appointment
                                  .professionalName,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  const TextStyle(
                                color:
                                    AppColors
                                        .textSecondary,
                                fontSize:
                                    11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
          ),

          // =====================================================
          // INFORMAÇÕES
          // =====================================================

          Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child:
                Column(
              children: [
                _InformationRow(
                  icon:
                      Icons
                          .calendar_month_outlined,
                  label:
                      'Data',
                  text:
                      '$weekday, $date',
                ),

                const SizedBox(
                  height: 11,
                ),

                _InformationRow(
                  icon:
                      Icons
                          .schedule_outlined,
                  label:
                      'Horário',
                  text:
                      time,
                ),

                const SizedBox(
                  height: 11,
                ),

                _InformationRow(
                  icon:
                      Icons
                          .payments_outlined,
                  label:
                      'Valor',
                  text:
                      price,
                  emphasize:
                      true,
                ),

                // =================================================
                // INFORMAÇÃO PENDENTE
                // =================================================

                if (
                  appointment.status ==
                  'pending_payment'
                ) ...[
                  const SizedBox(
                    height: 15,
                  ),

                  const _PendingInfo(),
                ],

                // =================================================
                // CANCELAR
                // =================================================

                if (canCancel) ...[
                  const SizedBox(
                    height: 17,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        46,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          isCancelling
                              ? null
                              : onCancel,
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            AppColors.error,
                        side:
                            const BorderSide(
                          color:
                              AppColors.error,
                        ),
                      ),
                      icon:
                          isCancelling
                              ? const SizedBox(
                                  width:
                                      17,
                                  height:
                                      17,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .event_busy_outlined,
                                  size:
                                      18,
                                ),
                      label:
                          Text(
                        isCancelling
                            ? 'CANCELANDO...'
                            : 'CANCELAR AGENDAMENTO',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS
// ============================================================

class _StatusChip extends StatelessWidget {
  final _AppointmentStatusStyle style;

  const _StatusChip({
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            style.backgroundColor,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size:
                13,
            color:
                style.foregroundColor,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            style.label,
            style:
                TextStyle(
              color:
                  style.foregroundColor,
              fontSize:
                  8.5,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ESTILO POR STATUS
// ============================================================

class _AppointmentStatusStyle {
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _AppointmentStatusStyle({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  factory _AppointmentStatusStyle.from(
    String status, {
    required bool historical,
  }) {
    final normalized =
        status
            .trim()
            .toLowerCase();

    // ==========================================================
    // CONFIRMADO / CONCLUÍDO
    // ==========================================================

    if (normalized == 'confirmed') {
      if (historical) {
        return const _AppointmentStatusStyle(
          label:
              'CONCLUÍDO',
          icon:
              Icons.check_rounded,
          foregroundColor:
              AppColors.textSecondary,
          backgroundColor:
              AppColors.surfaceSecondary,
        );
      }

      return const _AppointmentStatusStyle(
        label:
            'CONFIRMADO',
        icon:
            Icons
                .check_circle_rounded,
        foregroundColor:
            AppColors.success,
        backgroundColor:
            AppColors.successSoft,
      );
    }

    // ==========================================================
    // AGUARDANDO PAGAMENTO
    // ==========================================================

    if (
      normalized ==
      'pending_payment'
    ) {
      return const _AppointmentStatusStyle(
        label:
            'AGUARDANDO PAGAMENTO',
        icon:
            Icons
                .hourglass_top_rounded,
        foregroundColor:
            AppColors.warning,
        backgroundColor:
            AppColors.warningSoft,
      );
    }

    // ==========================================================
    // CANCELADO
    // ==========================================================

    if (
      normalized == 'cancelled' ||
      normalized == 'canceled'
    ) {
      return const _AppointmentStatusStyle(
        label:
            'CANCELADO',
        icon:
            Icons.close_rounded,
        foregroundColor:
            AppColors.error,
        backgroundColor:
            AppColors.errorSoft,
      );
    }

    // ==========================================================
    // EXPIRADO
    // ==========================================================

    if (normalized == 'expired') {
      return const _AppointmentStatusStyle(
        label:
            'EXPIRADO',
        icon:
            Icons.timer_off_outlined,
        foregroundColor:
            AppColors.textSecondary,
        backgroundColor:
            AppColors.surfaceSecondary,
      );
    }

    // ==========================================================
    // PADRÃO
    // ==========================================================

    return _AppointmentStatusStyle(
      label:
          normalized
              .replaceAll(
                '_',
                ' ',
              )
              .toUpperCase(),
      icon:
          Icons.info_outline_rounded,
      foregroundColor:
          AppColors.textSecondary,
      backgroundColor:
          AppColors.surfaceSecondary,
    );
  }
}

// ============================================================
// INFORMAÇÕES
// ============================================================

class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final bool emphasize;

  const _InformationRow({
    required this.icon,
    required this.label,
    required this.text,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width:
              37,
          height:
              37,
          decoration:
              BoxDecoration(
            color:
                AppColors.goldSoft,
            borderRadius:
                BorderRadius.circular(
              11,
            ),
          ),
          child:
              Icon(
            icon,
            size:
                18,
            color:
                AppColors.goldDark,
          ),
        ),

        const SizedBox(
          width:
              11,
        ),

        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  color:
                      AppColors
                          .textSecondary,
                  fontSize:
                      9.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    2,
              ),

              Text(
                text,
                style:
                    TextStyle(
                  color:
                      AppColors
                          .textPrimary,
                  fontSize:
                      emphasize
                          ? 14
                          : 12.5,
                  fontWeight:
                      emphasize
                          ? FontWeight.w800
                          : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// INFORMAÇÃO AGUARDANDO PAGAMENTO
// ============================================================

class _PendingInfo extends StatelessWidget {
  const _PendingInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.warningSoft,
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child:
          const Row(
        children: [
          Icon(
            Icons
                .info_outline_rounded,
            color:
                AppColors.warning,
            size:
                18,
          ),

          SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              'Este horário ainda está aguardando '
              'a conclusão do pagamento.',
              style:
                  TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize:
                    10.5,
                height:
                    1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TÍTULO DA SEÇÃO
// ============================================================

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color:
              AppColors.goldDark,
          size:
              20,
        ),

        const SizedBox(
          width:
              8,
        ),

        Expanded(
          child:
              Text(
            title,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal:
                9,
            vertical:
                5,
          ),
          decoration:
              BoxDecoration(
            color:
                AppColors.goldSoft,
            borderRadius:
                BorderRadius.circular(
              30,
            ),
          ),
          child:
              Text(
            '$count',
            style:
                const TextStyle(
              color:
                  AppColors.goldDark,
              fontSize:
                  10,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SEM PRÓXIMOS
// ============================================================

class _NoUpcomingAppointments
    extends StatelessWidget {
  const _NoUpcomingAppointments();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          17,
        ),
        border:
            Border.all(
          color:
              AppColors.border,
        ),
      ),
      child:
          const Row(
        children: [
          CircleAvatar(
            radius:
                23,
            backgroundColor:
                AppColors.goldSoft,
            child:
                Icon(
              Icons
                  .event_note_outlined,
              color:
                  AppColors.goldDark,
              size:
                  23,
            ),
          ),

          SizedBox(
            width:
                13,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Nenhum próximo horário',
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textPrimary,
                    fontSize:
                        13.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height:
                      3,
                ),

                Text(
                  'Quando você tiver um atendimento '
                  'confirmado, ele aparecerá aqui.',
                  style:
                      TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize:
                        10.5,
                    height:
                        1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NENHUM AGENDAMENTO
// ============================================================

class _EmptyAppointments
    extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  92,
              height:
                  92,
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.goldSoft,
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .calendar_month_outlined,
                color:
                    AppColors.goldDark,
                size:
                    42,
              ),
            ),

            const SizedBox(
              height:
                  22,
            ),

            const Text(
              'Nenhum agendamento',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize:
                    22,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            const Text(
              'Seus próximos horários e seu histórico '
              'de atendimentos aparecerão aqui.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize:
                    13,
                height:
                    1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _AppointmentsLoading
    extends StatelessWidget {
  const _AppointmentsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          CircularProgressIndicator(),

          SizedBox(
            height:
                16,
          ),

          Text(
            'Carregando seus agendamentos...',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERRO
// ============================================================

class _AppointmentsError
    extends StatelessWidget {
  const _AppointmentsError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  82,
              height:
                  82,
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.errorSoft,
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .error_outline_rounded,
                size:
                    38,
                color:
                    AppColors.error,
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            const Text(
              'Não foi possível carregar seus agendamentos',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize:
                    20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            const Text(
              'Verifique sua conexão e tente novamente.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors.textSecondary,
                fontSize:
                    13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}