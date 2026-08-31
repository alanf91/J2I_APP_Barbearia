import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/reschedule_appointment.dart';

class AppointmentDetailsPage extends StatelessWidget {
  final BarbershopAppointment appointment;

  const AppointmentDetailsPage({
    super.key,
    required this.appointment,
  });

  // ============================================================
  // HORÁRIO
  // ============================================================

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DATA
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
  // VALOR
  // ============================================================

  String _formatPrice(int priceCents) {
    final reais =
        priceCents ~/ 100;

    final cents =
        (priceCents % 100)
            .toString()
            .padLeft(2, '0');

    return 'R\$ $reais,$cents';
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
  // STATUS
  // ============================================================

  _AppointmentStatusStyle _statusStyle() {
    final status =
        appointment.status
            .trim()
            .toLowerCase();

    if (status == 'confirmed') {
      return const _AppointmentStatusStyle(
        label:
            'CONFIRMADO',
        description:
            'Seu horário está reservado e confirmado.',
        icon:
            Icons.check_circle_rounded,
        foregroundColor:
            AppColors.success,
        backgroundColor:
            AppColors.successSoft,
      );
    }

    if (status == 'pending_payment') {
      return const _AppointmentStatusStyle(
        label:
            'AGUARDANDO PAGAMENTO',
        description:
            'O agendamento ainda aguarda a conclusão do pagamento.',
        icon:
            Icons.hourglass_top_rounded,
        foregroundColor:
            AppColors.warning,
        backgroundColor:
            AppColors.warningSoft,
      );
    }

    if (
      status == 'cancelled' ||
      status == 'canceled'
    ) {
      return const _AppointmentStatusStyle(
        label:
            'CANCELADO',
        description:
            'Este agendamento foi cancelado.',
        icon:
            Icons.cancel_outlined,
        foregroundColor:
            AppColors.error,
        backgroundColor:
            AppColors.errorSoft,
      );
    }

    if (status == 'expired') {
      return const _AppointmentStatusStyle(
        label:
            'EXPIRADO',
        description:
            'O prazo da reserva terminou antes da confirmação.',
        icon:
            Icons.timer_off_outlined,
        foregroundColor:
            AppColors.textSecondary,
        backgroundColor:
            AppColors.surfaceSecondary,
      );
    }

    return _AppointmentStatusStyle(
      label:
          status
              .replaceAll(
                '_',
                ' ',
              )
              .toUpperCase(),
      description:
          'Consulte o status atual deste agendamento.',
      icon:
          Icons.info_outline_rounded,
      foregroundColor:
          AppColors.textSecondary,
      backgroundColor:
          AppColors.surfaceSecondary,
    );
  }

  // ============================================================
  // PODE REAGENDAR?
  // ============================================================

  bool _canReschedule() {
    final status =
        appointment.status
            .trim()
            .toLowerCase();

    return status == 'confirmed' &&
        appointment.startAt.isAfter(
          DateTime.now(),
        );
  }

  // ============================================================
  // ABRIR REAGENDAMENTO
  // ============================================================

  Future<void> _openReschedule(
    BuildContext context,
  ) async {
    final result =
        await Navigator.of(
          context,
        ).push<bool>(
          MaterialPageRoute<bool>(
            builder:
                (_) =>
                    RescheduleAppointmentPage(
              appointment:
                  appointment,
            ),
          ),
        );

    if (
      result != true ||
      !context.mounted
    ) {
      return;
    }

    // ==========================================================
    // O BACKEND JÁ ATUALIZOU:
    //
    // - appointment
    // - novos slots
    // - slots antigos
    //
    // Portanto fechamos também esta página.
    //
    // Ao voltar para "Meus agendamentos", o StreamBuilder
    // receberá os novos dados automaticamente.
    // ==========================================================

    Navigator.of(
      context,
    ).pop(
      true,
    );
  }

  // ============================================================
  // FORMATAR HORÁRIO DE DATETIME
  // ============================================================

  String _formatClockFromDate(
    DateTime date,
  ) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final statusStyle =
        _statusStyle();

    final canReschedule =
        _canReschedule();

    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar:
          AppBar(
        title:
            const Text(
          'Detalhes do agendamento',
        ),
      ),

      body:
          SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            32,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // =================================================
              // HERO
              // =================================================

              _AppointmentHero(
                appointment:
                    appointment,

                statusStyle:
                    statusStyle,

                date:
                    _formatDate(
                  appointment.startAt,
                ),

                weekday:
                    _weekdayName(
                  appointment.startAt,
                ),

                time:
                    '${_formatTime(appointment.startMinutes)} às '
                    '${_formatTime(appointment.endMinutes)}',
              ),

              const SizedBox(
                height:
                    24,
              ),

              // =================================================
              // STATUS
              // =================================================

              const _SectionTitle(
                icon:
                    Icons
                        .verified_outlined,
                title:
                    'Status',
              ),

              const SizedBox(
                height:
                    10,
              ),

              _StatusInformationCard(
                style:
                    statusStyle,
              ),

              const SizedBox(
                height:
                    25,
              ),

              // =================================================
              // ATENDIMENTO
              // =================================================

              const _SectionTitle(
                icon:
                    Icons
                        .content_cut_rounded,
                title:
                    'Atendimento',
              ),

              const SizedBox(
                height:
                    10,
              ),

              _DetailsCard(
                children: [
                  _DetailRow(
                    icon:
                        Icons
                            .content_cut_rounded,
                    label:
                        'Serviço',
                    value:
                        appointment
                            .serviceName,
                  ),

                  const _DetailDivider(),

                  _DetailRow(
                    icon:
                        Icons
                            .person_outline_rounded,
                    label:
                        'Profissional',
                    value:
                        appointment
                            .professionalName,
                  ),

                  const _DetailDivider(),

                  _DetailRow(
                    icon:
                        Icons
                            .schedule_outlined,
                    label:
                        'Duração',
                    value:
                        '${appointment.durationMinutes} minutos',
                  ),
                ],
              ),

              const SizedBox(
                height:
                    25,
              ),

              // =================================================
              // DATA E HORÁRIO
              // =================================================

              const _SectionTitle(
                icon:
                    Icons
                        .calendar_month_outlined,
                title:
                    'Data e horário',
              ),

              const SizedBox(
                height:
                    10,
              ),

              _DetailsCard(
                children: [
                  _DetailRow(
                    icon:
                        Icons
                            .calendar_today_outlined,
                    label:
                        'Data',
                    value:
                        '${_weekdayName(appointment.startAt)}, '
                        '${_formatDate(appointment.startAt)}',
                  ),

                  const _DetailDivider(),

                  _DetailRow(
                    icon:
                        Icons
                            .access_time_rounded,
                    label:
                        'Horário',
                    value:
                        '${_formatTime(appointment.startMinutes)} às '
                        '${_formatTime(appointment.endMinutes)}',
                  ),
                ],
              ),

              const SizedBox(
                height:
                    25,
              ),

              // =================================================
              // VALOR
              // =================================================

              const _SectionTitle(
                icon:
                    Icons
                        .payments_outlined,
                title:
                    'Valor',
              ),

              const SizedBox(
                height:
                    10,
              ),

              Container(
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
                    20,
                  ),
                ),

