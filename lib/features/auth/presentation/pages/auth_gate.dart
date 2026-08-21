import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/core/widgets/device_registration_gate.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/login_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_email_page.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/verify_phone_page.dart';
import 'package:j2i_app_barbearia/features/client/presentation/pages/client_home_page.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/mfa_recovery_setup_page.dart';

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthRepository _authRepository = AuthRepository();

  // ============================================================
  // TELEFONE OU MFA JÁ CONFIRMADO?
  // ============================================================

  Future<bool> _hasVerifiedPhone(User user) async {
    // ----------------------------------------------------------
    // Fluxo antigo / cadastro inicial.
    // ----------------------------------------------------------

    final primaryPhone = user.phoneNumber;

    if (primaryPhone != null && primaryPhone.isNotEmpty) {
      return true;
    }

    // ----------------------------------------------------------
    // Fluxo novo:
    // telefone utilizado exclusivamente como MFA.
    // ----------------------------------------------------------

    try {
      final factors = await user.multiFactor.getEnrolledFactors();

      return factors.any((factor) => factor is PhoneMultiFactorInfo);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authRepository.userChanges(),
      builder: (context, authSnapshot) {
        // ======================================================
        // CARREGANDO AUTH
        // ======================================================

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = authSnapshot.data;

        // ======================================================
        // NÃO LOGADO
        // ======================================================

        if (user == null) {
          return const LoginPage();
        }

        // ======================================================
        // E-MAIL
        // ======================================================

        if (!user.emailVerified) {
          return const VerifyEmailPage();
        }

        // ======================================================
        // CONSULTAR PERFIL FIRESTORE
        // ======================================================

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (profileSnapshot.hasError) {
              return Scaffold(
                body: SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 60),

                          const SizedBox(height: 16),

                          const Text(
                            'Não foi possível carregar '
                            'os dados da conta.',
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 18),

                          FilledButton(
                            onPressed: () async {
                              await _authRepository.signOut();
                            },
                            child: const Text('SAIR'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data?.data();

            final recoveryRequired = profile?['mfaRecoveryRequired'] == true;

            // ==================================================
            // RECUPERAÇÃO DE MFA
            // ==================================================
            //
            // Este teste TEM PRIORIDADE sobre VerifyPhonePage.
            // ==================================================

            if (recoveryRequired) {
              return const MfaRecoverySetupPage();
            }

            // ==================================================
            // TELEFONE NORMAL / MFA
            // ==================================================

            return FutureBuilder<bool>(
              future: _hasVerifiedPhone(user),
              builder: (context, phoneSnapshot) {
                if (phoneSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                final hasPhone = phoneSnapshot.data ?? false;

                // ==============================================
                // USUÁRIO NOVO QUE AINDA NÃO VERIFICOU TELEFONE
                // ==============================================

                if (!hasPhone) {
                  return const VerifyPhonePage();
                }

                // ==============================================
                // CONTA LIBERADA
                // ==============================================

                return DeviceRegistrationGate(
                  key: ValueKey(user.uid),
                  child: ClientHomePage(),
                );
              },
            );
          },
        );
      },
    );
  }
}
