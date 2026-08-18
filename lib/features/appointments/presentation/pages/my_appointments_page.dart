import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';

class MyAppointmentsPage extends StatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  State<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends State<MyAppointmentsPage> {
  final AppointmentRepository _repository = AppointmentRepository();

  final Set<String> _cancellingIds = {};

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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
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

  Future<void> _cancelAppointment(BarbershopAppointment appointment) async {
    if (_cancellingIds.contains(appointment.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.event_busy_outlined),
          title: const Text('Cancelar agendamento?'),
          content: Text(
            '${appointment.serviceName}\n'
            '${_formatDate(appointment.startAt)}\n'
            '${_formatTime(appointment.startMinutes)} às '
            '${_formatTime(appointment.endMinutes)}\n\n'
            'O horário será liberado novamente '
            'para outros clientes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('VOLTAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('CANCELAR AGENDAMENTO'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _cancellingIds.add(appointment.id);
    });

    try {
      await _repository.cancelAppointment(appointment: appointment);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
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
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      debugPrint('CANCEL APPOINTMENT ERROR -> $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
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
          _cancellingIds.remove(appointment.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<BarbershopAppointment>>(
        stream: _repository.watchCurrentUserAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint(
              'MY APPOINTMENTS ERROR -> '
              '${snapshot.error}',
            );

            return const _AppointmentsError();
          }

          final appointments = snapshot.data ?? [];

          if (appointments.isEmpty) {
            return const _EmptyAppointments();
          }

          final now = DateTime.now();

          final upcoming = appointments
              .where(
                (appointment) =>
                    appointment.status == 'confirmed' &&
                    appointment.endAt.isAfter(now),
              )
              .toList();

          final history = appointments
              .where(
                (appointment) =>
                    appointment.status != 'confirmed' ||
                    !appointment.endAt.isAfter(now),
              )
              .toList();

          history.sort((a, b) => b.startAt.compareTo(a.startAt));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Meus agendamentos',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Acompanhe seus próximos '
                'horários e atendimentos.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              const _SectionTitle(title: 'Próximos'),

              const SizedBox(height: 12),

              if (upcoming.isEmpty)
                const _NoUpcomingAppointments()
              else
                ...upcoming.map((appointment) {
                  final canCancel =
                      appointment.status == 'confirmed' &&
                      appointment.startAt.isAfter(now);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AppointmentCard(
                      appointment: appointment,
                      date: _formatDate(appointment.startAt),
                      weekday: _weekdayName(appointment.startAt),
                      time:
                          '${_formatTime(appointment.startMinutes)} às '
                          '${_formatTime(appointment.endMinutes)}',
                      price: _formatPrice(appointment.priceCents),
                      canCancel: canCancel,
                      isCancelling: _cancellingIds.contains(appointment.id),
                      onCancel: () {
                        _cancelAppointment(appointment);
                      },
                    ),
                  );
                }),

              if (history.isNotEmpty) ...[
                const SizedBox(height: 28),

                const _SectionTitle(title: 'Histórico'),

                const SizedBox(height: 12),

                ...history.map(
                  (appointment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AppointmentCard(
                      appointment: appointment,
                      date: _formatDate(appointment.startAt),
                      weekday: _weekdayName(appointment.startAt),
                      time:
                          '${_formatTime(appointment.startMinutes)} às '
                          '${_formatTime(appointment.endMinutes)}',
                      price: _formatPrice(appointment.priceCents),
                      historical: true,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CARD
// ============================================================

class _AppointmentCard extends StatelessWidget {
  final BarbershopAppointment appointment;

  final String date;
  final String weekday;
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
    required this.time,
    required this.price,
    this.historical = false,
    this.canCancel = false,
    this.isCancelling = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Icon(
                    historical ? Icons.history : Icons.event_available_outlined,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.serviceName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(appointment.professionalName),
                    ],
                  ),
                ),

                _StatusChip(status: appointment.status, historical: historical),
              ],
            ),

            const Divider(height: 28),

            _InformationRow(
              icon: Icons.calendar_month_outlined,
              text: '$weekday, $date',
            ),

            const SizedBox(height: 10),

            _InformationRow(icon: Icons.schedule_outlined, text: time),

            const SizedBox(height: 10),

            _InformationRow(icon: Icons.payments_outlined, text: price),

            if (canCancel) ...[
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isCancelling ? null : onCancel,
                  icon: isCancelling
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.event_busy_outlined),
                  label: Text(
                    isCancelling ? 'CANCELANDO...' : 'CANCELAR AGENDAMENTO',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// STATUS
// ============================================================

class _StatusChip extends StatelessWidget {
  final String status;
  final bool historical;

  const _StatusChip({required this.status, required this.historical});

  @override
  Widget build(BuildContext context) {
    String label;

    if (status == 'confirmed') {
      label = historical ? 'CONCLUÍDO' : 'CONFIRMADO';
    } else if (status == 'cancelled') {
      label = 'CANCELADO';
    } else {
      label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ============================================================
// INFORMAÇÃO
// ============================================================

class _InformationRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InformationRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),

        const SizedBox(width: 10),

        Expanded(child: Text(text)),
      ],
    );
  }
}

// ============================================================
// TÍTULO
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    );
  }
}

// ============================================================
// SEM PRÓXIMOS
// ============================================================

class _NoUpcomingAppointments extends StatelessWidget {
  const _NoUpcomingAppointments();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.event_note_outlined, size: 34),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Você não possui próximos '
                'agendamentos.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NENHUM AGENDAMENTO
// ============================================================

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined, size: 80),
            SizedBox(height: 20),
            Text(
              'Nenhum agendamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Seus agendamentos aparecerão aqui.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERRO
// ============================================================

class _AppointmentsError extends StatelessWidget {
  const _AppointmentsError();

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
              'Não foi possível carregar seus agendamentos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
