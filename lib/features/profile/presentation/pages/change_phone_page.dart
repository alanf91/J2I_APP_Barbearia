import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/auth/presentation/pages/mfa_sign_in_page.dart';

enum _PhoneChangeStage { form, newPhoneCode }

class ChangePhonePage extends StatefulWidget {
  const ChangePhonePage({super.key});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final AuthRepository _authRepository = AuthRepository();

  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _codeController = TextEditingController();

  _PhoneChangeStage _stage = _PhoneChangeStage.form;

  bool _isLoading = false;
  bool _isLoadingCurrentPhone = true;

  String? _currentPhone;
  String? _newPhoneE164;
  String? _verificationId;

  final List<String> _oldPhoneFactorUids = [];

  @override
  void initState() {
    super.initState();

    _loadCurrentPhone();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _phoneController.dispose();
    _codeController.dispose();

    super.dispose();
  }

  // ============================================================
  // CARREGAR TELEFONE ATUAL
  // ============================================================

  Future<void> _loadCurrentPhone() async {
    try {
      final phone = await _authRepository.getRegisteredPhone();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentPhone = phone;
        _isLoadingCurrentPhone = false;
      });
    } catch (e) {
      debugPrint('LOAD CURRENT PHONE ERROR -> $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCurrentPhone = false;
      });
    }
  }

  // ============================================================
  // TELEFONE BRASILEIRO → E.164
  // ============================================================

  String? _toBrazilE164(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      return '+$digits';
    }

    if (digits.length == 10 || digits.length == 11) {
      return '+55$digits';
    }

    return null;
  }

  // ============================================================
  // FORMATAR TELEFONE
  // ============================================================

  String _formatPhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('55') &&
        (digits.length == 12 || digits.length == 13)) {
      digits = digits.substring(2);
    }

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

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool _samePhone(String first, String second) {
    var firstDigits = _digitsOnly(first);

    var secondDigits = _digitsOnly(second);

    if (firstDigits.startsWith('55') && firstDigits.length >= 12) {
      firstDigits = firstDigits.substring(2);
    }

    if (secondDigits.startsWith('55') && secondDigits.length >= 12) {
      secondDigits = secondDigits.substring(2);
    }

    return firstDigits == secondDigits;
  }

  // ============================================================
  // ERROS
  // ============================================================

  String _firebaseErrorMessage(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-phone-number':
        return 'O telefone informado é inválido.';

      case 'invalid-verification-code':
        return 'O código informado está incorreto.';

      case 'session-expired':
        return 'O código expirou. '
            'Inicie a alteração novamente.';

      case 'too-many-requests':
        return 'Muitas tentativas foram realizadas. '
            'Aguarde alguns minutos.';

      case 'requires-recent-login':
        return 'Por segurança, faça login novamente '
            'antes de alterar o telefone.';

      case 'second-factor-already-enrolled':
        return 'Este telefone já está cadastrado '
            'como fator de segurança.';

      default:
        return exception.message ??
            'Não foi possível concluir '
                'a alteração do telefone.';
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
  // COMEÇAR
  // ============================================================

  Future<void> _startPhoneChange() async {
    if (_isLoading) {
      return;
    }

    final password = _passwordController.text;

    final newPhone = _toBrazilE164(_phoneController.text);

    if (password.isEmpty) {
      _showMessage('Informe sua senha.');

      return;
    }

    if (newPhone == null) {
      _showMessage('Informe um telefone válido com DDD.');

      return;
    }

    if (_currentPhone != null && _samePhone(newPhone, _currentPhone!)) {
      _showMessage('O novo telefone é igual ao telefone atual.');

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.reauthenticateWithPassword(password: password);

      await _continueAfterAuthentication(newPhone);
    }
    // ==========================================================
    // CONTA PROTEGIDA POR MFA
    // ==========================================================
    on FirebaseAuthMultiFactorException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => MfaSignInPage(resolver: e.resolver)),
      );

      if (!mounted || confirmed != true) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        await _continueAfterAuthentication(newPhone);
      } catch (e) {
        debugPrint('PHONE CHANGE AFTER MFA ERROR -> $e');

        _showMessage(
          'Não foi possível continuar '
          'a alteração do telefone.',
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      debugPrint('START PHONE CHANGE ERROR -> $e');

      _showMessage(
        'Não foi possível iniciar '
        'a alteração do telefone.',
      );
    } finally {
      if (mounted && _stage == _PhoneChangeStage.form) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // APÓS SENHA + MFA ATUAL
  // ============================================================

  Future<void> _continueAfterAuthentication(String newPhone) async {
    final factors = await _authRepository.getEnrolledPhoneFactors();

    _oldPhoneFactorUids.clear();

    PhoneMultiFactorInfo? existingNewFactor;

    for (final factor in factors) {
      // --------------------------------------------------------
      // IMPORTANTE:
      //
      // Se você já passou pelo "1 de 2" anteriormente,
      // o novo fator provavelmente já existe.
      // --------------------------------------------------------

      if (_samePhone(factor.phoneNumber, newPhone)) {
        existingNewFactor = factor;
      } else if (_currentPhone != null &&
          _samePhone(factor.phoneNumber, _currentPhone!)) {
        _oldPhoneFactorUids.add(factor.uid);
      }
    }

    _newPhoneE164 = newPhone;

    // ==========================================================
    // RECUPERAÇÃO DO TESTE ANTERIOR
    // ==========================================================
    //
    // Novo MFA já foi criado antes do erro no "2 de 2".
    //
    // Nesse caso não enviamos outro SMS.
    // Apenas terminamos a migração.
    // ==========================================================

    if (existingNewFactor != null) {
      await _finishPhoneChange(newFactor: existingNewFactor);

      return;
    }

    // ==========================================================
    // NOVO FATOR AINDA NÃO EXISTE
    // ==========================================================

    await _authRepository.startMfaEnrollment(
      phoneNumber: newPhone,

      verificationCompleted: (_) {
        // Confirmação manual.
      },

      verificationFailed: (exception) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
        });

        _showMessage(_firebaseErrorMessage(exception));
      },

      codeSent: (verificationId, resendToken) {
        if (!mounted) {
          return;
        }

        _codeController.clear();

        setState(() {
          _verificationId = verificationId;

          _stage = _PhoneChangeStage.newPhoneCode;

          _isLoading = false;
        });

        _showMessage(
          'Código enviado para '
          '${_formatPhone(newPhone)}.',
        );
      },

      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ============================================================
  // CONFIRMAR NOVO TELEFONE MFA
  // ============================================================

  Future<void> _confirmNewPhone() async {
    if (_isLoading) {
      return;
    }

    final verificationId = _verificationId;

    final newPhone = _newPhoneE164;

    final smsCode = _codeController.text.trim();

    if (verificationId == null || newPhone == null) {
      _showMessage('A verificação expirou.');

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
      await _authRepository.completeMfaEnrollment(
        verificationId: verificationId,
        smsCode: smsCode,
        displayName: 'Telefone principal',
      );

      final factors = await _authRepository.getEnrolledPhoneFactors();

      PhoneMultiFactorInfo? newFactor;

      for (final factor in factors) {
        if (_samePhone(factor.phoneNumber, newPhone)) {
          newFactor = factor;
          break;
        }
      }

      if (newFactor == null) {
        throw Exception('Novo telefone MFA não encontrado.');
      }

      await _finishPhoneChange(newFactor: newFactor);
    } on FirebaseAuthException catch (e) {
      _showMessage(_firebaseErrorMessage(e));
    } catch (e) {
      debugPrint('CONFIRM NEW MFA PHONE ERROR -> $e');

      _showMessage(
        'Não foi possível concluir '
        'a alteração do telefone.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FINALIZAR A MIGRAÇÃO
  // ============================================================

  Future<void> _finishPhoneChange({
    required PhoneMultiFactorInfo newFactor,
  }) async {
    // ==========================================================
    // REMOVE SOMENTE O FATOR ANTIGO
    // ==========================================================

    for (final oldUid in _oldPhoneFactorUids) {
      if (oldUid == newFactor.uid) {
        continue;
      }

      await _authRepository.unenrollMfaFactor(factorUid: oldUid);
    }

    if (!mounted) {
      return;
    }

    _showMessage('Telefone de segurança atualizado com sucesso.');

    Navigator.of(context).pop(true);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alterar telefone')),
      body: SafeArea(
        child: _isLoadingCurrentPhone
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 10),

                  const Icon(Icons.phone_android_outlined, size: 72),

                  const SizedBox(height: 22),

                  const Text(
                    'Telefone da conta',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    _currentPhone == null || _currentPhone!.isEmpty
                        ? 'Nenhum telefone cadastrado.'
                        : 'Telefone atual:\n'
                              '${_formatPhone(_currentPhone!)}',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  if (_stage == _PhoneChangeStage.form) _buildForm(),

                  if (_stage == _PhoneChangeStage.newPhoneCode) _buildCode(),
                ],
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Por segurança, confirme sua senha '
          'antes de alterar o telefone.',
        ),

        const SizedBox(height: 20),

        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Senha atual',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          decoration: const InputDecoration(
            labelText: 'Novo telefone',
            hintText: '43999999999',
            prefixIcon: Icon(Icons.phone_outlined),
            border: OutlineInputBorder(),
          ),
        ),

        const Text('Digite DDD + telefone.'),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _startPhoneChange,
            icon: const Icon(Icons.security_outlined),
            label: Text(
              _isLoading ? 'VERIFICANDO...' : 'CONTINUAR COM SEGURANÇA',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Confirmar novo telefone',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        Text(
          'Digite o código enviado para '
          '${_formatPhone(_newPhoneE164 ?? '')}.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        TextField(
          controller: _codeController,
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
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isLoading ? null : _confirmNewPhone,
            child: Text(
              _isLoading ? 'CONFIRMANDO...' : 'CONFIRMAR NOVO TELEFONE',
            ),
          ),
        ),
      ],
    );
  }
}
