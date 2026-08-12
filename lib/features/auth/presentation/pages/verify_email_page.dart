import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final _authRepository = AuthRepository();

  bool _isSending = false;
  bool _isChecking = false;
  bool _automaticEmailSent = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendVerificationEmail(automatic: true);
    });
  }

  Future<void> _sendVerificationEmail({bool automatic = false}) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _authRepository.sendEmailVerification();

      if (!mounted) return;

      setState(() {
        _automaticEmailSent = true;
      });

      if (!automatic) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de verificação enviado.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'too-many-requests':
          message =
              'Muitas solicitações foram realizadas. '
              'Aguarde alguns minutos e tente novamente.';
          break;

        case 'network-request-failed':
          message =
              'Não foi possível conectar. '
              'Verifique sua internet.';
          break;

        default:
          message =
              'Não foi possível enviar o e-mail '
              'de verificação.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível enviar o e-mail '
            'de verificação.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _checkEmailVerification() async {
    if (_isChecking) {
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      await _authRepository.reloadCurrentUser();

      if (!mounted) return;

      final user = _authRepository.currentUser;

      if (user?.emailVerified == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail confirmado com sucesso!')),
        );

        // Não navegamos manualmente.
        // O AuthGate detectará emailVerified = true
        // e abrirá a Home automaticamente.
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O e-mail ainda não foi confirmado.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'network-request-failed':
          message =
              'Não foi possível conectar. '
              'Verifique sua internet.';
          break;

        default:
          message =
              'Não foi possível verificar o status '
              'do e-mail.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authRepository.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar e-mail'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 48),

              const Icon(Icons.mark_email_unread_outlined, size: 88),

              const SizedBox(height: 24),

              const Text(
                'Confirme seu e-mail',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              const Text(
                'Enviamos um link de confirmação para:',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Abra o e-mail e clique no link de '
                'confirmação. Depois volte ao aplicativo '
                'e toque em "JÁ VERIFIQUEI".',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isChecking ? null : _checkEmailVerification,
                  child: _isChecking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'JÁ VERIFIQUEI',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              TextButton.icon(
                onPressed: _isSending
                    ? null
                    : () {
                        _sendVerificationEmail();
                      },
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                  _automaticEmailSent
                      ? 'Reenviar e-mail'
                      : 'Enviar e-mail de verificação',
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: _logout,
                child: const Text('Sair da conta'),
              ),

              const SizedBox(height: 24),

              const Text(
                'Não encontrou o e-mail? '
                'Verifique também a pasta de spam '
                'ou lixo eletrônico.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
