import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/security_page.dart';

class AdminHomePage extends StatelessWidget {
  AdminHomePage({super.key});

  final AuthRepository _authRepository = AuthRepository();

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature será implementado nas próximas etapas.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authRepository.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('J2I Barbearia - Administração'),
        actions: [
          IconButton(
            tooltip: 'Segurança',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SecurityPage()));
            },
            icon: const Icon(Icons.security_outlined),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),

            const Text(
              'Painel administrativo',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(user?.email ?? '', style: const TextStyle(fontSize: 15)),

            const SizedBox(height: 8),

            const Text(
              'Gerencie a operação da barbearia.',
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 28),

            _AdminMenuCard(
              icon: Icons.calendar_month_outlined,
              title: 'Agenda',
              description: 'Visualize e gerencie os agendamentos.',
              onTap: () {
                _comingSoon(context, 'Agenda administrativa');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.people_outline,
              title: 'Clientes',
              description: 'Consulte clientes cadastrados.',
              onTap: () {
                _comingSoon(context, 'Clientes');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.content_cut_outlined,
              title: 'Serviços',
              description: 'Cadastre serviços, preços e duração.',
              onTap: () {
                _comingSoon(context, 'Cadastro de serviços');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.badge_outlined,
              title: 'Profissionais',
              description: 'Gerencie barbeiros e profissionais.',
              onTap: () {
                _comingSoon(context, 'Profissionais');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.payments_outlined,
              title: 'Pagamentos',
              description: 'Acompanhe pagamentos e recebimentos.',
              onTap: () {
                _comingSoon(context, 'Pagamentos');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.settings_outlined,
              title: 'Configurações',
              description: 'Configure horários e regras do negócio.',
              onTap: () {
                _comingSoon(context, 'Configurações');
              },
            ),

            const SizedBox(height: 12),

            _AdminMenuCard(
              icon: Icons.security_outlined,
              title: 'Segurança',
              description: 'MFA e dispositivos da conta.',
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SecurityPage()));
              },
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('SAIR DA CONTA'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AdminMenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 36),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(description),
                  ],
                ),
              ),

              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
