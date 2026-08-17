import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/professionals/presentation/pages/professional_selection_page.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';
import 'package:j2i_app_barbearia/features/services/data/repositories/service_repository.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final ServiceRepository _repository = ServiceRepository();

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents = (priceCents % 100).toString().padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

  void _selectService(BarbershopService service) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfessionalSelectionPage(service: service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<BarbershopService>>(
        stream: _repository.watchActiveServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint(
              'SERVICES ERROR -> '
              '${snapshot.error}',
            );

            return const _ServicesError();
          }

          final services = snapshot.data ?? [];

          if (services.isEmpty) {
            return const _EmptyServices();
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Escolha seu serviço',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Selecione uma opção para '
                'continuar com seu agendamento.',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              ...services.map(
                (service) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ServiceCard(
                    service: service,
                    formattedPrice: _formatPrice(service.priceCents),
                    onTap: () {
                      _selectService(service);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final BarbershopService service;
  final String formattedPrice;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.formattedPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                child: Icon(_getServiceIcon(service.name), size: 30),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(
                        service.description,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        _InfoItem(
                          icon: Icons.schedule_outlined,
                          text: '${service.durationMinutes} min',
                        ),

                        _InfoItem(
                          icon: Icons.payments_outlined,
                          text: formattedPrice,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String name) {
    final normalized = name.toLowerCase();

    if (normalized.contains('barba') && normalized.contains('corte')) {
      return Icons.content_cut;
    }

    if (normalized.contains('barba')) {
      return Icons.face_outlined;
    }

    return Icons.content_cut;
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),

        const SizedBox(width: 5),

        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut_outlined, size: 80),

            SizedBox(height: 20),

            Text(
              'Nenhum serviço disponível',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              'Quando houver serviços disponíveis, eles aparecerão aqui.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServicesError extends StatelessWidget {
  const _ServicesError();

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
              'Não foi possível carregar os serviços.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 10),

            Text(
              'Verifique sua conexão e tente novamente.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
