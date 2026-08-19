import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:j2i_app_barbearia/core/services/mfa_recovery_service.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';

enum _RecoveryStage { form, waitingEmail }

class MfaRecoveryPage extends StatefulWidget {
  final String? initialEmail;

  const MfaRecoveryPage({super.key, this.initialEmail});

  @override
  State<MfaRecoveryPage> createState() => _MfaRecoveryPageState();
}

class _MfaRecoveryPageState extends State<MfaRecoveryPage> {
  final AuthRepository _authRepository = AuthRepository();

  final MfaRecoveryService _recoveryService = MfaRecoveryService();

  final TextEditingController _emailController = TextEditingController();

  _RecoveryStage _stage = _RecoveryStage.form;

  bool _isLoading = false;

  String? _requestId;
  String? _recoveryToken;

  int _expiresInMinutes = 15;

  String? _recoveryEmail;

  @override
  void initState() {
    super.initState();

    final initialEmail = widget.initialEmail?.trim().toLowerCase();

    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();

    super.dispose();
  }

  // ============================================================
  // VALIDAR E-MAIL
  // ============================================================

  bool _isValidEmail(String email) {
    final normalized = email.trim();

    if (normalized.length < 5 || normalized.length > 254) {
      return false;
    }

    final atIndex = normalized.indexOf('@');

    final dotIndex = normalized.lastIndexOf('.');

    return atIndex > 0 &&
        dotIndex > atIndex + 1 &&
        dotIndex < normalized.length - 1;
  }

  // ============================================================
  // MASCARAR E-MAIL
  // ============================================================

  String _maskedEmail(String email) {
    final parts = email.split('@');

    if (parts.length != 2) {
      return email;
    }

    final name = parts.first;

    final domain = parts.last;

    if (name.length <= 2) {
      return '${name.substring(0, 1)}***@$domain';
    }

    return '${name.substring(0, 2)}***@$domain';
  }

  // ============================================================
  // SNACKBAR
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
  // INICIAR RECUPERAÇÃO
  // ============================================================

