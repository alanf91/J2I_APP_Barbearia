import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

class MfaEnrollmentPage extends StatefulWidget {
  const MfaEnrollmentPage({super.key});

  @override
  State<MfaEnrollmentPage> createState() => _MfaEnrollmentPageState();
}

class _MfaEnrollmentPageState extends State<MfaEnrollmentPage> {
  final _authRepository = AuthRepository();

  final _passwordController = TextEditingController();

  final _codeController = TextEditingController();

  String? _verificationId;

  bool _isChecking = true;
  bool _alreadyEnabled = false;
  bool _passwordConfirmed = false;
  bool _codeSent = false;

  bool _isAuthenticating = false;
  bool _isSending = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _checkMfa();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkMfa() async {
    try {
      final enabled = await _authRepository.hasMfaEnabled();

      if (!mounted) return;

      setState(() {
        _alreadyEnabled = enabled;
        _isChecking = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isChecking = false;
      });
    }
  }

  Future<void> _confirmPassword() async {
    if (_passwordController.text.isEmpty) {
      _showMessage('Informe sua senha.');
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      await _authRepository.reauthenticateWithPassword(
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _passwordConfirmed = true;
      });

      _showMessage('Identidade confirmada.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        _showMessage('Senha incorreta.');
      } else {
        _showMessage('Não foi possível confirmar sua senha.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _sendCode() async {
    final user = _authRepository.currentUser;

    final phone = user?.phoneNumber;

    if (phone == null || phone.isEmpty) {
      _showMessage('Nenhum telefone verificado foi encontrado.');
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _authRepository.startMfaEnrollment(
        phoneNumber: phone,

        verificationCompleted: (_) {},

        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;

          setState(() {
            _isSending = false;
          });

          _showMessage('Erro Firebase: ${e.code}');
        },

        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      _showMessage('Não foi possível iniciar a verificação.');
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
      await _authRepository.completeMfaEnrollment(
        verificationId: verificationId,
        smsCode: code,
      );

      if (!mounted) return;

      setState(() {
        _alreadyEnabled = true;
      });

      _showMessage('Verificação em duas etapas ativada!');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      _showMessage('Erro Firebase: ${e.code}');
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Verificação em duas etapas')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              Icon(
                _alreadyEnabled
                    ? Icons.verified_user_outlined
                    : Icons.security_outlined,
                size: 80,
              ),

              const SizedBox(height: 24),

              Text(
                _alreadyEnabled ? 'Proteção ativada' : 'Proteja sua conta',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              if (_alreadyEnabled)
                const Text(
                  'A autenticação em duas etapas '
                  'está ativa nesta conta.',
                  textAlign: TextAlign.center,
                )
              else ...[
                const Text(
                  'Além da sua senha, novos logins '
                  'exigirão um código de segurança.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                if (!_passwordConfirmed) ...[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirme sua senha',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _isAuthenticating ? null : _confirmPassword,
                    child: const Text('CONFIRMAR IDENTIDADE'),
                  ),
                ],

                if (_passwordConfirmed && !_codeSent) ...[
                  const Text(
                    'Sua identidade foi confirmada. '
                    'Agora enviaremos um código '
                    'para o telefone verificado.',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: _isSending ? null : _sendCode,
                    child: const Text('ENVIAR CÓDIGO'),
                  ),
                ],

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
                    ),
                  ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _isConfirming ? null : _confirmCode,
                    child: const Text('ATIVAR VERIFICAÇÃO EM DUAS ETAPAS'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
