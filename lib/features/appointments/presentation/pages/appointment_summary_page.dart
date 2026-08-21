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
    final value = priceCents / 100;

    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // DIA DA SEMANA
  // ============================================================

  String _weekdayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'segunda-feira';

      case DateTime.tuesday:
        return 'terça-feira';

      case DateTime.wednesday:
        return 'quarta-feira';

      case DateTime.thursday:
        return 'quinta-feira';

      case DateTime.friday:
        return 'sexta-feira';

      case DateTime.saturday:
        return 'sábado';

      case DateTime.sunday:
        return 'domingo';

      default:
        return '';
    }
  }

  // ============================================================
  // NOME DO MÊS
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
  // FORMATAR DATA
  // ============================================================

  String _formatDate(DateTime date) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)} de '
        '${date.year}';
  }

  // ============================================================
  // CONFIRMAR AGENDAMENTO
  // ============================================================

  Future<void> _confirmAppointment() async {
    if (_isConfirming) {
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // ========================================================
      // CRIAR AGENDAMENTO E GUARDAR O ID GERADO
      // ========================================================

      final appointmentId = await _appointmentRepository.createAppointment(
        service: widget.service,
        professional: widget.professional,
        date: widget.date,
        startMinutes: widget.startMinutes,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // IR PARA A TELA DE SUCESSO
      //
      // O appointmentId será utilizado para gerar o pagamento Pix.
      // ========================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppointmentSuccessPage(appointmentId: appointmentId),
        ),
      );
    } on AppointmentConflictException {
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.schedule_outlined, size: 48),
            title: const Text('Horário indisponível'),
            content: const Text(
              'Este horário acabou de ser reservado '
              'por outro cliente.\n\n'
              'Escolha outro horário para continuar.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('ENTENDI'),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      // Volta para a seleção de horário.
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('CREATE APPOINTMENT ERROR -> $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível confirmar o agendamento. '
            'Tente novamente.',
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final endMinutes = widget.startMinutes + widget.service.durationMinutes;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo do agendamento')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),

            // ==================================================
            // CABEÇALHO
            // ==================================================
            const Icon(Icons.event_available_outlined, size: 72),

            const SizedBox(height: 18),

            const Text(
              'Confira seu agendamento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            const Text(
              'Revise os dados abaixo antes de reservar o horário.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // ==================================================
            // SERVIÇO
            // ==================================================
            _SummaryCard(
              icon: Icons.content_cut,
              title: 'Serviço',
              value: widget.service.name,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // PROFISSIONAL
            // ==================================================
            _SummaryCard(
              icon: Icons.person_outline,
              title: 'Profissional',
              value: widget.professional.name,
            ),

            const SizedBox(height: 12),

            // ==================================================
            // DATA
            // ==================================================
            _SummaryCard(
              icon: Icons.calendar_month_outlined,
              title: 'Data',
              value: _formatDate(widget.date),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // HORÁRIO
            // ==================================================
            _SummaryCard(
              icon: Icons.schedule_outlined,
              title: 'Horário',
              value:
                  '${_formatTime(widget.startMinutes)} '
                  'às ${_formatTime(endMinutes)}',
            ),

            const SizedBox(height: 12),

            // ==================================================
            // DURAÇÃO
            // ==================================================
            _SummaryCard(
              icon: Icons.timer_outlined,
              title: 'Duração',
              value: '${widget.service.durationMinutes} minutos',
            ),

            const SizedBox(height: 12),

            // ==================================================
            // VALOR
            // ==================================================
            _SummaryCard(
              icon: Icons.payments_outlined,
              title: 'Valor',
              value: _formatPrice(widget.service.priceCents),
              emphasize: true,
            ),

            const SizedBox(height: 26),

            // ==================================================
            // INFORMAÇÃO SOBRE PAGAMENTO
            // ==================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'Ao confirmar, o horário será reservado. '
                      'Na próxima tela você poderá realizar '
                      'o pagamento com Pix.',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==================================================
            // CONFIRMAR
            // ==================================================
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _isConfirming ? null : _confirmAppointment,
                icon: _isConfirming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isConfirming
                      ? 'RESERVANDO HORÁRIO...'
                      : 'CONFIRMAR AGENDAMENTO',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // VOLTAR
            // ==================================================
            TextButton(
              onPressed: _isConfirming
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: const Text('VOLTAR E ALTERAR HORÁRIO'),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CARD DO RESUMO
// ============================================================

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool emphasize;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: TextStyle(
                    fontSize: emphasize ? 19 : 16,
                    fontWeight: emphasize ? FontWeight.bold : FontWeight.w600,
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
