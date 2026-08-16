import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/widgets/device_registration_gate.dart';
import 'package:j2i_app_barbearia/core/widgets/role_gate.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/login_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_email_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_phone_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  final AuthRepository _authRepository = AuthRepository();

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

        // ==========================================
        // 1. USUÁRIO NÃO AUTENTICADO
        // ==========================================

        if (user == null) {
          return const LoginPage();
        }

        // ==========================================
        // 2. E-MAIL AINDA NÃO CONFIRMADO
        // ==========================================

        if (!user.emailVerified) {
          return const VerifyEmailPage();
        }

        // ==========================================
        // 3. TELEFONE AINDA NÃO CONFIRMADO
        // ==========================================

        if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
          return const VerifyPhonePage();
        }

        // ==========================================
        // 4. DISPOSITIVO
        // ==========================================
        //
        // Depois de validar o dispositivo,
        // o RoleGate decide qual área abrir.
        //

        return DeviceRegistrationGate(
          key: ValueKey(user.uid),
          child: const RoleGate(),
        );
      },
    );
  }
}
