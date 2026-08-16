import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

class MfaSignInPage extends StatefulWidget {
  final MultiFactorResolver resolver;

  const MfaSignInPage({super.key, required this.resolver});

  @override
  State<MfaSignInPage> createState() => _MfaSignInPageState();
}

class _MfaSignInPageState extends State<MfaSignInPage> {
  final _authRepository = AuthRepository();
  final _codeController = TextEditingController();

  String? _verificationId;

  bool _isSending = false;
  bool _codeSent = false;
  bool _isConfirming = false;

  PhoneMultiFactorInfo? get _phoneHint {
    for (final hint in widget.resolver.hints) {
      if (hint is PhoneMultiFactorInfo) {
        return hint;
      }
    }

    return null;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final hint = _phoneHint;

    if (hint == null) {
      _showMessage('Nenhum telefone de segurança foi encontrado.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _authRepository.startMfaSignIn(
        resolver: widget.resolver,
        hint: hint,
        verificationCompleted: (_) {},
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            _isSending = false;
          });

          _handleFirebaseError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isSending = false;
          });

          _showMessage('Código de segurança enviado.');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _isSending = false;
          });
        },
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      _handleFirebaseError(e);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      _showMessage('Não foi possível enviar o código.');
    }
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;

    final code = _codeController.text.trim();

    if (verificationId == null) {
      _showMessage('Solicite o código primeiro.');
      return;
    }

    if (code.length != 6) {
      _showMessage('Informe o código de 6 dígitos.');
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      await _authRepository.completeMfaSignIn(
        resolver: widget.resolver,
        verificationId: verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      _showMessage('Login confirmado com sucesso!');

      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _handleFirebaseError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException exception) {
    String message;

    switch (exception.code) {
      case 'invalid-verification-code':
        message = 'O código informado é inválido.';
        break;

      case 'session-expired':
        message = 'O código expirou. Solicite outro.';
        break;

      case 'too-many-requests':
        message = 'Muitas tentativas. Aguarde e tente novamente.';
        break;

      case 'network-request-failed':
        message = 'Verifique sua conexão com a internet.';
        break;

      default:
        message = 'Erro Firebase: ${exception.code}';
    }

    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phoneHint?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação de segurança')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              const Icon(Icons.phonelink_lock_outlined, size: 80),

              const SizedBox(height: 24),

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

              if (phone.isNotEmpty)
                Text(
                  'Telefone de segurança: $phone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 32),

              if (!_codeSent)
                FilledButton.icon(
                  onPressed: _isSending ? null : _sendCode,
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(_isSending ? 'ENVIANDO...' : 'ENVIAR CÓDIGO'),
                ),

              if (_codeSent) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código de segurança',
                    hintText: '123456',
                    counterText: '',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _isConfirming ? null : _confirmCode,
                  child: Text(
                    _isConfirming ? 'CONFIRMANDO...' : 'CONFIRMAR LOGIN',
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isSending ? null : _sendCode,
                  child: const Text('Reenviar código'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
