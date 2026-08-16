import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/security_page.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final AuthRepository _authRepository = AuthRepository();

  late Future<String?> _userNameFuture;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _userNameFuture = _authRepository.getCurrentUserName();
  }

  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  void _openSecurity() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SecurityPage()));
  }

  String _getPageTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'J2I Barbearia';

      case 1:
        return 'Meus agendamentos';

      case 2:
        return 'Serviços';

      case 3:
        return 'Meu perfil';

      default:
        return 'J2I Barbearia';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authRepository.currentUser;

    final email = user?.email ?? '';

    return FutureBuilder<String?>(
      future: _userNameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userName = snapshot.data?.trim();

        final pages = <Widget>[
          _HomeTab(
            userName: userName,
            email: email,
            onNavigate: _changePage,
            onOpenSecurity: _openSecurity,
          ),
          const _AppointmentsTab(),
          const _ServicesTab(),
          _ProfileTab(
            userName: userName,
            email: email,
            onOpenSecurity: _openSecurity,
            onLogout: _logout,
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(_getPageTitle()),
            actions: [
              IconButton(
                tooltip: 'Segurança',
                onPressed: _openSecurity,
                icon: const Icon(Icons.security_outlined),
              ),
            ],
          ),
          body: IndexedStack(index: _selectedIndex, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _changePage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Início',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Agenda',
              ),
              NavigationDestination(
                icon: Icon(Icons.content_cut_outlined),
                selectedIcon: Icon(Icons.content_cut),
                label: 'Serviços',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// INÍCIO
// ============================================================

class _HomeTab extends StatelessWidget {
  final String? userName;
  final String email;

  final void Function(int index) onNavigate;

  final VoidCallback onOpenSecurity;

  const _HomeTab({
    required this.userName,
    required this.email,
    required this.onNavigate,
    required this.onOpenSecurity,
  });

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim();

    final firstName = name != null && name.isNotEmpty
        ? name.split(' ').first
        : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),

          Text(
            firstName != null ? 'Olá, $firstName!' : 'Olá!',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(
            email,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 28),

          const _SectionTitle(title: 'Agendamento'),

          const SizedBox(height: 12),

          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                onNavigate(2);
              },
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Icon(Icons.calendar_month_outlined, size: 30),
                    ),

                    SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agendar horário',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            'Escolha um serviço para iniciar seu agendamento.',
                          ),
                        ],
                      ),
                    ),

                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const _SectionTitle(title: 'Acesso rápido'),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Agendamentos',
                  onTap: () {
                    onNavigate(1);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _QuickActionCard(
                  icon: Icons.content_cut_outlined,
                  title: 'Serviços',
                  onTap: () {
                    onNavigate(2);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.person_outline,
                  title: 'Perfil',
                  onTap: () {
                    onNavigate(3);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _QuickActionCard(
                  icon: Icons.security_outlined,
                  title: 'Segurança',
                  onTap: onOpenSecurity,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          const _SectionTitle(title: 'Próximo agendamento'),

          const SizedBox(height: 12),

          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.event_available_outlined, size: 38),

                  SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nenhum agendamento',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 4),

                        Text('Seus próximos horários aparecerão aqui.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ============================================================
// MEUS AGENDAMENTOS
// ============================================================

class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, size: 80),

              SizedBox(height: 20),

              Text(
                'Meus agendamentos',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 12),

              Text(
                'Aqui serão exibidos seus próximos horários e seu histórico de atendimentos.',
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              Text(
                'Esta funcionalidade será construída nas próximas etapas.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SERVIÇOS
// ============================================================

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.content_cut_outlined, size: 80),

              SizedBox(height: 20),

              Text(
                'Serviços',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              SizedBox(height: 12),

              Text(
                'Aqui você poderá escolher cortes, barba e outros serviços.',
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 12),

              Text(
                'Na próxima etapa conectaremos esta tela ao Firestore.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PERFIL
// ============================================================

class _ProfileTab extends StatelessWidget {
  final String? userName;
  final String email;

  final VoidCallback onOpenSecurity;

  final Future<void> Function() onLogout;

  const _ProfileTab({
    required this.userName,
    required this.email,
    required this.onOpenSecurity,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name = userName?.trim();

    final displayName = name != null && name.isNotEmpty ? name : 'Usuário';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),

          const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 52)),

          const SizedBox(height: 16),

          Text(
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Text(email, textAlign: TextAlign.center),

          const SizedBox(height: 32),

          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Dados pessoais'),
                  subtitle: const Text('Nome, telefone e informações da conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Edição do perfil será implementada em uma próxima etapa.',
                        ),
                      ),
                    );
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Segurança'),
                  subtitle: const Text('MFA e dispositivos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenSecurity,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(
            onPressed: () async {
              await onLogout();
            },
            icon: const Icon(Icons.logout),
            label: const Text('SAIR DA CONTA'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMPONENTES
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

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, size: 32),

              const SizedBox(height: 10),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
