import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/constants/user_roles.dart';
import 'package:j2i_app_barbearia/features/admin/presentation/pages/admin_home_page.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/client/presentation/pages/client_home_page.dart';

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  final AuthRepository _authRepository = AuthRepository();

  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();

    _roleFuture = _authRepository.getCurrentUserRole();
  }

  void _retry() {
    setState(() {
      _roleFuture = _authRepository.getCurrentUserRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('ROLE GATE ERROR -> ${snapshot.error}');

          return Scaffold(
            appBar: AppBar(title: const Text('Acesso')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 72),
                    const SizedBox(height: 24),
                    const Text(
                      'Não foi possível identificar '
                      'seu perfil de acesso.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Verifique sua conexão e '
                      'tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('TENTAR NOVAMENTE'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;

        if (role == UserRoles.client) {
          return const ClientHomePage();
        }

        if (role == UserRoles.admin) {
          return AdminHomePage();
        }

        return const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_outlined, size: 72),
                  SizedBox(height: 24),
                  Text(
                    'Perfil de acesso inválido.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
