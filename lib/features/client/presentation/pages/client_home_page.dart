import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/my_appointments_page.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/profile/presentation/pages/client_profile_page.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/security_page.dart';
import 'package:j2i_app_barbearia/features/services/presentation/pages/services_page.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final AuthRepository _authRepository = AuthRepository();

  final AppointmentRepository _appointmentRepository = AppointmentRepository();

  late Future<String?> _userNameFuture;

  late final Stream<List<BarbershopAppointment>> _appointmentsStream;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();

    _userNameFuture = _authRepository.getCurrentUserName();

    _appointmentsStream = _appointmentRepository.watchCurrentUserAppointments();
  }

  // ============================================================
  // NAVEGAÇÃO
  // ============================================================

  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;

      // Quando o usuário volta para Início ou Perfil,
      // buscamos o nome novamente no Firestore.
      //
      // Assim, se ele editar o nome no Perfil,
      // a Home recebe o valor atualizado.
      if (index == 0 || index == 3) {
        _userNameFuture = _authRepository.getCurrentUserName();
      }
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  // ============================================================
  // SEGURANÇA
  // ============================================================

  void _openSecurity() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SecurityPage()));
  }

  // ============================================================
  // TÍTULO DA APPBAR
  // ============================================================

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

  // ============================================================
  // BUILD PRINCIPAL
  // ============================================================

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
          // ======================================================
          // INÍCIO
          // ======================================================
          _HomeTab(
            userName: userName,
            email: email,
            appointmentsStream: _appointmentsStream,
            onNavigate: _changePage,
            onOpenSecurity: _openSecurity,
          ),

          // ======================================================
          // AGENDA
          // ======================================================
          const MyAppointmentsPage(),

          // ======================================================
          // SERVIÇOS
          // ======================================================
          const ServicesPage(),

          // ======================================================
          // PERFIL
          // ======================================================
          ClientProfilePage(
            initialUserName: userName,
            initialEmail: email,
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
// HOME
// ============================================================

class _HomeTab extends StatelessWidget {
  final String? userName;
  final String email;

  final Stream<List<BarbershopAppointment>> appointmentsStream;

  final void Function(int index) onNavigate;

  final VoidCallback onOpenSecurity;

  const _HomeTab({
    required this.userName,
    required this.email,
    required this.appointmentsStream,
    required this.onNavigate,
    required this.onOpenSecurity,
  });

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
  // FORMATAR DATA
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // DIA DA SEMANA
  // ============================================================

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

  // ============================================================
  // FORMATAR PREÇO
  // ============================================================

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents = (priceCents % 100).toString().padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

  // ============================================================
  // ENCONTRAR PRÓXIMO AGENDAMENTO
  // ============================================================

  BarbershopAppointment? _findNextAppointment(
    List<BarbershopAppointment> appointments,
  ) {
    final now = DateTime.now();

    final upcoming = appointments
        .where(
          (appointment) =>
              appointment.status == 'confirmed' &&
              appointment.endAt.isAfter(now),
        )
        .toList();

    upcoming.sort((a, b) => a.startAt.compareTo(b.startAt));

    if (upcoming.isEmpty) {
      return null;
    }

    return upcoming.first;
  }

  // ============================================================
  // BUILD HOME
  // ============================================================

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

          // ======================================================
          // SAUDAÇÃO
          // ======================================================
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

          // ======================================================
          // AGENDAMENTO
          // ======================================================
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

          // ======================================================
          // ACESSO RÁPIDO
          // ======================================================
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

          // ======================================================
          // PRÓXIMO AGENDAMENTO
          // ======================================================
          const _SectionTitle(title: 'Próximo agendamento'),

          const SizedBox(height: 12),

          StreamBuilder<List<BarbershopAppointment>>(
            stream: appointmentsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError) {
                debugPrint(
                  'HOME APPOINTMENT ERROR -> '
                  '${snapshot.error}',
                );

                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 34),

                        SizedBox(width: 14),

                        Expanded(
                          child: Text(
                            'Não foi possível carregar seu próximo agendamento.',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final appointments = snapshot.data ?? [];

              final nextAppointment = _findNextAppointment(appointments);

              // ==================================================
              // SEM AGENDAMENTO
              // ==================================================

              if (nextAppointment == null) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      onNavigate(2);
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.event_note_outlined, size: 38),

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

                                Text(
                                  'Você não possui próximos horários. Toque para agendar.',
                                ),
                              ],
                            ),
                          ),

                          Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // ==================================================
              // PRÓXIMO AGENDAMENTO REAL
              // ==================================================

              return _NextAppointmentCard(
                appointment: nextAppointment,
                date: _formatDate(nextAppointment.startAt),
                weekday: _weekdayName(nextAppointment.startAt),
                time:
                    '${_formatTime(nextAppointment.startMinutes)} às '
                    '${_formatTime(nextAppointment.endMinutes)}',
                price: _formatPrice(nextAppointment.priceCents),
                onTap: () {
                  onNavigate(1);
                },
              );
            },
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DO PRÓXIMO AGENDAMENTO
// ============================================================

class _NextAppointmentCard extends StatelessWidget {
  final BarbershopAppointment appointment;

  final String weekday;
  final String date;
  final String time;
  final String price;

  final VoidCallback onTap;

  const _NextAppointmentCard({
    required this.appointment,
    required this.weekday,
    required this.date,
    required this.time,
    required this.price,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    child: Icon(Icons.event_available_outlined),
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

                        const SizedBox(height: 4),

                        Text(appointment.professionalName),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CONFIRMADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const Divider(height: 28),

              _HomeAppointmentInfo(
                icon: Icons.calendar_month_outlined,
                text: '$weekday, $date',
              ),

              const SizedBox(height: 10),

              _HomeAppointmentInfo(icon: Icons.schedule_outlined, text: time),

              const SizedBox(height: 10),

              _HomeAppointmentInfo(icon: Icons.payments_outlined, text: price),

              const SizedBox(height: 14),

              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver detalhes',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),

                  SizedBox(width: 4),

                  Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INFORMAÇÃO DO AGENDAMENTO NA HOME
// ============================================================

class _HomeAppointmentInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HomeAppointmentInfo({required this.icon, required this.text});

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
// TÍTULO DAS SEÇÕES
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
// CARD DE ACESSO RÁPIDO
// ============================================================

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
