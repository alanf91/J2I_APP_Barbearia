import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/appointment_success_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class AppointmentSummaryPage extends StatefulWidget {
  final BarbershopService service;
  final Professional professional;
  final DateTime date;
  final int startMinutes;

  const AppointmentSummaryPage({
    super.key,
    required this.service,
    required this.professional,
    required this.date,
    required this.startMinutes,
  });

  @override
  State<AppointmentSummaryPage> createState() => _AppointmentSummaryPageState();
}

class _AppointmentSummaryPageState extends State<AppointmentSummaryPage> {
  final AppointmentRepository _appointmentRepository = AppointmentRepository();

  bool _isConfirming = false;

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
        '${_monthName(date.month)} de '
        '${date.year}';
  }

  Future<void> _confirmAppointment() async {
    if (_isConfirming) {
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      await _appointmentRepository.createAppointment(
        service: widget.service,
        professional: widget.professional,
        date: widget.date,
        startMinutes: widget.startMinutes,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppointmentSuccessPage()),
      );
    } on AppointmentConflictException {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            icon: const Icon(Icons.schedule_outlined),
            title: const Text('Horário indisponível'),
            content: const Text(
              'Este horário acabou de ser '
              'reservado. Volte e escolha '
              'outro horário.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('APPOINTMENT ERROR -> $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível confirmar '
            'o agendamento. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final endMinutes = widget.startMinutes + widget.service.durationMinutes;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do agendamento')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Confira seu agendamento',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Confira as informações antes de confirmar.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Card(
                    child: Column(
                      children: [
                        _SummaryItem(
                          icon: Icons.content_cut,
                          label: 'Serviço',
                          title: widget.service.name,
                          subtitle:
                              '${widget.service.durationMinutes} min • '
                              '${_formatPrice(widget.service.priceCents)}',
                        ),

                        const Divider(height: 1),

                        _SummaryItem(
                          icon: Icons.person_outline,
                          label: 'Profissional',
                          title: widget.professional.name,
                          subtitle: widget.professional.specialty,
                        ),

                        const Divider(height: 1),

                        _SummaryItem(
                          icon: Icons.calendar_month_outlined,
                          label: 'Data',
                          title: _formatDate(widget.date),
                        ),

                        const Divider(height: 1),

                        _SummaryItem(
                          icon: Icons.schedule_outlined,
                          label: 'Horário',
                          title:
                              '${_formatTime(widget.startMinutes)} às '
                              '${_formatTime(endMinutes)}',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ao confirmar, o horário '
                            'será reservado e deixará '
                            'de aparecer como disponível.',
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    onPressed: _isConfirming ? null : _confirmAppointment,
                    child: Text(
                      _isConfirming
                          ? 'CONFIRMANDO...'
                          : 'CONFIRMAR AGENDAMENTO',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String? subtitle;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(child: Icon(icon)),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
