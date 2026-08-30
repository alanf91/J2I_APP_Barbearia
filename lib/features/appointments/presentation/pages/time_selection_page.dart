import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/data/models/professional_availability.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/availability_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/appointment_summary_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class TimeSelectionPage extends StatefulWidget {
  final BarbershopService service;
  final Professional professional;
  final DateTime date;

  const TimeSelectionPage({
    super.key,
    required this.service,
    required this.professional,
    required this.date,
  });

  @override
  State<TimeSelectionPage> createState() => _TimeSelectionPageState();
}

class _TimeSelectionPageState extends State<TimeSelectionPage> {
  final AvailabilityRepository _availabilityRepository =
      AvailabilityRepository();

  final AppointmentRepository _appointmentRepository =
      AppointmentRepository();

  late Future<ProfessionalAvailability?> _availabilityFuture;

  int? _selectedStartMinutes;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _availabilityFuture =
        _availabilityRepository.getAvailabilityForDate(
      professionalId: widget.professional.id,
      date: widget.date,
    );
  }

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
  // PREÇO
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
  // MÊS
  // ============================================================

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'janeiro';

      case 2:
        return 'fevereiro';

      case 3:
        return 'março';

      case 4:
        return 'abril';

      case 5:
        return 'maio';

      case 6:
        return 'junho';

      case 7:
        return 'julho';

      case 8:
        return 'agosto';

      case 9:
        return 'setembro';

      case 10:
        return 'outubro';

      case 11:
        return 'novembro';

      case 12:
        return 'dezembro';

      default:
        return '';
    }
  }

  // ============================================================
  // DATA
  // ============================================================

  String _formatDate(DateTime date) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)}';
  }

  // ============================================================
  // GERAR HORÁRIOS DISPONÍVEIS
  // ============================================================

  List<int> _generateAvailableTimes(
    ProfessionalAvailability availability,
    Set<int> occupiedSlots,
  ) {
    if (!availability.enabled) {
      return [];
    }

    if (availability.startMinutes >=
        availability.endMinutes) {
      return [];
    }

    final serviceDuration =
        widget.service.durationMinutes;

    if (serviceDuration <= 0) {
      return [];
    }

    final interval =
        availability.intervalMinutes > 0
            ? availability.intervalMinutes
            : 30;

    final times = <int>[];

    var current =
        availability.startMinutes;

    while (
      current + serviceDuration <=
          availability.endMinutes
    ) {
      final hasConflict =
          _hasOccupiedSlot(
        startMinutes: current,
        endMinutes:
            current + serviceDuration,
        occupiedSlots: occupiedSlots,
      );

      final isPast =
          _isPastTime(current);

      if (!hasConflict && !isPast) {
        times.add(current);
      }

      current += interval;
    }

    return times;
  }

  // ============================================================
  // CONFLITO COM HORÁRIO OCUPADO
  // ============================================================

  bool _hasOccupiedSlot({
    required int startMinutes,
    required int endMinutes,
    required Set<int> occupiedSlots,
  }) {
    var current =
        startMinutes;

    while (current < endMinutes) {
      if (occupiedSlots.contains(current)) {
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

  bool _isPastTime(int startMinutes) {
    final now =
        DateTime.now();

    final selectedDay =
        DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );

    final today =
        DateTime(
      now.year,
      now.month,
      now.day,
    );

    if (selectedDay.isBefore(today)) {
      return true;
    }

    if (!selectedDay.isAtSameMomentAs(today)) {
      return false;
    }

    final candidate =
        selectedDay.add(
      Duration(
        minutes: startMinutes,
      ),
    );

    return candidate.isBefore(now);
  }

  // ============================================================
  // SELECIONAR HORÁRIO
  // ============================================================

  void _selectTime(int minutes) {
    setState(() {
      _selectedStartMinutes =
          minutes;
    });
  }

  // ============================================================
  // CONTINUAR
  // ============================================================

  void _continue(
    List<int> availableTimes,
  ) {
    final selected =
        _selectedStartMinutes;

    if (selected == null) {
      return;
    }

    if (!availableTimes.contains(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este horário não está mais disponível. '
            'Escolha outro horário.',
          ),
        ),
      );

      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                AppointmentSummaryPage(
          service: widget.service,
          professional:
              widget.professional,
          date: widget.date,
          startMinutes: selected,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Escolha o horário',
        ),
      ),

      body:
          FutureBuilder<
              ProfessionalAvailability?>(
        future: _availabilityFuture,

        builder:
            (
              context,
              availabilitySnapshot,
            ) {
          // ======================================================
          // CARREGANDO DISPONIBILIDADE
          // ======================================================

          if (
            availabilitySnapshot
                    .connectionState ==
                ConnectionState.waiting
          ) {
            return const _HoursLoading();
          }

          // ======================================================
          // ERRO
          // ======================================================

          if (availabilitySnapshot.hasError) {
            debugPrint(
              'AVAILABILITY ERROR -> '
              '${availabilitySnapshot.error}',
            );

            return const _AvailabilityError();
          }

          final availability =
              availabilitySnapshot.data;

          // ======================================================
          // PROFISSIONAL NÃO ATENDE NESTE DIA
          // ======================================================

          if (
            availability == null ||
            !availability.enabled
          ) {
            return _NoAvailability(
              date:
                  _formatDate(
                widget.date,
              ),
            );
          }

          // ======================================================
          // HORÁRIOS OCUPADOS
          // ======================================================

          return StreamBuilder<Set<int>>(
            stream:
                _appointmentRepository
                    .watchBookedSlotMinutes(
              professionalId:
                  widget.professional.id,
              date: widget.date,
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
                return const _HoursLoading();
              }

              if (bookedSnapshot.hasError) {
                debugPrint(
                  'BOOKED SLOTS ERROR -> '
                  '${bookedSnapshot.error}',
                );

                return const _AvailabilityError();
              }

              final occupiedSlots =
                  bookedSnapshot.data ??
                      <int>{};

              final times =
                  _generateAvailableTimes(
                availability,
                occupiedSlots,
              );

              // ==================================================
              // SEM HORÁRIOS LIVRES
              // ==================================================

              if (times.isEmpty) {
                return _NoFreeTimes(
                  date:
                      _formatDate(
                    widget.date,
                  ),
                );
              }

              final selected =
                  _selectedStartMinutes;

              final selectedIsAvailable =
                  selected != null &&
                  times.contains(selected);

              // ==================================================
              // TELA PRINCIPAL
              // ==================================================

              return SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          18,
                          14,
                          18,
                          30,
                        ),

                        children: [
                          // =======================================
                          // PROGRESSO
                          // =======================================

                          const _BookingProgress(),

                          const SizedBox(
                            height: 18,
                          ),

                          // =======================================
                          // RESUMO
                          // =======================================

                          _BookingSummaryCard(
                            service:
                                widget.service,

                            professional:
                                widget
                                    .professional,

                            date:
                                _formatDate(
                              widget.date,
                            ),

                            formattedPrice:
                                _formatPrice(
                              widget
                                  .service
                                  .priceCents,
                            ),
                          ),

                          const SizedBox(
                            height: 28,
                          ),

                          // =======================================
                          // TÍTULO
                          // =======================================

                          Text(
                            'Qual horário fica melhor para você?',

                            style:
                                Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontSize:
                                          24,
                                      fontWeight:
                                          FontWeight
                                              .w800,
                                      letterSpacing:
                                          -0.5,
                                    ),
                          ),

                          const SizedBox(
                            height: 7,
                          ),

                          Text(
                            'Escolha um dos horários disponíveis '
                            'para ${widget.professional.name}.',

                            style:
                                Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          AppColors
                                              .textSecondary,
                                      fontSize:
                                          13.5,
                                      height:
                                          1.4,
                                    ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          // =======================================
                          // HORÁRIO DE ATENDIMENTO
                          // =======================================

                          _WorkingHoursCard(
                            startTime:
                                _formatTime(
                              availability
                                  .startMinutes,
                            ),

                            endTime:
                                _formatTime(
                              availability
                                  .endMinutes,
                            ),

                            availableCount:
                                times.length,
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // =======================================
                          // CABEÇALHO DA GRADE
                          // =======================================

                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .schedule_rounded,
                                size: 20,
                                color:
                                    AppColors
                                        .goldDark,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Text(
                                'Horários disponíveis',

                                style:
                                    Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight
                                                  .w800,
                                        ),
                              ),

                              const Spacer(),

                              Text(
                                '${times.length} '
                                '${times.length == 1 ? 'horário' : 'horários'}',

                                style:
                                    const TextStyle(
                                  color:
                                      AppColors
                                          .textSecondary,
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 13,
                          ),

                          // =======================================
                          // GRADE DE HORÁRIOS
                          // =======================================

                          GridView.builder(
                            shrinkWrap: true,

                            physics:
                                const NeverScrollableScrollPhysics(),

                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio:
                                  2.05,
                            ),

                            itemCount:
                                times.length,

                            itemBuilder:
                                (
                                  context,
                                  index,
                                ) {
                              final time =
                                  times[index];

                              final isSelected =
                                  selectedIsAvailable &&
                                  selected == time;

                              return _TimeCard(
                                time:
                                    _formatTime(
                                  time,
                                ),
                                selected:
                                    isSelected,
                                onTap:
                                    () {
                                  _selectTime(
                                    time,
                                  );
                                },
                              );
                            },
                          ),

                          // =======================================
                          // HORÁRIO SELECIONADO
                          // =======================================

                          if (selectedIsAvailable) ...[
                            const SizedBox(
                              height: 28,
                            ),

                            Text(
                              'Horário selecionado',

                              style:
                                  Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w800,
                                      ),
                            ),

                            const SizedBox(
                              height: 11,
                            ),

                            _SelectedTimeCard(
                              startTime:
                                  _formatTime(
                                selected,
                              ),

                              endTime:
                                  _formatTime(
                                selected +
                                    widget
                                        .service
                                        .durationMinutes,
                              ),

                              durationMinutes:
                                  widget
                                      .service
                                      .durationMinutes,
                            ),
                          ],

                          const SizedBox(
                            height: 12,
                          ),
                        ],
                      ),
                    ),

                    // =============================================
                    // CONTINUAR
                    // =============================================

                    _BottomContinueButton(
                      enabled:
                          selectedIsAvailable,
                      onPressed:
                          () {
                        _continue(times);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// PROGRESSO DO AGENDAMENTO
// ============================================================

class _BookingProgress extends StatelessWidget {
  const _BookingProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),

      decoration:
          BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(17),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),

      child: const Row(
        children: [
          _ProgressItem(
            icon: Icons.check_rounded,
            label: 'Serviço',
            completed: true,
          ),

          _ProgressLine(
            active: true,
          ),

          _ProgressItem(
            icon: Icons.check_rounded,
            label: 'Profissional',
            completed: true,
          ),

          _ProgressLine(
            active: true,
          ),

          _ProgressItem(
            icon: Icons.check_rounded,
            label: 'Data',
            completed: true,
          ),

          _ProgressLine(
            active: true,
          ),

          _ProgressItem(
            icon:
                Icons.schedule_rounded,
            label: 'Horário',
            active: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ITEM DO PROGRESSO
// ============================================================

class _ProgressItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool completed;
  final bool active;

  const _ProgressItem({
    required this.icon,
    required this.label,
    this.completed = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted =
        completed || active;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 31,
            height: 31,

            decoration:
                BoxDecoration(
              color:
                  completed
                      ? AppColors.black
                      : active
                          ? AppColors.gold
                          : AppColors
                              .surfaceSecondary,
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              size: 16,
              color:
                  completed
                      ? AppColors.gold
                      : active
                          ? AppColors.black
                          : AppColors
                              .textSecondary,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              color:
                  highlighted
                      ? AppColors
                          .textPrimary
                      : AppColors
                          .textSecondary,
              fontSize: 8.5,
              fontWeight:
                  highlighted
                      ? FontWeight.w700
                      : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LINHA DO PROGRESSO
// ============================================================

class _ProgressLine extends StatelessWidget {
  final bool active;

  const _ProgressLine({
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 2,
      margin:
          const EdgeInsets.only(
        bottom: 19,
      ),
      color:
          active
              ? AppColors.gold
              : AppColors.border,
    );
  }
}

// ============================================================
// RESUMO
// ============================================================

class _BookingSummaryCard extends StatelessWidget {
  final BarbershopService service;
  final Professional professional;
  final String date;
  final String formattedPrice;

  const _BookingSummaryCard({
    required this.service,
    required this.professional,
    required this.date,
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),

      decoration:
          BoxDecoration(
        color: AppColors.black,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: Column(
        children: [
          _PremiumSummaryRow(
            icon:
                Icons
                    .content_cut_rounded,
            label: 'SERVIÇO',
            value: service.name,
            subtitle:
                '${service.durationMinutes} min'
                '  •  '
                '$formattedPrice',
            highlighted: true,
          ),

          const Divider(
            height: 26,
            color: AppColors.graphite,
          ),

          _PremiumSummaryRow(
            icon:
                Icons
                    .person_outline_rounded,
            label: 'PROFISSIONAL',
            value: professional.name,
            subtitle:
                professional.specialty,
          ),

          const Divider(
            height: 26,
            color: AppColors.graphite,
          ),

          _PremiumSummaryRow(
            icon:
                Icons
                    .calendar_month_outlined,
            label: 'DATA',
            value: date,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LINHA DO RESUMO
// ============================================================

class _PremiumSummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool highlighted;

  const _PremiumSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle =
        subtitle != null &&
        subtitle!.trim().isNotEmpty;

    return Row(
      children: [
        Container(
          width: 43,
          height: 43,

          decoration:
              BoxDecoration(
            color:
                highlighted
                    ? AppColors.gold
                    : AppColors.graphite,

            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),

          child: Icon(
            icon,
            size: 21,
            color:
                highlighted
                    ? AppColors.black
                    : AppColors.gold,
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  color: AppColors.gold,
                  fontSize: 8.5,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight:
                      FontWeight.w700,
                  height: 1.25,
                ),
              ),

              if (hasSubtitle) ...[
                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle!,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFFBDB9B3,
                    ),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),

        const Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.success,
        ),
      ],
    );
  }
}

// ============================================================
// HORÁRIO DE FUNCIONAMENTO
// ============================================================

class _WorkingHoursCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final int availableCount;

  const _WorkingHoursCard({
    required this.startTime,
    required this.endTime,
    required this.availableCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(15),

      decoration:
          BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color: AppColors.black,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                const Icon(
              Icons.access_time_rounded,
              color: AppColors.gold,
              size: 21,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Atendimento neste dia',
                  style: TextStyle(
                    color:
                        AppColors
                            .textPrimary,
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  '$startTime às $endTime',
                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),

            decoration:
                BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),

            child: Text(
              '$availableCount livres',
              style:
                  const TextStyle(
                color:
                    AppColors.goldDark,
                fontSize: 10,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DE HORÁRIO
// ============================================================

class _TimeCard extends StatelessWidget {
  final String time;
  final bool selected;
  final VoidCallback onTap;

  const _TimeCard({
    required this.time,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected
              ? AppColors.black
              : AppColors.surface,

      borderRadius:
          BorderRadius.circular(14),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(14),

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 160,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              14,
            ),

            border:
                Border.all(
              color:
                  selected
                      ? AppColors.gold
                      : AppColors.border,
              width:
                  selected
                      ? 1.5
                      : 1,
            ),
          ),

          alignment:
              Alignment.center,

          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppColors.gold,
                ),

                const SizedBox(
                  width: 5,
                ),
              ],

              Text(
                time,
                style: TextStyle(
                  color:
                      selected
                          ? Colors.white
                          : AppColors
                              .textPrimary,
                  fontSize: 14,
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
// HORÁRIO SELECIONADO
// ============================================================

class _SelectedTimeCard extends StatelessWidget {
  final String startTime;
  final String endTime;
  final int durationMinutes;

  const _SelectedTimeCard({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color: AppColors.goldSoft,

        borderRadius:
            BorderRadius.circular(17),

        border:
            Border.all(
          color: AppColors.gold,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color: AppColors.black,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child:
                const Icon(
              Icons.schedule_rounded,
              color: AppColors.gold,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'HORÁRIO SELECIONADO',
                  style: TextStyle(
                    color:
                        AppColors.goldDark,
                    fontSize: 9,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '$startTime às $endTime',
                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .textPrimary,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  'Duração prevista: '
                  '$durationMinutes min',
                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 22,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTÃO INFERIOR
// ============================================================

class _BottomContinueButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _BottomContinueButton({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,

      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          16,
        ),

        decoration:
            const BoxDecoration(
          color: AppColors.background,

          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),

        child: SizedBox(
          width: double.infinity,
          height: 54,

          child: FilledButton(
            onPressed:
                enabled
                    ? onPressed
                    : null,

            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [
                Text(
                  enabled
                      ? 'REVISAR AGENDAMENTO'
                      : 'ESCOLHA UM HORÁRIO',

                  style:
                      const TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),

                if (enabled) ...[
                  const SizedBox(
                    width: 8,
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CARREGAMENTO
// ============================================================

class _HoursLoading extends StatelessWidget {
  const _HoursLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(30),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 18,
            ),

            Text(
              'Consultando horários disponíveis...',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SEM ATENDIMENTO NESTA DATA
// ============================================================

class _NoAvailability extends StatelessWidget {
  final String date;

  const _NoAvailability({
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return _EmptyStateLayout(
      icon:
          Icons.event_busy_outlined,

      title:
          'Sem atendimento nesta data',

      date: date,

      message:
          'Este profissional não possui '
          'atendimento configurado para este dia.',

      buttonText:
          'ESCOLHER OUTRA DATA',
    );
  }
}

// ============================================================
// SEM HORÁRIOS LIVRES
// ============================================================

class _NoFreeTimes extends StatelessWidget {
  final String date;

  const _NoFreeTimes({
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return _EmptyStateLayout(
      icon:
          Icons.schedule_outlined,

      title:
          'Todos os horários estão ocupados',

      date: date,

      message:
          'Não restam horários disponíveis '
          'nesta data. Escolha outro dia para continuar.',

      buttonText:
          'ESCOLHER OUTRA DATA',
    );
  }
}

// ============================================================
// ESTADO VAZIO
// ============================================================

class _EmptyStateLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String message;
  final String buttonText;

  const _EmptyStateLayout({
    required this.icon,
    required this.title,
    required this.date,
    required this.message,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(
            28,
          ),

          child: Column(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              Container(
                width: 86,
                height: 86,

                decoration:
                    const BoxDecoration(
                  color:
                      AppColors.goldSoft,
                  shape:
                      BoxShape.circle,
                ),

                child: Icon(
                  icon,
                  size: 39,
                  color:
                      AppColors.goldDark,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Text(
                title,
                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors
                          .textPrimary,
                  fontSize: 21,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                date,
                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors.goldDark,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                message,
                textAlign:
                    TextAlign.center,

                style:
                    const TextStyle(
                  color:
                      AppColors
                          .textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              SizedBox(
                width: double.infinity,
                height: 50,

                child:
                    OutlinedButton.icon(
                  onPressed:
                      () {
                    Navigator.of(
                      context,
                    ).pop();
                  },

                  icon:
                      const Icon(
                    Icons
                        .arrow_back_rounded,
                  ),

                  label: Text(
                    buttonText,
                  ),
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
// ERRO AO CARREGAR
// ============================================================

class _AvailabilityError extends StatelessWidget {
  const _AvailabilityError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(30),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            CircleAvatar(
              radius: 41,

              backgroundColor:
                  AppColors.errorSoft,

              child: Icon(
                Icons
                    .error_outline_rounded,
                size: 38,
                color: AppColors.error,
              ),
            ),

            SizedBox(
              height: 20,
            ),

            Text(
              'Não foi possível carregar os horários',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors
                        .textPrimary,
                fontSize: 20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            SizedBox(
              height: 9,
            ),

            Text(
              'Verifique sua conexão e tente '
              'novamente em alguns instantes.',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                color:
                    AppColors
                        .textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}