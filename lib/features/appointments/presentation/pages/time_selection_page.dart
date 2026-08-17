import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/professional_availability.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/availability_repository.dart';
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
  final AvailabilityRepository _repository = AvailabilityRepository();

  late Future<ProfessionalAvailability?> _availabilityFuture;

  int? _selectedStartMinutes;

  @override
  void initState() {
    super.initState();

    _availabilityFuture = _repository.getAvailabilityForDate(
      professionalId: widget.professional.id,
      date: widget.date,
    );
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
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

  String _formatDate(DateTime date) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)}';
  }

  List<int> _generateAvailableTimes(ProfessionalAvailability availability) {
    if (!availability.enabled) {
      return [];
    }

    if (availability.startMinutes >= availability.endMinutes) {
      return [];
    }

    final serviceDuration = widget.service.durationMinutes;

    if (serviceDuration <= 0) {
      return [];
    }

    final interval = availability.intervalMinutes > 0
        ? availability.intervalMinutes
        : 30;

    final times = <int>[];

    var current = availability.startMinutes;

    while (current + serviceDuration <= availability.endMinutes) {
      times.add(current);

      current += interval;
    }

    return times;
  }

  void _selectTime(int minutes) {
    setState(() {
      _selectedStartMinutes = minutes;
    });
  }

  void _continue() {
    final selected = _selectedStartMinutes;

    if (selected == null) {
      return;
    }

    final end = selected + widget.service.durationMinutes;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Horário selecionado: '
          '${_formatTime(selected)} às '
          '${_formatTime(end)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolha o horário')),
      body: FutureBuilder<ProfessionalAvailability?>(
        future: _availabilityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint(
              'AVAILABILITY ERROR -> '
              '${snapshot.error}',
            );

            return const _AvailabilityError();
          }

          final availability = snapshot.data;

          if (availability == null || !availability.enabled) {
            return _NoAvailability(date: _formatDate(widget.date));
          }

          final times = _generateAvailableTimes(availability);

          if (times.isEmpty) {
            return _NoAvailability(date: _formatDate(widget.date));
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _BookingSummaryCard(
                        service: widget.service,
                        professional: widget.professional,
                        date: _formatDate(widget.date),
                        formattedPrice: _formatPrice(widget.service.priceCents),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'Horários disponíveis',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Atendimento de '
                        '${_formatTime(availability.startMinutes)} '
                        'até '
                        '${_formatTime(availability.endMinutes)}.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 22),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.2,
                            ),
                        itemCount: times.length,
                        itemBuilder: (context, index) {
                          final time = times[index];

                          final selected = _selectedStartMinutes == time;

                          return _TimeCard(
                            time: _formatTime(time),
                            selected: selected,
                            onTap: () {
                              _selectTime(time);
                            },
                          );
                        },
                      ),

                      if (_selectedStartMinutes != null) ...[
                        const SizedBox(height: 28),

                        const Text(
                          'Horário selecionado',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule_outlined),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  '${_formatTime(_selectedStartMinutes!)} '
                                  'às '
                                  '${_formatTime(_selectedStartMinutes! + widget.service.durationMinutes)}',
                                  style: const TextStyle(
                                    fontSize: 17,
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
                        onPressed: _selectedStartMinutes == null
                            ? null
                            : _continue,
                        child: const Text('CONTINUAR'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _SummaryRow(
              icon: Icons.content_cut,
              label: 'Serviço',
              value: service.name,
              subtitle:
                  '${service.durationMinutes} min'
                  ' • '
                  '$formattedPrice',
            ),

            const Divider(height: 28),

            _SummaryRow(
              icon: Icons.person_outline,
              label: 'Profissional',
              value: professional.name,
              subtitle: professional.specialty,
            ),

            const Divider(height: 28),

            _SummaryRow(
              icon: Icons.calendar_month_outlined,
              label: 'Data',
              value: date,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(child: Icon(icon)),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),

              const SizedBox(height: 2),

              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),

                Text(subtitle!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

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
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            time,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: selected ? colors.onPrimaryContainer : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoAvailability extends StatelessWidget {
  final String date;

  const _NoAvailability({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 76),

            const SizedBox(height: 20),

            const Text(
              'Sem atendimento nesta data',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Text(date, textAlign: TextAlign.center),

            const SizedBox(height: 10),

            const Text(
              'Volte e escolha outra data.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityError extends StatelessWidget {
  const _AvailabilityError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72),

            SizedBox(height: 20),

            Text(
              'Não foi possível carregar os horários.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
