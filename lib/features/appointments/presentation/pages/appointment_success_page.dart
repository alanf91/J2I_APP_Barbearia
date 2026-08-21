import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/payments/presentation/pages/pix_payment_page.dart';

class AppointmentSuccessPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentSuccessPage({super.key, required this.appointmentId});

  // ============================================================
  // ABRIR PAGAMENTO PIX
  // ============================================================

  Future<void> _openPixPayment(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PixPaymentPage(appointmentId: appointmentId),
      ),
    );
  }

  // ============================================================
  // VOLTAR PARA O INÍCIO
  // ============================================================

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Agendamento realizado'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, size: 100),

                const SizedBox(height: 28),

                const Text(
                  'Horário reservado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Seu horário foi reservado. '
                  'Agora você pode realizar o pagamento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // AVISO PAGAMENTO
                // ==================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.payments_outlined),

                      SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'O pagamento será associado '
                          'diretamente a este agendamento.',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 26),

                // ==================================================
                // PIX
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () {
                      _openPixPayment(context);
                    },
                    icon: const Icon(Icons.pix),
                    label: const Text('PAGAR COM PIX'),
                  ),
                ),

                const SizedBox(height: 14),

                // ==================================================
                // HOME
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _goHome(context);
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('PAGAR DEPOIS'),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Agendamento: $appointmentId',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
