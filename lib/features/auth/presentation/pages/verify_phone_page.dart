import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({super.key});

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final _authRepository = AuthRepository();
  final _codeController = TextEditingController();

  String? _registeredPhone;
  String? _verificationId;
  int? _resendToken;

  bool _isLoadingPhone = true;
  bool _isSending = false;
  bool _isConfirming = false;
  bool _codeSent = false;

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadPhone() async {
    try {
      final phone = await _authRepository.getRegisteredPhone();

      if (!mounted) return;

      setState(() {
        _registeredPhone = phone;
        _isLoadingPhone = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingPhone = false;
      });

      _showMessage('Não foi possível carregar o telefone cadastrado.');
    }
  }

  String? _convertPhoneToE164(String? value) {
    if (value == null) {
      return null;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 10 && digits.length != 11) {
      return null;
    }

    return '+55$digits';
  }

  Future<void> _sendCode({bool resend = false}) async {
    final phone = _convertPhoneToE164(_registeredPhone);

    if (phone == null) {
      _showMessage('O telefone cadastrado é inválido.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    await _authRepository.startPhoneVerification(
      phoneNumber: phone,
      forceResendingToken: resend ? _resendToken : null,

      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await _authRepository.linkPhoneCredential(credential);

          if (!mounted) return;

          _showMessage('Telefone confirmado com sucesso!');
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          _handleFirebaseError(e);
        } finally {
          if (mounted) {
            setState(() {
              _isSending = false;
            });
          }
        }
      },

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
          _resendToken = resendToken;
          _codeSent = true;
          _isSending = false;
        });

        _showMessage('Código enviado.');
      },

      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
          _isSending = false;
        });
      },
    );
  }

  Future<void> _confirmCode() async {
    final verificationId = _verificationId;

    final code = _codeController.text.trim();

    if (verificationId == null) {
      _showMessage('Solicite o código novamente.');
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
      await _authRepository.confirmPhoneCode(
        verificationId: verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      _showMessage('Telefone confirmado com sucesso!');

      await _authRepository.reloadCurrentUser();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _handleFirebaseError(e);
    } catch (_) {
      if (!mounted) return;

      _showMessage('Não foi possível confirmar o telefone.');
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  void _handleFirebaseError(FirebaseAuthException exception) {
    debugPrint(
      'PHONE AUTH ERROR -> '
      'code: ${exception.code} | '
      'message: ${exception.message}',
    );

    String message;

    switch (exception.code) {
      case 'invalid-phone-number':
        message = 'O telefone informado é inválido.';
        break;

      case 'invalid-verification-code':
        message = 'O código informado é inválido.';
        break;

      case 'session-expired':
        message = 'O código expirou. Solicite outro.';
        break;

      case 'too-many-requests':
        message = 'Muitas tentativas. Aguarde e tente novamente.';
        break;

      case 'quota-exceeded':
        message = 'O limite de verificações foi atingido.';
        break;

      case 'credential-already-in-use':
        message = 'Este telefone já está vinculado a outra conta.';
        break;

      case 'provider-already-linked':
        message = 'O telefone já está vinculado à sua conta.';
        break;

      case 'network-request-failed':
        message = 'Verifique sua conexão com a internet.';
        break;

      default:
        message =
            'Erro Firebase: ${exception.code}\n'
            '${exception.message ?? ''}';
    }

    _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    await _authRepository.signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPhone) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar telefone'),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              const Icon(Icons.sms_outlined, size: 80),

              const SizedBox(height: 24),

              const Text(
                'Confirme seu telefone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              const Text(
                'Enviaremos um código de segurança '
                'para o telefone cadastrado:',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                _registeredPhone ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 32),

              if (!_codeSent)
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSending ? null : _sendCode,
                    child: _isSending
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'ENVIAR CÓDIGO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

              if (_codeSent) ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Código recebido',
                    hintText: '123456',
                    border: OutlineInputBorder(),
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) {
                    if (!_isConfirming) {
                      _confirmCode();
                    }
                  },
                ),

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isConfirming ? null : _confirmCode,
                    child: _isConfirming
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'CONFIRMAR CÓDIGO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isSending
                      ? null
                      : () {
                          _sendCode(resend: true);
                        },
                  child: const Text('Reenviar código'),
                ),
              ],

              const SizedBox(height: 24),

              TextButton(
                onPressed: _logout,
                child: const Text('Sair da conta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
