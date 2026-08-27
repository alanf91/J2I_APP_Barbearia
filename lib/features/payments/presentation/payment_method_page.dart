import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/payments/presentation/pages/card_payment_page.dart';
import 'package:j2i_app_barbearia/features/payments/presentation/pages/pix_payment_page.dart';

class PaymentMethodPage extends StatelessWidget {
  final String appointmentId;

  const PaymentMethodPage({
    super.key,
    required this.appointmentId,
  });

  // ============================================================
  // PIX
  // ============================================================

  void _openPix(
    BuildContext context,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PixPaymentPage(
          appointmentId: appointmentId,
        ),
      ),
    );
  }

  // ============================================================
  // CARTÃO
  // ============================================================

  void _openCard(
    BuildContext context,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CardPaymentPage(
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
        title: const Text(
          'Forma de pagamento',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),

            const Icon(
              Icons.payments_outlined,
              size: 72,
            ),

            const SizedBox(height: 20),

            const Text(
              'Como deseja pagar?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Escolha a forma de pagamento '
              'para continuar.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 36),

            // ==================================================
            // PIX
            // ==================================================

            _PaymentOptionCard(
              icon: Icons.pix,
              title: 'Pix',
              subtitle:
                  'Pagamento por QR Code ou Pix Copia e Cola.',
              onTap: () {
                _openPix(context);
              },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // CARTÃO
            // ==================================================

            _PaymentOptionCard(
              icon: Icons.credit_card,
              title: 'Cartão',
              subtitle:
                  'Crédito ou débito com processamento seguro.',
              onTap: () {
                _openCard(context);
              },
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 20,
                  ),

                  SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      'Os pagamentos são processados '
                      'com integração segura do Mercado Pago.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OPÇÃO DE PAGAMENTO
// ============================================================

class _PaymentOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 30,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subtitle,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}