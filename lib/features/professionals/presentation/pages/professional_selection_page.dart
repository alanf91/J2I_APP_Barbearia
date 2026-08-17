import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/presentation/pages/date_selection_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/professionals/data/repositories/professional_repository.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class ProfessionalSelectionPage extends StatefulWidget {
  final BarbershopService service;

  const ProfessionalSelectionPage({super.key, required this.service});

  @override
  State<ProfessionalSelectionPage> createState() =>
      _ProfessionalSelectionPageState();
}

class _ProfessionalSelectionPageState extends State<ProfessionalSelectionPage> {
  final ProfessionalRepository _repository = ProfessionalRepository();

  Professional? _selectedProfessional;

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents = (priceCents % 100).toString().padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

  void _selectProfessional(Professional professional) {
    setState(() {
      _selectedProfessional = professional;
    });
  }

  void _continue() {
    final professional = _selectedProfessional;

    if (professional == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DateSelectionPage(
          service: widget.service,
          professional: professional,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escolha o profissional')),
      body: SafeArea(
        child: Column(
          children: [
            _SelectedServiceCard(
              service: widget.service,
              formattedPrice: _formatPrice(widget.service.priceCents),
            ),

            Expanded(
              child: StreamBuilder<List<Professional>>(
                stream: _repository.watchActiveProfessionalsForService(
                  widget.service.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'PROFESSIONALS ERROR -> '
                      '${snapshot.error}',
                    );

                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 72),
                            SizedBox(height: 20),
                            Text(
                              'Não foi possível carregar os profissionais.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final professionals = snapshot.data ?? [];

                  if (professionals.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined, size: 72),
                            SizedBox(height: 20),
                            Text(
                              'Nenhum profissional disponível.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    children: [
                      const Text(
                        'Profissionais disponíveis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text('Escolha quem irá realizar seu atendimento.'),

                      const SizedBox(height: 20),

                      ...professionals.map((professional) {
                        final selected =
                            _selectedProfessional?.id == professional.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ProfessionalCard(
                            professional: professional,
                            selected: selected,
                            onTap: () {
                              _selectProfessional(professional);
                            },
                          ),
                        );
                      }),
                    ],
                  );
                },
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
                    onPressed: _selectedProfessional == null ? null : _continue,
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
}

class _SelectedServiceCard extends StatelessWidget {
  final BarbershopService service;
  final String formattedPrice;

  const _SelectedServiceCard({
    required this.service,
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.content_cut)),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Serviço selecionado',
                  style: TextStyle(fontSize: 12),
                ),

                const SizedBox(height: 3),

                Text(
                  service.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

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
    );
  }
}

class _ProfessionalCard extends StatelessWidget {
  final Professional professional;
  final bool selected;
  final VoidCallback onTap;

  const _ProfessionalCard({
    required this.professional,
    required this.selected,
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
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(
                  professional.name.isNotEmpty
                      ? professional.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (professional.specialty.isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(professional.specialty),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
