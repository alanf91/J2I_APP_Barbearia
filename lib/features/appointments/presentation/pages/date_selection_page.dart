import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/time_selection_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class DateSelectionPage extends StatefulWidget {
  final BarbershopService service;
  final Professional professional;

  const DateSelectionPage({
    super.key,
    required this.service,
    required this.professional,
  });

  @override
  State<DateSelectionPage> createState() =>
      _DateSelectionPageState();
}

class _DateSelectionPageState
    extends State<DateSelectionPage> {
  DateTime? _selectedDate;

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

    _lastAllowedDate =
        _today.add(
      const Duration(days: 30),
    );
  }

  // ============================================================
  // PREÇO
  // ============================================================

  String _formatPrice(
    int priceCents,
  ) {
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

  // ============================================================
  // MÊS
  // ============================================================

  String _monthName(
    int month,
  ) {
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
  // DATA COMPLETA
  // ============================================================

  String _formatFullDate(
    DateTime date,
  ) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)} de '
        '${date.year}';
  }

  // ============================================================
  // DIA CURTO
  // ============================================================

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
  // CALENDÁRIO COMPLETO
  // ============================================================

  Future<void> _openCalendar() async {
    final pickedDate =
        await showDatePicker(
      context: context,

      initialDate:
          _selectedDate ??
              _today,

      firstDate:
          _today,

      lastDate:
          _lastAllowedDate,

      helpText:
          'Escolha a data',

      cancelText:
          'CANCELAR',

      confirmText:
          'CONFIRMAR',
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate =
          DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  // ============================================================
  // SELECIONAR DATA
  // ============================================================

  void _selectDate(
    DateTime date,
  ) {
    setState(() {
      _selectedDate =
          date;
    });
  }

  // ============================================================
  // CONTINUAR
  // ============================================================

  void _continue() {
    final date =
        _selectedDate;

    if (date == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                TimeSelectionPage(
          service:
              widget.service,

          professional:
              widget.professional,

          date:
              date,
        ),
      ),
    );
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final nextDates =
        List.generate(
      14,
      (index) =>
          _today.add(
        Duration(
          days: index,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Escolha a data',
        ),
      ),

      body: SafeArea(
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
                  // ===============================================
                  // PROGRESSO
                  // ===============================================

                  const _BookingProgress(),

                  const SizedBox(
                    height: 18,
                  ),

                  // ===============================================
                  // RESUMO
                  // ===============================================

                  _BookingSummaryCard(
                    service:
                        widget.service,

                    professional:
                        widget.professional,

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

                  // ===============================================
                  // TÍTULO
                  // ===============================================

                  Text(
                    'Quando você quer ser atendido?',

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
                    'Escolha uma data para consultar '
                    'os horários disponíveis com '
                    '${widget.professional.name}.',

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
                    height: 24,
                  ),

                  // ===============================================
                  // PRÓXIMOS DIAS
                  // ===============================================

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .calendar_today_outlined,

                        size:
                            19,

                        color:
                            AppColors
                                .goldDark,
                      ),

                      const SizedBox(
                        width:
                            8,
                      ),

                      Text(
                        'Próximos dias',

                        style:
                            Theme.of(
                          context,
                        )
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
                    ],
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  SizedBox(
                    height: 102,

                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,

                      itemCount:
                          nextDates
                              .length,

                      separatorBuilder:
                          (_, _) =>
                              const SizedBox(
                        width: 9,
                      ),

                      itemBuilder:
                          (
                            context,
                            index,
                          ) {
                        final date =
                            nextDates[
                                index];

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

                          isToday:
                              _isSameDay(
                            _today,
                            date,
                          ),

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
                    height: 16,
                  ),

                  // ===============================================
                  // CALENDÁRIO
                  // ===============================================

                  SizedBox(
                    width:
                        double.infinity,

                    height:
                        50,

                    child:
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
                  ),

                  // ===============================================
                  // DATA SELECIONADA
                  // ===============================================

                  if (
                    _selectedDate !=
                        null
                  ) ...[
                    const SizedBox(
                      height: 28,
                    ),

                    Text(
                      'Data selecionada',

                      style:
                          Theme.of(
                        context,
                      )
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

                    _SelectedDateCard(
                      formattedDate:
                          _formatFullDate(
                        _selectedDate!,
                      ),
                    ),
                  ],

                  const SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),

            // ===================================================
            // BOTÃO INFERIOR
            // ===================================================

            _BottomContinueButton(
              selectedDate:
                  _selectedDate,

              onPressed:
                  _continue,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROGRESSO DO AGENDAMENTO
// ============================================================

class _BookingProgress
    extends StatelessWidget {
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

      child: const Row(
        children: [
          _ProgressItem(
            icon:
                Icons
                    .check_rounded,

            label:
                'Serviço',

            completed:
                true,
          ),

          _ProgressLine(
            active:
                true,
          ),

          _ProgressItem(
            icon:
                Icons
                    .check_rounded,

            label:
                'Profissional',

            completed:
                true,
          ),

          _ProgressLine(
            active:
                true,
          ),

          _ProgressItem(
            icon:
                Icons
                    .calendar_today_rounded,

            label:
                'Data',

            active:
                true,
          ),

          _ProgressLine(),

          _ProgressItem(
            icon:
                Icons
                    .schedule_rounded,

            label:
                'Horário',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ITEM DE PROGRESSO
// ============================================================

class _ProgressItem
    extends StatelessWidget {
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
        completed ||
        active;

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
                      ? AppColors
                          .black
                      : active
                          ? AppColors
                              .gold
                          : AppColors
                              .surfaceSecondary,

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              icon,

              size:
                  16,

              color:
                  completed
                      ? AppColors
                          .gold
                      : active
                          ? AppColors
                              .black
                          : AppColors
                              .textSecondary,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            label,

            maxLines:
                1,

            overflow:
                TextOverflow
                    .ellipsis,

            style:
                TextStyle(
              color:
                  highlighted
                      ? AppColors
                          .textPrimary
                      : AppColors
                          .textSecondary,

              fontSize:
                  8.5,

              fontWeight:
                  highlighted
                      ? FontWeight
                          .w700
                      : FontWeight
                          .w500,
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

class _ProgressLine
    extends StatelessWidget {
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

class _BookingSummaryCard
    extends StatelessWidget {
  final BarbershopService service;
  final Professional professional;
  final String formattedPrice;

  const _BookingSummaryCard({
    required this.service,
    required this.professional,
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    final specialty =
        professional
            .specialty
            .trim();

    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(
        17,
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

      child: Column(
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                width: 47,
                height: 47,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold,

                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .content_cut_rounded,

                  color:
                      AppColors.black,

                  size: 22,
                ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Text(
                      'SEU ATENDIMENTO',

                      style:
                          TextStyle(
                        color:
                            AppColors.gold,

                        fontSize:
                            9.5,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            0.8,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      service.name,

                      style:
                          const TextStyle(
                        color:
                            Colors.white,

                        fontSize:
                            16,

                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '${service.durationMinutes} min'
                      '  •  '
                      '$formattedPrice',

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFFD0CCC6,
                        ),

                        fontSize:
                            11.5,

                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(
            height: 28,
            color:
                AppColors.graphite,
          ),

          Row(
            children: [
              Container(
                width: 43,
                height: 43,

                alignment:
                    Alignment.center,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .graphite,

                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),

                child:
                    Text(
                  professional
                          .name
                          .trim()
                          .isNotEmpty
                      ? professional
                          .name
                          .trim()
                          .substring(
                            0,
                            1,
                          )
                          .toUpperCase()
                      : '?',

                  style:
                      const TextStyle(
                    color:
                        AppColors.gold,

                    fontSize:
                        18,

                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Text(
                      'PROFISSIONAL',

                      style:
                          TextStyle(
                        color:
                            AppColors.gold,

                        fontSize:
                            9,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            0.7,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      professional.name,

                      style:
                          const TextStyle(
                        color:
                            Colors.white,

                        fontSize:
                            14.5,

                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    if (
                      specialty
                          .isNotEmpty
                    ) ...[
                      const SizedBox(
                        height: 2,
                      ),

                      Text(
                        specialty,

                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFFB7B3AD,
                          ),

                          fontSize:
                              10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Icon(
                Icons
                    .check_circle_rounded,

                color:
                    AppColors.success,

                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DA DATA
// ============================================================

class _DateCard
    extends StatelessWidget {
  final DateTime date;
  final String weekday;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  const _DateCard({
    required this.date,
    required this.weekday,
    required this.selected,
    required this.isToday,
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
          BorderRadius.circular(
        17,
      ),

      child: InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 180,
          ),

          width: 70,

          padding:
              const EdgeInsets.symmetric(
            vertical: 11,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              17,
            ),

            border:
                Border.all(
              color:
                  selected
                      ? AppColors
                          .gold
                      : AppColors
                          .border,

              width:
                  selected
                      ? 1.5
                      : 1,
            ),
          ),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Text(
                weekday,

                style:
                    TextStyle(
                  color:
                      selected
                          ? AppColors
                              .gold
                          : AppColors
                              .textSecondary,

                  fontSize:
                      10,

                  fontWeight:
                      FontWeight
                          .w700,
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
                          ? Colors
                              .white
                          : AppColors
                              .textPrimary,

                  fontSize:
                      24,

                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),

              const SizedBox(
                height: 3,
              ),

              if (isToday)
                Text(
                  'HOJE',

                  style:
                      TextStyle(
                    color:
                        selected
                            ? AppColors
                                .gold
                            : AppColors
                                .goldDark,

                    fontSize:
                        8,

                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                )
              else
                const SizedBox(
                  height: 10,
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
  final String formattedDate;

  const _SelectedDateCard({
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
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
            AppColors.goldSoft,

        borderRadius:
            BorderRadius.circular(
          17,
        ),

        border:
            Border.all(
          color:
              AppColors.gold,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration:
                BoxDecoration(
              color:
                  AppColors.black,

              borderRadius:
                  BorderRadius
                      .circular(
                13,
              ),
            ),

            child:
                const Icon(
              Icons
                  .event_available_rounded,

              color:
                  AppColors.gold,

              size: 23,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'DATA CONFIRMADA',

                  style:
                      TextStyle(
                    color:
                        AppColors.goldDark,

                    fontSize:
                        9,

                    fontWeight:
                        FontWeight
                            .w800,

                    letterSpacing:
                        0.7,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  formattedDate,

                  style:
                      const TextStyle(
                    color:
                        AppColors
                            .textPrimary,

                    fontSize:
                        14,

                    fontWeight:
                        FontWeight
                            .w800,

                    height:
                        1.3,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .check_circle_rounded,

            color:
                AppColors.success,

            size: 22,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTÃO CONTINUAR
// ============================================================

class _BottomContinueButton
    extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onPressed;

  const _BottomContinueButton({
    required this.selectedDate,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled =
        selectedDate != null;

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
          color:
              AppColors.background,

          border:
              Border(
            top:
                BorderSide(
              color:
                  AppColors.border,
            ),
          ),
        ),

        child: SizedBox(
          width:
              double.infinity,

          height:
              54,

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
                      ? 'VER HORÁRIOS DISPONÍVEIS'
                      : 'ESCOLHA UMA DATA',

                  style:
                      const TextStyle(
                    fontSize:
                        12.5,

                    fontWeight:
                        FontWeight
                            .w800,

                    letterSpacing:
                        0.3,
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