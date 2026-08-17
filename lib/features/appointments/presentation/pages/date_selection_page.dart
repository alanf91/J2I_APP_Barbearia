import 'package:flutter/material.dart';

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
  State<DateSelectionPage> createState() => _DateSelectionPageState();
}

class _DateSelectionPageState extends State<DateSelectionPage> {
  DateTime? _selectedDate;

  late final DateTime _today;
  late final DateTime _lastAllowedDate;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _today = DateTime(now.year, now.month, now.day);

    _lastAllowedDate = _today.add(const Duration(days: 30));
  }

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents = (priceCents % 100).toString().padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

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

  String _formatFullDate(DateTime date) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)} de '
        '${date.year}';
  }

  String _shortWeekday(DateTime date) {
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

  Future<void> _openCalendar() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? _today,
      firstDate: _today,
      lastDate: _lastAllowedDate,
      helpText: 'Escolha a data',
      cancelText: 'CANCELAR',
      confirmText: 'CONFIRMAR',
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  void _continue() {
    final date = _selectedDate;

    if (date == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimeSelectionPage(
          service: widget.service,
          professional: widget.professional,
          date: date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextDates = List.generate(
      14,
      (index) => _today.add(Duration(days: index)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Escolha a data')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _BookingSummaryCard(
                    service: widget.service,
                    professional: widget.professional,
                    formattedPrice: _formatPrice(widget.service.priceCents),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Quando você quer ser atendido?',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Escolha uma data para consultar '
                    'os horários disponíveis.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 22),

                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: nextDates.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final date = nextDates[index];

                        final selected =
                            _selectedDate != null &&
                            _isSameDay(_selectedDate!, date);

                        return _DateCard(
                          date: date,
                          weekday: _shortWeekday(date),
                          selected: selected,
                          onTap: () {
                            _selectDate(date);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  OutlinedButton.icon(
                    onPressed: _openCalendar,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('VER CALENDÁRIO COMPLETO'),
                  ),

                  if (_selectedDate != null) ...[
                    const SizedBox(height: 28),

                    const Text(
                      'Data selecionada',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_available_outlined, size: 32),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Text(
                              _formatFullDate(_selectedDate!),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const Icon(Icons.check_circle),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _selectedDate == null ? null : _continue,
                    child: const Text('CONTINUAR'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

// ============================================================
// RESUMO DO AGENDAMENTO
// ============================================================

class _BookingSummaryCard extends StatelessWidget {
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.content_cut)),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Serviço', style: TextStyle(fontSize: 12)),

                      const SizedBox(height: 2),

                      Text(
                        service.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        '${service.durationMinutes} min'
                        ' • '
                        '$formattedPrice',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    professional.name.isNotEmpty
                        ? professional.name.substring(0, 1).toUpperCase()
                        : '?',
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profissional',
                        style: TextStyle(fontSize: 12),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        professional.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (professional.specialty.isNotEmpty) ...[
                        const SizedBox(height: 3),

                        Text(professional.specialty),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARD DE DATA
// ============================================================

class _DateCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
