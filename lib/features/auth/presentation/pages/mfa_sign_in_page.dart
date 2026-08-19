import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/security/presentation/pages/mfa_recovery_page.dart';

class MfaSignInPage extends StatefulWidget {
  final MultiFactorResolver resolver;

  const MfaSignInPage({super.key, required this.resolver});

  @override
  State<MfaSignInPage> createState() => _MfaSignInPageState();
}

class _MfaSignInPageState extends State<MfaSignInPage> {
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _codeController = TextEditingController();

  String? _verificationId;

  bool _isSendingCode = false;
  bool _isConfirmingCode = false;
  bool _codeSent = false;

  String? _errorMessage;

  // ============================================================
  // FATOR MFA DE TELEFONE
  // ============================================================

  PhoneMultiFactorInfo? get _phoneHint {
    for (final hint in widget.resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        return hint;
      }
    }

    return null;
  }

  // ============================================================
  // MASCARAR TELEFONE
  // ============================================================

  String _maskedPhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 4) {
      return phoneNumber;
    }

    final lastFour = digits.substring(digits.length - 4);

    return '+*********$lastFour';
  }

  // ============================================================
  // ERROS
  // ============================================================

  String _firebaseErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-verification-code':
        return 'O código informado está incorreto.';

      case 'session-expired':
        return 'O código expirou. '
            'Solicite um novo código.';

      case 'too-many-requests':
        return 'Muitas tentativas foram realizadas. '
            'Aguarde alguns minutos e tente novamente.';

      case 'quota-exceeded':
        return 'O limite de SMS foi atingido. '
            'Tente novamente mais tarde.';

      case 'invalid-phone-number':
        return 'O telefone de segurança é inválido.';

      case 'network-request-failed':
        return 'Não foi possível conectar ao Firebase. '
            'Verifique sua internet.';

      case 'operation-not-allowed':
        return 'A autenticação por telefone '
            'não está habilitada.';

      default:
        return exception.message ??
            'Não foi possível concluir '
                'a verificação de segurança.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // ENVIAR CÓDIGO MFA
  // ============================================================

  Future<void> _sendCode({bool resend = false}) async {
    if (_isSendingCode || _isConfirmingCode) {
      return;
    }

    final hint = _phoneHint;

    if (hint == null) {
      setState(() {
        _errorMessage =
            'Nenhum telefone de segurança '
            'foi encontrado nesta conta.';
      });

      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.startMfaSignIn(
        resolver: widget.resolver,

        hint: hint,

        verificationCompleted: (PhoneAuthCredential credential) {
          // Confirmação manual.
        },

        verificationFailed: (FirebaseAuthException exception) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isSendingCode = false;

            _errorMessage = _firebaseErrorMessage(exception);
          });
        },

        codeSent: (String verificationId, int? _) {
          if (!mounted) {
            return;
          }

          _codeController.clear();

          setState(() {
            _verificationId = verificationId;

            _codeSent = true;

            _isSendingCode = false;

            _errorMessage = null;
          });

          _showMessage(
            resend ? 'Novo código enviado.' : 'Código de segurança enviado.',
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;

          if (mounted) {
            setState(() {
              _isSendingCode = false;
            });
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingCode = false;

        _errorMessage = _firebaseErrorMessage(e);
      });
    } catch (e) {
      debugPrint('MFA SEND CODE ERROR -> $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isSendingCode = false;

        _errorMessage =
            'Não foi possível enviar '
            'o código de segurança.';
      });
    }
  }

  // ============================================================
  // CONFIRMAR CÓDIGO MFA
  // ============================================================

  Future<void> _confirmCode() async {
    if (_isConfirmingCode || _isSendingCode) {
      return;
    }

    final verificationId = _verificationId;

    final smsCode = _codeController.text.trim();

    if (verificationId == null) {
      setState(() {
        _errorMessage =
            'Solicite um código antes '
            'de continuar.';
      });

      return;
    }

    if (smsCode.length != 6) {
      setState(() {
        _errorMessage = 'Informe o código de 6 dígitos.';
      });

      return;
    }

    setState(() {
      _isConfirmingCode = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.completeMfaSignIn(
        resolver: widget.resolver,
        verificationId: verificationId,
        smsCode: smsCode,
      );

      if (!mounted) {
        return;
      }

      // MUITO IMPORTANTE:
      //
      // A tela que abriu o MFA receberá TRUE.
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConfirmingCode = false;

        _errorMessage = _firebaseErrorMessage(e);
      });
    } catch (e) {
      debugPrint('MFA CONFIRM CODE ERROR -> $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isConfirmingCode = false;

        _errorMessage =
            'Não foi possível confirmar '
            'o código de segurança.';
      });
    }
  }

  // ============================================================
  // RECUPERAÇÃO SEM TELEFONE ANTIGO
  // ============================================================

  Future<void> _openEmailRecovery() async {
    if (_isSendingCode || _isConfirmingCode) {
      return;
    }

    final currentEmail = FirebaseAuth.instance.currentUser?.email;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MfaRecoveryPage(initialEmail: currentEmail),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _codeController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final hint = _phoneHint;

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação de segurança')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 24),

            const Icon(Icons.phonelink_lock_outlined, size: 78),

            const SizedBox(height: 26),

            const Text(
              'Confirme que é você',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Text(
              'Sua conta possui verificação '
              'em duas etapas.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            if (hint != null)
              Text(
                'Telefone de segurança: '
                '${_maskedPhone(hint.phoneNumber)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

            if (hint == null)
              const Text(
                'Nenhum telefone de segurança '
                'foi encontrado.',
                textAlign: TextAlign.center,
              ),

            const SizedBox(height: 30),

            // ==================================================
            // ENVIAR CÓDIGO
            // ==================================================
            if (!_codeSent && hint != null)
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSendingCode
                      ? null
                      : () {
                          _sendCode();
                        },
                  icon: _isSendingCode
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sms_outlined),
                  label: Text(_isSendingCode ? 'ENVIANDO...' : 'ENVIAR CÓDIGO'),
                ),
              ),

            // ==================================================
            // CONFIRMAR CÓDIGO
            // ==================================================
            if (_codeSent) ...[
              TextField(
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,

                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Código de segurança',
                  hintText: '123456',
                  prefixIcon: Icon(Icons.password_outlined),
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_isConfirmingCode) {
                    _confirmCode();
                  }
                },
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isConfirmingCode ? null : _confirmCode,
                  icon: _isConfirmingCode
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: Text(
                    _isConfirmingCode
                        ? 'CONFIRMANDO...'
                        : 'CONFIRMAR IDENTIDADE',
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton.icon(
                onPressed: _isSendingCode || _isConfirmingCode
                    ? null
                    : () {
                        _sendCode(resend: true);
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('REENVIAR CÓDIGO'),
              ),
            ],

            // ==================================================
            // ERRO
            // ==================================================
            if (_errorMessage != null) ...[
              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),

            const Divider(),

            const SizedBox(height: 14),

            // ==================================================
            // PERDEU O TELEFONE
            // ==================================================
            const Text(
              'Não tem mais acesso a este telefone?',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: _isSendingCode || _isConfirmingCode
                  ? null
                  : _openEmailRecovery,
              icon: const Icon(Icons.mark_email_read_outlined),
              label: const Text('RECUPERAR PELO E-MAIL'),
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security_outlined),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'A recuperação pelo e-mail '
                      'é destinada a situações em '
                      'que o telefone antigo foi '
                      'perdido, roubado ou não está '
                      'mais disponível.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
