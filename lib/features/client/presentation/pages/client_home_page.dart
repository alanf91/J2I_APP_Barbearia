import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/appointments/data/models/barbershop_appointment.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/my_appointments_page.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/home/presentation/widgets/client_home_tab.dart';
import 'package:j2i_app_barbearia/features/profile/presentation/pages/client_profile_page.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/security_page.dart';
import 'package:j2i_app_barbearia/features/services/presentation/pages/services_page.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({
    super.key,
  });

  @override
  State<ClientHomePage> createState() =>
      _ClientHomePageState();
}

class _ClientHomePageState
    extends State<ClientHomePage> {
  final AuthRepository _authRepository =
      AuthRepository();

  final AppointmentRepository
      _appointmentRepository =
      AppointmentRepository();

  late Future<String?> _userNameFuture;

  late final Stream<List<BarbershopAppointment>>
      _appointmentsStream;

  int _selectedIndex = 0;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _userNameFuture =
        _authRepository
            .getCurrentUserName();

    _appointmentsStream =
        _appointmentRepository
            .watchCurrentUserAppointments();
  }

  // ============================================================
  // NAVEGAÇÃO
  // ============================================================

  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;

      // Atualiza novamente o nome ao voltar
      // para Início ou Perfil.
      if (index == 0 || index == 3) {
        _userNameFuture =
            _authRepository
                .getCurrentUserName();
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                const SecurityPage(),
      ),
    );
  }

  // ============================================================
  // TÍTULO
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user =
        _authRepository.currentUser;

    final email =
        user?.email ?? '';

    return FutureBuilder<String?>(
      future:
          _userNameFuture,

      builder:
          (
            context,
            snapshot,
          ) {
        // ======================================================
        // CARREGANDO NOME
        // ======================================================

        if (
          snapshot.connectionState ==
          ConnectionState.waiting
        ) {
          return const Scaffold(
            body:
                Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        final userName =
            snapshot.data?.trim();

        // ======================================================
        // PÁGINAS
        // ======================================================

        final pages = <Widget>[
          // ----------------------------------------------------
          // INÍCIO
          // ----------------------------------------------------

          ClientHomeTab(
            userName:
                userName,

            email:
                email,

            appointmentsStream:
                _appointmentsStream,

            onNavigate:
                _changePage,

            onOpenSecurity:
                _openSecurity,
          ),

          // ----------------------------------------------------
          // AGENDA
          // ----------------------------------------------------

          const MyAppointmentsPage(),

          // ----------------------------------------------------
          // SERVIÇOS
          // ----------------------------------------------------

          const ServicesPage(),

          // ----------------------------------------------------
          // PERFIL
          // ----------------------------------------------------

          ClientProfilePage(
            initialUserName:
                userName,

            initialEmail:
                email,

            onOpenSecurity:
                _openSecurity,

            onLogout:
                _logout,
          ),
        ];

        // ======================================================
        // SCAFFOLD
        // ======================================================

        return Scaffold(
          appBar:
              AppBar(
            title:
                Text(
              _getPageTitle(),
            ),

            actions: [
              IconButton(
                tooltip:
                    'Segurança',

                onPressed:
                    _openSecurity,

                icon:
                    const Icon(
                  Icons
                      .security_outlined,
                ),
              ),
            ],
          ),

          body:
              IndexedStack(
            index:
                _selectedIndex,

            children:
                pages,
          ),

          // ====================================================
          // MENU INFERIOR
          // ====================================================

          bottomNavigationBar:
              NavigationBar(
            selectedIndex:
                _selectedIndex,

            onDestinationSelected:
                _changePage,

            destinations:
                const [
              NavigationDestination(
                icon:
                    Icon(
                  Icons.home_outlined,
                ),

                selectedIcon:
                    Icon(
                  Icons.home,
                ),

                label:
                    'Início',
              ),

              NavigationDestination(
                icon:
                    Icon(
                  Icons
                      .calendar_month_outlined,
                ),

                selectedIcon:
                    Icon(
                  Icons
                      .calendar_month,
                ),

                label:
                    'Agenda',
              ),

              NavigationDestination(
                icon:
                    Icon(
                  Icons
                      .content_cut_outlined,
                ),

                selectedIcon:
                    Icon(
                  Icons.content_cut,
                ),

                label:
                    'Serviços',
              ),

              NavigationDestination(
                icon:
                    Icon(
                  Icons.person_outline,
                ),

                selectedIcon:
                    Icon(
                  Icons.person,
                ),

                label:
                    'Perfil',
              ),
            ],
          ),
        );
      },
    );
  }
}