  Future<void> _startRecovery() async {
    if (_isLoading) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    if (!_isValidEmail(email)) {
      _showMessage('Informe um e-mail válido.');

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ========================================================
      // 1. CRIA A SOLICITAÇÃO NO NOSSO BACKEND
      // ========================================================

      final result = await _recoveryService.startRecovery(email: email);

      // ========================================================
      // 2. FIREBASE ENVIA O E-MAIL DE REDEFINIÇÃO
      // ========================================================

      await _authRepository.sendPasswordResetEmail(email: email);

      if (!mounted) {
        return;
      }

      setState(() {
        _requestId = result.requestId;

        _recoveryToken = result.recoveryToken;

        _expiresInMinutes = result.expiresInMinutes;

        _recoveryEmail = email;

        _stage = _RecoveryStage.waitingEmail;

        _isLoading = false;
      });

      _showMessage('E-mail de recuperação enviado.');
    } on MfaRecoveryException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(e.message);
    } catch (e) {
      debugPrint('START MFA RECOVERY ERROR -> $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Não foi possível iniciar '
        'a recuperação da conta.',
      );
    }
  }

  // ============================================================
  // REENVIAR E-MAIL
  // ============================================================

  Future<void> _resendEmail() async {
    if (_isLoading) {
      return;
    }

    final email = _recoveryEmail;

    if (email == null || email.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.sendPasswordResetEmail(email: email);

      _showMessage('Novo e-mail de recuperação enviado.');
    } catch (e) {
      debugPrint('RESEND RECOVERY EMAIL ERROR -> $e');

      _showMessage(
        'Não foi possível reenviar '
        'o e-mail.',
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
  // CONFIRMAR QUE A SENHA FOI REDEFINIDA
  // ============================================================

  Future<void> _completeRecovery() async {
    if (_isLoading) {
      return;
    }

    final requestId = _requestId;

    final recoveryToken = _recoveryToken;

    if (requestId == null || recoveryToken == null) {
      _showMessage(
        'A solicitação de recuperação '
        'não está mais disponível.',
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final message = await _recoveryService.completeRecovery(
        requestId: requestId,
        recoveryToken: recoveryToken,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // BACKEND CONFIRMOU A RECUPERAÇÃO
      // ========================================================

      await _showRecoverySuccessDialog(message);

      // ========================================================
      // SAIR DA SESSÃO LOCAL
      // ========================================================

      await _authRepository.signOut();

      if (!mounted) {
        return;
      }

      // ========================================================
      // VOLTAR AO INÍCIO DO APP
      // ========================================================

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on MfaRecoveryException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      switch (e.code) {
        case 'PASSWORD_RESET_NOT_DETECTED':
          _showMessage(
            'Ainda não detectamos a redefinição '
            'da senha. Abra o e-mail, crie uma '
            'nova senha e depois tente novamente.',
          );
          break;

        case 'RECOVERY_EXPIRED':
          _showMessage(
            'A solicitação expirou. '
            'Inicie uma nova recuperação.',
          );
          break;

        case 'RECOVERY_ALREADY_USED':
          _showMessage('Esta recuperação já foi utilizada.');
          break;

        default:
          _showMessage(e.message);
      }
    } catch (e) {
      debugPrint('COMPLETE MFA RECOVERY ERROR -> $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Não foi possível concluir '
        'a recuperação.',
      );
    }
  }

  // ============================================================
  // DIÁLOGO DE SUCESSO
  // ============================================================

  Future<void> _showRecoverySuccessDialog(String message) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.verified_user_outlined, size: 52),
          title: const Text('Acesso recuperado'),
          content: Text(
            '$message\n\n'
            'Por segurança, você será desconectado. '
            'Entre novamente com sua nova senha e '
            'cadastre um novo telefone.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('ENTRAR NOVAMENTE'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar acesso')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 18),

            const Icon(Icons.mark_email_read_outlined, size: 78),

            const SizedBox(height: 24),

            const Text(
              'Recuperação pelo e-mail',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            if (_stage == _RecoveryStage.form) _buildForm(),

            if (_stage == _RecoveryStage.waitingEmail) _buildWaitingEmail(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMULÁRIO INICIAL
  // ============================================================

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Use esta opção somente se você '
          'não tiver mais acesso ao telefone '
          'de segurança cadastrado.',
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [LengthLimitingTextInputFormatter(254)],
          decoration: const InputDecoration(
            labelText: 'E-mail da conta',
            hintText: 'seuemail@exemplo.com',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) {
            if (!_isLoading) {
              _startRecovery();
            }
          },
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Você receberá um e-mail para '
                  'definir uma nova senha. '
                  'Depois disso, volte ao aplicativo '
                  'para finalizar a recuperação.',
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _startRecovery,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.outgoing_mail),
            label: Text(
              _isLoading ? 'ENVIANDO...' : 'ENVIAR E-MAIL DE RECUPERAÇÃO',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AGUARDANDO REDEFINIÇÃO
  // ============================================================

  Widget _buildWaitingEmail() {
    final email = _recoveryEmail ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Enviamos as instruções para:', textAlign: TextAlign.center),

        const SizedBox(height: 8),

        Text(
          _maskedEmail(email),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 28),

        const _RecoveryStep(
          number: '1',
          title: 'Abra o e-mail',
          description:
              'Procure a mensagem de redefinição '
              'de senha enviada pelo Firebase.',
        ),

        const _RecoveryStep(
          number: '2',
          title: 'Crie uma nova senha',
          description:
              'Abra o link do e-mail e conclua '
              'a redefinição da senha.',
        ),

        const _RecoveryStep(
          number: '3',
          title: 'Volte para o aplicativo',
          description:
              'Depois de criar a nova senha, '
              'pressione o botão abaixo.',
        ),

        const SizedBox(height: 10),

        Text(
          'Esta solicitação fica disponível '
          'por aproximadamente '
          '$_expiresInMinutes minutos.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),

        const SizedBox(height: 26),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _completeRecovery,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _isLoading ? 'VERIFICANDO...' : 'JÁ REDEFINI MINHA SENHA',
            ),
          ),
        ),

        const SizedBox(height: 10),

        TextButton.icon(
          onPressed: _isLoading ? null : _resendEmail,
          icon: const Icon(Icons.refresh),
          label: const Text('REENVIAR E-MAIL'),
        ),

        const SizedBox(height: 4),

        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _stage = _RecoveryStage.form;

                    _requestId = null;

                    _recoveryToken = null;

                    _recoveryEmail = null;
                  });
                },
          child: const Text('USAR OUTRO E-MAIL'),
        ),
      ],
    );
  }
}

// ============================================================
// ITEM VISUAL DAS ETAPAS
// ============================================================

class _RecoveryStep extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _RecoveryStep({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
