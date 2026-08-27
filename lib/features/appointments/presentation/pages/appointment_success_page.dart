import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/payments/presentation/payment_method_page.dart';

class AppointmentSuccessPage extends StatelessWidget {
  final String appointmentId;

  const AppointmentSuccessPage({
    super.key,
    required this.appointmentId,
  });

  // ============================================================
  // ABRIR ESCOLHA DA FORMA DE PAGAMENTO
  // ============================================================

  Future<void> _openPaymentMethod(
    BuildContext context,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentMethodPage(
          appointmentId: appointmentId,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Agendamento realizado',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // SUCESSO
                // ==================================================

                const Icon(
                  Icons.check_circle_outline,
                  size: 100,
                ),

                const SizedBox(height: 28),

                const Text(
                  'Horário reservado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  'Seu horário foi reservado. '
                  'Agora escolha a forma de pagamento '
                  'para concluir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // AVISO PAGAMENTO
                // ==================================================

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.payments_outlined,
                      ),

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
                // ESCOLHER FORMA DE PAGAMENTO
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      _openPaymentMethod(
                        context,
                      );
                    },
                    icon: const Icon(
                      Icons.payment,
                    ),
                    label: const Text(
                      'ESCOLHER FORMA DE PAGAMENTO',
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // ID - DESENVOLVIMENTO
                // ==================================================

                Text(
                  'Agendamento: $appointmentId',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}