                child:
                    Row(
                  children: [
                    Container(
                      width:
                          48,
                      height:
                          48,

                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.gold
                                .withValues(
                          alpha:
                              0.14,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                      ),

                      child:
                          const Icon(
                        Icons
                            .payments_outlined,
                        color:
                            AppColors.gold,
                      ),
                    ),

                    const SizedBox(
                      width:
                          14,
                    ),

                    const Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          Text(
                            'VALOR DO SERVIÇO',

                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFFBDB9B3,
                              ),

                              fontSize:
                                  9,

                              fontWeight:
                                  FontWeight.w700,

                              letterSpacing:
                                  0.7,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Text(
                      _formatPrice(
                        appointment
                            .priceCents,
                      ),

                      style:
                          const TextStyle(
                        color:
                            AppColors.gold,

                        fontSize:
                            22,

                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    25,
              ),

              // =================================================
              // REAGENDAR
              // =================================================

              if (canReschedule) ...[
                SizedBox(
                  width:
                      double.infinity,

                  height:
                      54,

                  child:
                      FilledButton.icon(
                    onPressed:
                        () {
                      _openReschedule(
                        context,
                      );
                    },

                    icon:
                        const Icon(
                      Icons
                          .event_repeat_rounded,
                    ),

                    label:
                        const Text(
                      'REAGENDAR HORÁRIO',
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      12,
                ),

                const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons
                          .info_outline_rounded,

                      size:
                          17,

                      color:
                          AppColors.textSecondary,
                    ),

                    SizedBox(
                      width:
                          8,
                    ),

                    Expanded(
                      child:
                          Text(
                        'O serviço, profissional e pagamento serão mantidos. '
                        'Você escolherá somente uma nova data e horário.',

                        style:
                            TextStyle(
                          color:
                              AppColors.textSecondary,

                          fontSize:
                              10.5,

                          height:
                              1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height:
                      25,
                ),
              ],

              // =================================================
              // IDENTIFICAÇÃO
              // =================================================

              const _SectionTitle(
                icon:
                    Icons
                        .receipt_long_outlined,
                title:
                    'Identificação',
              ),

              const SizedBox(
                height:
                    10,
              ),

              _DetailsCard(
                children: [
                  _DetailRow(
                    icon:
                        Icons
                            .tag_rounded,

                    label:
                        'Código do agendamento',

                    value:
                        appointment.id,

                    compact:
                        true,
                  ),

                  if (
                    appointment.createdAt !=
                    null
                  ) ...[
                    const _DetailDivider(),

                    _DetailRow(
                      icon:
                          Icons
                              .history_rounded,

                      label:
                          'Criado em',

                      value:
                          '${_formatDate(appointment.createdAt!)} '
                          'às '
                          '${_formatClockFromDate(appointment.createdAt!)}',

                      compact:
                          true,
                    ),
                  ],
                ],
              ),

              const SizedBox(
                height:
                    20,
              ),

              // =================================================
              // INFORMAÇÃO
              // =================================================

              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(
                  14,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.surfaceSecondary,

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child:
                    const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons
                          .info_outline_rounded,

                      size:
                          19,

                      color:
                          AppColors.textSecondary,
                    ),

                    SizedBox(
                      width:
                          10,
                    ),

                    Expanded(
                      child:
                          Text(
                        'As informações exibidas correspondem '
                        'ao registro atual do agendamento.',

                        style:
                            TextStyle(
                          color:
                              AppColors.textSecondary,

                          fontSize:
                              11,

                          height:
                              1.4,
                        ),
                      ),
                    ),
                  ],
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
// HERO
// ============================================================

class _AppointmentHero
    extends StatelessWidget {
  final BarbershopAppointment appointment;

  final _AppointmentStatusStyle statusStyle;

  final String date;
  final String weekday;
  final String time;

  const _AppointmentHero({
    required this.appointment,
    required this.statusStyle,
    required this.date,
    required this.weekday,
    required this.time,
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
        20,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.black,

        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),

      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width:
                    54,
                height:
                    54,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold
                          .withValues(
                    alpha:
                        0.14,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .content_cut_rounded,

                  color:
                      AppColors.gold,

                  size:
                      26,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      appointment
                          .serviceName,

                      style:
                          const TextStyle(
                        color:
                            Colors.white,

                        fontSize:
                            21,

                        fontWeight:
                            FontWeight.w800,

                        letterSpacing:
                            -0.4,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      appointment
                          .professionalName,

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFFC6C1BA,
                        ),

                        fontSize:
                            12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                20,
          ),

          Container(
            width:
                double.infinity,

            height:
                1,

            color:
                AppColors.graphite,
          ),

          const SizedBox(
            height:
                17,
          ),

          Row(
            children: [
              Expanded(
                child:
                    _HeroInformation(
                  icon:
                      Icons
                          .calendar_today_outlined,

                  label:
                      weekday,

                  value:
                      date,
                ),
              ),

              Container(
                width:
                    1,

                height:
                    42,

                color:
                    AppColors.graphite,
              ),

              Expanded(
                child:
                    _HeroInformation(
                  icon:
                      Icons
                          .schedule_outlined,

                  label:
                      'Horário',

                  value:
                      time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO DO HERO
// ============================================================

class _HeroInformation
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroInformation({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      children: [
        Icon(
          icon,

          size:
              18,

          color:
              AppColors.gold,
        ),

        const SizedBox(
          height:
              6,
        ),

        Text(
          label,

          textAlign:
              TextAlign.center,

          maxLines:
              1,

          overflow:
              TextOverflow.ellipsis,

          style:
              const TextStyle(
            color:
                Color(
              0xFFAAA59F,
            ),

            fontSize:
                9,

            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height:
              3,
        ),

        Text(
          value,

          textAlign:
              TextAlign.center,

          style:
              const TextStyle(
            color:
                Colors.white,

            fontSize:
                12,

            fontWeight:
                FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TÍTULO
// ============================================================

class _SectionTitle
    extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
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
              19,

          color:
              AppColors.goldDark,
        ),

        const SizedBox(
          width:
              8,
        ),

        Text(
          title,

          style:
              const TextStyle(
            color:
                AppColors.textPrimary,

            fontSize:
                16,

            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STATUS
// ============================================================

class _StatusInformationCard
    extends StatelessWidget {
  final _AppointmentStatusStyle style;

  const _StatusInformationCard({
    required this.style,
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
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            style.backgroundColor,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child:
          Row(
        children: [
          Container(
            width:
                46,
            height:
                46,

            decoration:
                BoxDecoration(
              color:
                  Colors.white
                      .withValues(
                alpha:
                    0.70,
              ),

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              style.icon,

              color:
                  style.foregroundColor,

              size:
                  24,
            ),
          ),

          const SizedBox(
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
                  style.label,

                  style:
                      TextStyle(
                    color:
                        style
                            .foregroundColor,

                    fontSize:
                        11,

                    fontWeight:
                        FontWeight.w800,

                    letterSpacing:
                        0.4,
                  ),
                ),

                const SizedBox(
                  height:
                      4,
                ),

                Text(
                  style.description,

                  style:
                      const TextStyle(
                    color:
                        AppColors.textSecondary,

                    fontSize:
                        11,

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
// CARD DE DETALHES
// ============================================================

class _DetailsCard
    extends StatelessWidget {
  final List<Widget> children;

  const _DetailsCard({
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.symmetric(
        horizontal:
            15,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.surface,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              AppColors.border,
        ),
      ),

      child:
          Column(
        children:
            children,
      ),
    );
  }
}

// ============================================================
// LINHA
// ============================================================

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            15,
      ),

      child:
          Row(
        children: [
          Container(
            width:
                40,
            height:
                40,

            decoration:
                BoxDecoration(
              color:
                  AppColors.goldSoft,

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                Icon(
              icon,

              color:
                  AppColors.goldDark,

              size:
                  19,
            ),
          ),

          const SizedBox(
            width:
                12,
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
                        AppColors.textSecondary,

                    fontSize:
                        9.5,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  value,

                  maxLines:
                      compact
                          ? 2
                          : 3,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      TextStyle(
                    color:
                        AppColors.textPrimary,

                    fontSize:
                        compact
                            ? 11
                            : 13,

                    fontWeight:
                        FontWeight.w700,
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
// DIVISOR
// ============================================================

class _DetailDivider
    extends StatelessWidget {
  const _DetailDivider();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Divider(
      height:
          1,

      color:
          AppColors.border,
    );
  }
}

// ============================================================
// ESTILO DO STATUS
// ============================================================

class _AppointmentStatusStyle {
  final String label;
  final String description;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  const _AppointmentStatusStyle({
    required this.label,
    required this.description,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });
}