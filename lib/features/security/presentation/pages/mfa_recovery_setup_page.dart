import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/core/services/mfa_recovery_service.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

enum _SetupStage { phone, smsCode }

class MfaRecoverySetupPage extends StatefulWidget {
  const MfaRecoverySetupPage({super.key});

  @override
  State<MfaRecoverySetupPage> createState() => _MfaRecoverySetupPageState();
}

class _MfaRecoverySetupPageState extends State<MfaRecoverySetupPage> {
  final AuthRepository _authRepository = AuthRepository();

  final MfaRecoveryService _recoveryService = MfaRecoveryService();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _codeController = TextEditingController();

  _SetupStage _stage = _SetupStage.phone;

  bool _isLoading = false;

  String? _newPhoneE164;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();

    super.dispose();
  }

  // ============================================================
  // TELEFONE BRASILEIRO -> E.164
  // ============================================================

  String? _toBrazilE164(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    // Caso usuário informe 55 + DDD + telefone.
    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      return '+$digits';
    }

    // DDD + telefone.
    if (digits.length == 10 || digits.length == 11) {
      return '+55$digits';
    }

    return null;
  }

  // ============================================================
  // NORMALIZAR TELEFONE
  // ============================================================

  String _normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      digits = digits.substring(2);
    }

    return digits;
  }

  // ============================================================
  // COMPARAR TELEFONES
  // ============================================================

  bool _samePhone(String first, String second) {
    return _normalizePhone(first) == _normalizePhone(second);
  }

  // ============================================================
  // FORMATAR TELEFONE
  // ============================================================

  String _formatPhone(String value) {
    final digits = _normalizePhone(value);

    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) '
          '${digits.substring(2, 7)}-'
          '${digits.substring(7, 11)}';
    }

    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) '
          '${digits.substring(2, 6)}-'
          '${digits.substring(6, 10)}';
    }

    return value;
  }

  // ============================================================
  // MENSAGEM
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // ERROS FIREBASE
  // ============================================================

  String _firebaseErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-phone-number':
        return 'O telefone informado é inválido.';

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

      case 'requires-recent-login':
        return 'Sua sessão de segurança expirou. '
            'Saia da conta, entre novamente e tente outra vez.';

      case 'second-factor-already-enrolled':
        return 'Este telefone já está cadastrado '
            'como fator de segurança.';

      case 'network-request-failed':
        return 'Não foi possível conectar ao Firebase. '
            'Verifique sua conexão.';

      default:
        return exception.message ?? 'Não foi possível concluir a operação.';
    }
  }

  // ============================================================
  // ENVIAR CÓDIGO PARA O NOVO TELEFONE
  // ============================================================

  Future<void> _sendCode() async {
    if (_isLoading) {
      return;
    }

    final newPhone = _toBrazilE164(_phoneController.text);

    if (newPhone == null) {
      _showMessage(
        'Informe um telefone brasileiro válido '
        'com DDD.',
      );

      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(
        'Sua sessão expirou. '
        'Entre novamente.',
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // VERIFICAR SE O TELEFONE JÁ FOI CADASTRADO
      //
      // Isso também permite recuperar uma tentativa anterior
      // interrompida depois da confirmação do SMS.
      // ========================================================

      final existingFactors = await _authRepository.getEnrolledPhoneFactors();

      for (final factor in existingFactors) {
        if (_samePhone(factor.phoneNumber, newPhone)) {
          _newPhoneE164 = newPhone;

          await _finalizeRecovery();

          return;
        }
      }

      _newPhoneE164 = newPhone;

      // ========================================================
      // CRIAR SESSÃO MFA E ENVIAR SMS
      // ========================================================

      await _authRepository.startMfaEnrollment(
        phoneNumber: newPhone,

        verificationCompleted: (PhoneAuthCredential credential) {
          // Mantemos confirmação manual do SMS.
        },

        verificationFailed: (FirebaseAuthException exception) {
          if (!mounted) {
            return;
          }

          setState(() {
            _isLoading = false;
          });

          _showMessage(_firebaseErrorMessage(exception));
        },

        codeSent: (String verificationId, int? _) {
          if (!mounted) {
            return;
          }

          _codeController.clear();

          setState(() {
            _verificationId = verificationId;

            _stage = _SetupStage.smsCode;

            _isLoading = false;
          });

          _showMessage(
            'Código enviado para '
            '${_formatPhone(newPhone)}.',
          );
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      debugPrint('RECOVERY MFA SEND CODE ERROR -> $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage(
        'Não foi possível enviar '
        'o código para o novo telefone.',
      );
    }
  }

  // ============================================================
  // CONFIRMAR CÓDIGO SMS
  // ============================================================

  Future<void> _confirmCode() async {
    if (_isLoading) {
      return;
    }

    final verificationId = _verificationId;

    final smsCode = _codeController.text.trim();

    if (verificationId == null) {
      _showMessage(
        'A verificação expirou. '
        'Solicite um novo código.',
      );

      return;
    }

    if (smsCode.length != 6) {
      _showMessage('Informe o código de 6 dígitos.');

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // CADASTRAR NOVO TELEFONE COMO SEGUNDO FATOR
      // ========================================================

      await _authRepository.completeMfaEnrollment(
        verificationId: verificationId,
        smsCode: smsCode,
        displayName: 'Telefone de segurança',
      );

      // ========================================================
      // CONFIRMAR NO BACKEND
      // ========================================================

      await _finalizeRecovery();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage(_firebaseErrorMessage(e));
    } on MfaRecoveryException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage(e.message);
    } catch (e) {
      debugPrint('RECOVERY MFA CONFIRM ERROR -> $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage(
        'Não foi possível confirmar '
        'o novo telefone.',
      );
    }
  }

  // ============================================================
  // REENVIAR CÓDIGO
  // ============================================================

  Future<void> _resendCode() async {
    if (_isLoading) {
      return;
    }

    // Volta para o formulário mantendo o telefone.
    setState(() {
      _stage = _SetupStage.phone;

      _verificationId = null;

      _codeController.clear();
    });

    await _sendCode();
  }

  // ============================================================
  // FINALIZAR RECUPERAÇÃO NO BACKEND
  // ============================================================

  Future<void> _finalizeRecovery() async {
    final phone = _newPhoneE164;

    if (phone == null) {
      throw const MfaRecoveryException('Telefone de recuperação inválido.');
    }

    final message = await _recoveryService.finalizeRecoveredPhone(
      phoneNumber: phone,
    );

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.verified_user_outlined, size: 52),
          title: const Text('Proteção restaurada'),
          content: Text(
            '$message\n\n'
            'Por segurança, você será '
            'desconectado. Entre novamente '
            'e confirme o novo telefone.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('CONTINUAR'),
            ),
          ],
        );
      },
    );

    await _authRepository.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ============================================================
  // SAIR
  // ============================================================

  Future<void> _signOut() async {
    await _authRepository.signOut();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Restaurar proteção'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _signOut,
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 20),

            const Icon(Icons.security_outlined, size: 78),

            const SizedBox(height: 24),

            const Text(
              'Cadastre seu novo telefone',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            const Text(
              'Sua recuperação por e-mail '
              'foi concluída. Agora precisamos '
              'cadastrar um novo telefone de '
              'segurança antes de liberar sua conta.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            if (_stage == _SetupStage.phone) _buildPhoneForm(),

            if (_stage == _SetupStage.smsCode) _buildCodeForm(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMULÁRIO DO TELEFONE
  // ============================================================

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phoneController,
          autofocus: true,
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Novo telefone',
            hintText: '43999999999',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) {
              _sendCode();
            }
          },
        ),

        const Text(
          'Digite DDD + telefone. '
          'Enviaremos um código SMS para confirmação.',
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _sendCode,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sms_outlined),
            label: Text(_isLoading ? 'ENVIANDO...' : 'ENVIAR CÓDIGO'),
          ),
        ),

        const SizedBox(height: 14),

        TextButton(
          onPressed: _isLoading ? null : _signOut,
          child: const Text('Sair da conta'),
        ),
      ],
    );
  }

  // ============================================================
  // FORMULÁRIO DO CÓDIGO
  // ============================================================

  Widget _buildCodeForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirme seu novo telefone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Text(
          'Enviamos um código para '
          '${_formatPhone(_newPhoneE164 ?? '')}.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

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
            labelText: 'Código SMS',
            hintText: '123456',
            prefixIcon: Icon(Icons.sms_outlined),
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!_isLoading) {
              _confirmCode();
            }
          },
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _confirmCode,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _isLoading ? 'CONFIRMANDO...' : 'CONFIRMAR NOVO TELEFONE',
            ),
          ),
        ),

        const SizedBox(height: 10),

        TextButton.icon(
          onPressed: _isLoading ? null : _resendCode,
          icon: const Icon(Icons.refresh),
          label: const Text('REENVIAR CÓDIGO'),
        ),

        const SizedBox(height: 4),

        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _stage = _SetupStage.phone;

                    _verificationId = null;

                    _codeController.clear();
                  });
                },
          child: const Text('ALTERAR NÚMERO'),
        ),
      ],
    );
  }
}
