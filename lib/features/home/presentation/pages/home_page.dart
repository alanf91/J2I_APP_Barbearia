import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/security_page.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});

  final AuthRepository _authRepository = AuthRepository();

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authRepository.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, size: 72),

                const SizedBox(height: 24),

                const Text(
                  'Login realizado com sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                Text(user?.email ?? '', textAlign: TextAlign.center),

                const SizedBox(height: 32),

                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SecurityPage()),
                    );
                  },
                  icon: const Icon(Icons.security_outlined),
                  label: const Text('SEGURANÇA'),
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('SAIR'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
