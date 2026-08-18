import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/profile/presentation/pages/change_email_page.dart';

class ClientProfilePage extends StatefulWidget {
  final String? initialUserName;
  final String initialEmail;
  final VoidCallback onOpenSecurity;
  final Future<void> Function() onLogout;

  const ClientProfilePage({
    super.key,
    required this.initialUserName,
    required this.initialEmail,
    required this.onOpenSecurity,
    required this.onLogout,
  });

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final AuthRepository _authRepository = AuthRepository();

  late Future<Map<String, dynamic>?> _profileFuture;

  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();

    _profileFuture = _authRepository.getCurrentUserProfileData();
  }

  // ============================================================
  // ATUALIZAR PERFIL
  // ============================================================

  void _refreshProfile() {
    if (!mounted) {
      return;
    }

    setState(() {
      _profileFuture = _authRepository.getCurrentUserProfileData();
    });
  }

  // ============================================================
  // FORMATAR CPF
  // ============================================================

  String _formatCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 11) {
      return cpf;
    }

    return '${digits.substring(0, 3)}.'
        '${digits.substring(3, 6)}.'
        '${digits.substring(6, 9)}-'
        '${digits.substring(9, 11)}';
  }

  // ============================================================
  // FORMATAR TELEFONE
  // ============================================================

  String _formatPhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('55') && digits.length >= 12) {
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

    return phone;
  }

  // ============================================================
  // EDITAR NOME
  // ============================================================

  Future<void> _editName(String currentName) async {
    final newName = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _EditNameDialog(initialName: currentName);
      },
    );

    // Cancelou o diálogo.
    if (newName == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final normalizedName = newName.trim();

    if (normalizedName == currentName.trim()) {
      return;
    }

    setState(() {
      _isSavingName = true;
    });

    try {
      await _authRepository.updateCurrentUserName(name: normalizedName);

      if (!mounted) {
        return;
      }

      _refreshProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome atualizado com sucesso.')),
      );
    } catch (e) {
      debugPrint('UPDATE NAME ERROR -> $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível atualizar o nome.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  // ============================================================
  // ALTERAR E-MAIL
  // ============================================================

  Future<void> _openChangeEmail(String currentEmail) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeEmailPage(currentEmail: currentEmail),
      ),
    );

    if (changed == true && mounted) {
      _refreshProfile();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          debugPrint(
            'PROFILE ERROR -> '
            '${snapshot.error}',
          );

          return _ProfileError(onRetry: _refreshProfile);
        }

        final profile = snapshot.data ?? {};

        final storedName = profile['name'] as String?;

        final storedEmail = profile['email'] as String?;

        final storedPhone = profile['phone'] as String?;

        final storedCpf = profile['cpf'] as String?;

        // ======================================================
        // NOME
        // ======================================================

        final name = storedName != null && storedName.trim().isNotEmpty
            ? storedName.trim()
            : widget.initialUserName?.trim().isNotEmpty == true
            ? widget.initialUserName!.trim()
            : 'Usuário';

        // ======================================================
        // E-MAIL
        // ======================================================

        final email = storedEmail != null && storedEmail.trim().isNotEmpty
            ? storedEmail.trim()
            : widget.initialEmail;

        // ======================================================
        // TELEFONE
        // ======================================================

        final phone = storedPhone != null && storedPhone.trim().isNotEmpty
            ? _formatPhone(storedPhone)
            : 'Não informado';

        // ======================================================
        // CPF
        // ======================================================

        final cpf = storedCpf != null && storedCpf.trim().isNotEmpty
            ? _formatCpf(storedCpf)
            : 'Não informado';

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),

              // ==================================================
              // AVATAR
              // ==================================================
              const CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 54),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // NOME PRINCIPAL
              // ==================================================
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              // ==================================================
              // E-MAIL PRINCIPAL
              // ==================================================
              Text(
                email,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // DADOS PESSOAIS
              // ==================================================
              const Text(
                'Dados pessoais',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    // =============================================
                    // NOME
                    // =============================================
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Nome'),
                      subtitle: Text(name),
                      trailing: _isSavingName
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit_outlined),
                      onTap: _isSavingName
                          ? null
                          : () {
                              _editName(name);
                            },
                    ),

                    const Divider(height: 1),

                    // =============================================
                    // E-MAIL
                    // =============================================
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('E-mail'),
                      subtitle: Text(email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _openChangeEmail(email);
                      },
                    ),

                    const Divider(height: 1),

                    // =============================================
                    // TELEFONE
                    // =============================================
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Telefone'),
                      subtitle: Text(phone),
                      trailing: const Icon(Icons.verified_outlined),
                    ),

                    const Divider(height: 1),

                    // =============================================
                    // CPF
                    // =============================================
                    ListTile(
                      leading: const Icon(Icons.fingerprint),
                      title: const Text('CPF'),
                      subtitle: Text(cpf),
                      trailing: const Icon(Icons.lock_outline),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'O CPF não pode ser alterado. '
                'Alterações de e-mail e telefone '
                'exigem nova verificação de segurança.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // SEGURANÇA
              // ==================================================
              Card(
                child: ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text('Segurança'),
                  subtitle: const Text('MFA e dispositivos da conta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: widget.onOpenSecurity,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // LOGOUT
              // ==================================================
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.onLogout();
                },
                icon: const Icon(Icons.logout),
                label: const Text('SAIR DA CONTA'),
              ),

              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// DIÁLOGO DE EDIÇÃO DO NOME
// ============================================================
//
// IMPORTANTE:
//
// O TextEditingController pertence ao State deste diálogo.
// Portanto ele só é destruído quando o diálogo realmente
// sai da árvore de widgets.
//
// Isso evita o erro:
//
// '_dependents.isEmpty': is not true
//
// que acontecia ao cancelar o diálogo.
// ============================================================

class _EditNameDialog extends StatefulWidget {
  final String initialName;

  const _EditNameDialog({required this.initialName});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Informe seu nome.';
    }

    if (name.length < 2) {
      return 'Informe um nome válido.';
    }

    if (name.length > 80) {
      return 'O nome deve possuir no máximo 80 caracteres.';
    }

    return null;
  }

  void _save() {
    final valid = _formKey.currentState?.validate() ?? false;

    if (!valid) {
      return;
    }

    final name = _controller.text.trim();

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.edit_outlined),
      title: const Text('Editar nome'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          validator: _validateName,
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            _save();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('CANCELAR'),
        ),
        FilledButton(onPressed: _save, child: const Text('SALVAR')),
      ],
    );
  }
}

// ============================================================
// ERRO AO CARREGAR PERFIL
// ============================================================

class _ProfileError extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 72),

            const SizedBox(height: 20),

            const Text(
              'Não foi possível carregar seu perfil.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('TENTAR NOVAMENTE'),
            ),
          ],
        ),
      ),
    );
  }
}
