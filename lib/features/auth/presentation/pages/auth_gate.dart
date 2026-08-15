import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/login_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_email_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_phone_page.dart';
import 'package:j2i_app_barbearia/features/home/presentation/pages/home_page.dart';
import 'package:j2i_app_barbearia/core/widgets/device_registration_gate.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  final _authRepository = AuthRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // 1. Usuário não está logado.
        if (user == null) {
          return const LoginPage();
        }

        // 2. Está logado, mas ainda não confirmou o e-mail.
        if (!user.emailVerified) {
          return const VerifyEmailPage();
        }

        // 3. E-mail confirmado, mas telefone ainda não confirmado.
        if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
          return const VerifyPhonePage();
        }

        // 4. E-mail e telefone confirmados.
        return DeviceRegistrationGate(
          key: ValueKey(user.uid),
          child: HomePage(),
        );
      },
    );
  }
}
