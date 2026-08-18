import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

class ChangeEmailPage extends StatefulWidget {
  final String currentEmail;

  const ChangeEmailPage({super.key, required this.currentEmail});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _emailController = TextEditingController();

  bool _isSending = false;
  bool _isChecking = false;
  bool _verificationSent = false;

  String? _pendingEmail;

  @override
  void dispose() {
    _emailController.dispose();

    super.dispose();
  }

  bool _isValidEmail(String email) {
    final value = email.trim();

    return value.contains('@') && value.contains('.') && !value.contains(' ');
  }

  String _firebaseErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-email':
        return 'O e-mail informado é inválido.';

      case 'email-already-in-use':
        return 'Este e-mail já está sendo utilizado por outra conta.';

      case 'requires-recent-login':
        return 'Por segurança, saia da conta, faça login novamente e repita a alteração.';

      case 'too-many-requests':
        return 'Muitas tentativas foram realizadas. Aguarde alguns minutos e tente novamente.';

      case 'network-request-failed':
        return 'Não foi possível conectar ao Firebase. Verifique sua internet.';

      default:
        return exception.message ??
            'Não foi possível solicitar a alteração do e-mail.';
    }
  }

  Future<void> _sendVerification() async {
    final email = _emailController.text.trim().toLowerCase();

    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail válido.')),
      );

      return;
    }

    if (email == widget.currentEmail.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um e-mail diferente do atual.')),
      );

      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _authRepository.requestEmailChange(newEmail: email);

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingEmail = email;
        _verificationSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enviamos uma confirmação para $email.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseErrorMessage(e))));
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _checkVerification() async {
    final pendingEmail = _pendingEmail;

    if (pendingEmail == null) {
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      final synchronized = await _authRepository.syncVerifiedEmailToFirestore(
        expectedEmail: pendingEmail,
      );

      if (!mounted) {
        return;
      }

      if (!synchronized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'O novo e-mail ainda não foi confirmado. '
              'Abra o e-mail recebido, confirme o link '
              'e tente novamente.',
            ),
          ),
        );

        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail atualizado com sucesso.')),
      );

      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_firebaseErrorMessage(e))));
    } catch (e) {
      debugPrint('EMAIL SYNC ERROR -> $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível confirmar a alteração.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar e-mail')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),

            const Icon(Icons.email_outlined, size: 72),

            const SizedBox(height: 24),

            const Text(
              'E-mail da conta',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              'E-mail atual:\n'
              '${widget.currentEmail}',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            if (!_verificationSent) ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Novo e-mail',
                  prefixIcon: Icon(Icons.alternate_email),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _sendVerification,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_read_outlined),
                  label: Text(
                    _isSending ? 'ENVIANDO...' : 'ENVIAR VERIFICAÇÃO',
                  ),
                ),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.outgoing_mail, size: 46),

                      const SizedBox(height: 16),

                      const Text(
                        'Verificação enviada',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Enviamos um link para:\n\n'
                        '$_pendingEmail',
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Abra esse e-mail e confirme '
                        'o link antes de continuar.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isChecking ? null : _checkVerification,
                  icon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(_isChecking ? 'VERIFICANDO...' : 'JÁ CONFIRMEI'),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: _isChecking
                    ? null
                    : () {
                        setState(() {
                          _verificationSent = false;

                          _pendingEmail = null;

                          _emailController.clear();
                        });
                      },
                child: const Text('USAR OUTRO E-MAIL'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
