import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/auth/data/repositories/auth_repository.dart';
import 'package:j2i_app_barbearia/features/profile/presentation/pages/change_email_page.dart';
import 'package:j2i_app_barbearia/features/profile/presentation/pages/change_phone_page.dart';

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
  State<ClientProfilePage> createState() =>
      _ClientProfilePageState();
}

class _ClientProfilePageState
    extends State<ClientProfilePage> {
  final AuthRepository _authRepository =
      AuthRepository();

  late Future<Map<String, dynamic>?>
      _profileFuture;

  bool _isSavingName = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _profileFuture =
        _authRepository
            .getCurrentUserProfileData();
  }

  // ============================================================
  // ATUALIZAR PERFIL
  // ============================================================

  void _refreshProfile() {
    if (!mounted) {
      return;
    }

    setState(() {
      _profileFuture =
          _authRepository
              .getCurrentUserProfileData();
    });
  }

  // ============================================================
  // FORMATAR CPF
  // ============================================================

  String _formatCpf(String cpf) {
    final digits =
        cpf.replaceAll(
      RegExp(r'\D'),
      '',
    );

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
    var digits =
        phone.replaceAll(
      RegExp(r'\D'),
      '',
    );

    if (
      digits.startsWith('55') &&
      digits.length >= 12
    ) {
      digits =
          digits.substring(2);
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
  // INICIAL DO NOME
  // ============================================================

  String _initialFromName(
    String name,
  ) {
    final normalized =
        name.trim();

    if (normalized.isEmpty) {
      return 'U';
    }

    return normalized
        .substring(0, 1)
        .toUpperCase();
  }

  // ============================================================
  // EDITAR NOME
  // ============================================================

  Future<void> _editName(
    String currentName,
  ) async {
    final newName =
        await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return _EditNameDialog(
          initialName:
              currentName,
        );
      },
    );

    if (newName == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final normalizedName =
        newName.trim();

    if (
      normalizedName ==
      currentName.trim()
    ) {
      return;
    }

    setState(() {
      _isSavingName = true;
    });

    try {
      await _authRepository
          .updateCurrentUserName(
        name: normalizedName,
      );

      if (!mounted) {
        return;
      }

      _refreshProfile();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Nome atualizado com sucesso.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'UPDATE NAME ERROR -> $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível atualizar o nome.',
          ),
        ),
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

  Future<void> _openChangeEmail(
    String currentEmail,
  ) async {
    final changed =
        await Navigator.of(
      context,
    ).push<bool>(
      MaterialPageRoute(
        builder:
            (_) =>
                ChangeEmailPage(
          currentEmail:
              currentEmail,
        ),
      ),
    );

    if (
      changed == true &&
      mounted
    ) {
      _refreshProfile();
    }
  }

  // ============================================================
  // ALTERAR TELEFONE
  // ============================================================

  Future<void> _openChangePhone() async {
    final changed =
        await Navigator.of(
      context,
    ).push<bool>(
      MaterialPageRoute(
        builder:
            (_) =>
                const ChangePhonePage(),
      ),
    );

    if (
      changed == true &&
      mounted
    ) {
      _refreshProfile();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<
        Map<String, dynamic>?>(
      future:
          _profileFuture,
      builder:
          (
            context,
            snapshot,
          ) {
        // ======================================================
        // CARREGANDO
        // ======================================================

        if (
          snapshot.connectionState ==
          ConnectionState.waiting
        ) {
          return const _ProfileLoading();
        }

        // ======================================================
        // ERRO
        // ======================================================

        if (snapshot.hasError) {
          debugPrint(
            'PROFILE ERROR -> '
            '${snapshot.error}',
          );

          return _ProfileError(
            onRetry:
                _refreshProfile,
          );
        }

        final profile =
            snapshot.data ?? {};

        final storedName =
            profile['name']
                as String?;

        final storedEmail =
            profile['email']
                as String?;

        final storedPhone =
            profile['phone']
                as String?;

        final storedCpf =
            profile['cpf']
                as String?;

        // ======================================================
        // NOME
        // ======================================================

        final name =
            storedName != null &&
                    storedName
                        .trim()
                        .isNotEmpty
                ? storedName.trim()
                : widget.initialUserName
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? widget
                        .initialUserName!
                        .trim()
                    : 'Usuário';

        // ======================================================
        // E-MAIL
        // ======================================================

        final email =
            storedEmail != null &&
                    storedEmail
                        .trim()
                        .isNotEmpty
                ? storedEmail.trim()
                : widget.initialEmail;

        // ======================================================
        // TELEFONE
        // ======================================================

        final phone =
            storedPhone != null &&
                    storedPhone
                        .trim()
                        .isNotEmpty
                ? _formatPhone(
                    storedPhone,
                  )
                : 'Não informado';

        // ======================================================
        // CPF
        // ======================================================

        final cpf =
            storedCpf != null &&
                    storedCpf
                        .trim()
                        .isNotEmpty
                ? _formatCpf(
                    storedCpf,
                  )
                : 'Não informado';

        return SafeArea(
          child: ListView(
            padding:
                const EdgeInsets
                    .fromLTRB(
              18,
              14,
              18,
              32,
            ),
            children: [
              // =================================================
              // PERFIL PRINCIPAL
              // =================================================

              _ProfileHeaderCard(
                name:
                    name,
                email:
                    email,
                initial:
                    _initialFromName(
                  name,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // MINHA CONTA
              // =================================================

              const _SectionTitle(
                title:
                    'Minha conta',
                subtitle:
                    'Gerencie seus dados pessoais',
              ),

              const SizedBox(
                height: 12,
              ),

              _AccountCard(
                children: [
                  // =============================================
                  // NOME
                  // =============================================

                  _ProfileOption(
                    icon:
                        Icons
                            .person_outline_rounded,
                    title:
                        'Nome',
                    value:
                        name,
                    trailing:
                        _isSavingName
                            ? const SizedBox(
                                width:
                                    22,
                                height:
                                    22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth:
                                      2,
                                ),
                              )
                            : const Icon(
                                Icons
                                    .edit_outlined,
                              ),
                    onTap:
                        _isSavingName
                            ? null
                            : () {
                                _editName(
                                  name,
                                );
                              },
                  ),

                  const _AccountDivider(),

                  // =============================================
                  // E-MAIL
                  // =============================================

                  _ProfileOption(
                    icon:
                        Icons
                            .alternate_email_rounded,
                    title:
                        'E-mail',
                    value:
                        email,
                    trailing:
                        const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                    onTap:
                        () {
                      _openChangeEmail(
                        email,
                      );
                    },
                  ),

                  const _AccountDivider(),

                  // =============================================
                  // TELEFONE
                  // =============================================

                  _ProfileOption(
                    icon:
                        Icons
                            .phone_outlined,
                    title:
                        'Telefone',
                    value:
                        phone,
                    trailing:
                        const Icon(
                      Icons
                          .chevron_right_rounded,
                    ),
                    onTap:
                        _openChangePhone,
                  ),

                  const _AccountDivider(),

                  // =============================================
                  // CPF
                  // =============================================

                  _ProfileOption(
                    icon:
                        Icons
                            .fingerprint_rounded,
                    title:
                        'CPF',
                    value:
                        cpf,
                    trailing:
                        const Icon(
                      Icons
                          .lock_outline_rounded,
                      size:
                          19,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 13,
              ),

              const _CpfInfoCard(),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // SEGURANÇA
              // =================================================

              const _SectionTitle(
                title:
                    'Segurança',
                subtitle:
                    'Proteção e acesso à sua conta',
              ),

              const SizedBox(
                height: 12,
              ),

              _SecurityCard(
                onTap:
                    widget
                        .onOpenSecurity,
              ),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // CONTA
              // =================================================

              const _SectionTitle(
                title:
                    'Sessão',
                subtitle:
                    'Gerencie o acesso ao aplicativo',
              ),

              const SizedBox(
                height: 12,
              ),

              // =================================================
              // LOGOUT
              // =================================================

              SizedBox(
                width:
                    double.infinity,
                height:
                    52,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      () async {
                    await widget
                        .onLogout();
                  },
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        AppColors.error,
                    side:
                        const BorderSide(
                      color:
                          AppColors
                              .error,
                    ),
                  ),
                  icon:
                      const Icon(
                    Icons
                        .logout_rounded,
                  ),
                  label:
                      const Text(
                    'SAIR DA CONTA',
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              const _Footer(),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// CABEÇALHO DO PERFIL
// ============================================================

class _ProfileHeaderCard
    extends StatelessWidget {
  final String name;
  final String email;
  final String initial;

  const _ProfileHeaderCard({
    required this.name,
    required this.email,
    required this.initial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        22,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.black,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child: Column(
        children: [
          // =====================================================
          // AVATAR
          // =====================================================

          Container(
            width:
                84,
            height:
                84,
            alignment:
                Alignment.center,
            decoration:
                BoxDecoration(
              color:
                  AppColors.gold,
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color:
                    Colors.white
                        .withValues(
                  alpha: 0.12,
                ),
                width:
                    4,
              ),
            ),
            child: Text(
              initial,
              style:
                  const TextStyle(
                color:
                    AppColors.black,
                fontSize:
                    34,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // =====================================================
          // NOME
          // =====================================================

          Text(
            name,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize:
                  23,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  -0.4,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          // =====================================================
          // EMAIL
          // =====================================================

          Text(
            email,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Color(
                0xFFBDB9B3,
              ),
              fontSize:
                  12.5,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          // =====================================================
          // SELO
          // =====================================================

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal:
                  12,
              vertical:
                  7,
            ),
            decoration:
                BoxDecoration(
              color:
                  AppColors.graphite,
              borderRadius:
                  BorderRadius.circular(
                30,
              ),
            ),
            child:
                const Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  Icons
                      .verified_user_rounded,
                  color:
                      AppColors.success,
                  size:
                      16,
                ),

                SizedBox(
                  width:
                      6,
                ),

                Text(
                  'CONTA PROTEGIDA',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        9.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TÍTULO DE SEÇÃO
// ============================================================

class _SectionTitle
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style:
                Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.w800,
                    ),
          ),
        ),

        Text(
          subtitle,
          style:
              Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    fontSize:
                        10.5,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// CARD DA CONTA
// ============================================================

class _AccountCard
    extends StatelessWidget {
  final List<Widget> children;

  const _AccountCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Column(
        children:
            children,
      ),
    );
  }
}

// ============================================================
// ITEM DO PERFIL
// ============================================================

class _ProfileOption
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal:
                15,
            vertical:
                14,
          ),
          child: Row(
            children: [
              Container(
                width:
                    43,
                height:
                    43,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .goldSoft,
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      AppColors
                          .goldDark,
                  size:
                      21,
                ),
              ),

              const SizedBox(
                width:
                    13,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .textSecondary,
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      value,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .textPrimary,
                        fontSize:
                            13.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing != null) ...[
                const SizedBox(
                  width:
                      8,
                ),

                IconTheme(
                  data:
                      const IconThemeData(
                    color:
                        AppColors
                            .textSecondary,
                  ),
                  child:
                      trailing!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DIVISOR
// ============================================================

class _AccountDivider
    extends StatelessWidget {
  const _AccountDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height:
          1,
      indent:
          71,
      endIndent:
          15,
    );
  }
}

// ============================================================
// INFO CPF
// ============================================================

class _CpfInfoCard
    extends StatelessWidget {
  const _CpfInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surfaceSecondary,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child:
          const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .info_outline_rounded,
            color:
                AppColors.goldDark,
            size:
                19,
          ),

          SizedBox(
            width:
                9,
          ),

          Expanded(
            child:
                Text(
              'O CPF é protegido e não pode ser alterado. '
              'Mudanças de e-mail e telefone exigem nova '
              'verificação de segurança.',
              style:
                  TextStyle(
                color:
                    AppColors
                        .textSecondary,
                fontSize:
                    11,
                height:
                    1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEGURANÇA
// ============================================================

class _SecurityCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _SecurityCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          AppColors.black,
      borderRadius:
          BorderRadius.circular(
        20,
      ),
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            17,
          ),
          child:
              Row(
            children: [
              Container(
                width:
                    50,
                height:
                    50,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold,
                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .shield_outlined,
                  color:
                      AppColors.black,
                  size:
                      25,
                ),
              ),

              const SizedBox(
                width:
                    14,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Segurança da conta',
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      'Senha, MFA e dispositivos autorizados',
                      style:
                          TextStyle(
                        color:
                            Color(
                          0xFFBDB9B3,
                        ),
                        fontSize:
                            11,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                color:
                    AppColors.gold,
                size:
                    17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RODAPÉ
// ============================================================

class _Footer
    extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(
            Icons
                .content_cut_rounded,
            color:
                AppColors.goldDark,
            size:
                20,
          ),

          SizedBox(
            height:
                6,
          ),

          Text(
            'J2I Barbearia',
            style:
                TextStyle(
              color:
                  AppColors.textSecondary,
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _ProfileLoading
    extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child:
          Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          CircularProgressIndicator(),

          SizedBox(
            height:
                16,
          ),

          Text(
            'Carregando seu perfil...',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DIÁLOGO DE EDIÇÃO DO NOME
// ============================================================
//
// Mantém o controller dentro do State do diálogo para evitar
// erros ao cancelar/fechar a janela.
// ============================================================

class _EditNameDialog
    extends StatefulWidget {
  final String initialName;

  const _EditNameDialog({
    required this.initialName,
  });

  @override
  State<_EditNameDialog> createState() =>
      _EditNameDialogState();
}

class _EditNameDialogState
    extends State<_EditNameDialog> {
  final GlobalKey<FormState>
      _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text:
          widget.initialName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  String? _validateName(
    String? value,
  ) {
    final name =
        value?.trim() ?? '';

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
    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    final name =
        _controller.text.trim();

    Navigator.of(context).pop(
      name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon:
          Container(
        width:
            56,
        height:
            56,
        decoration:
            const BoxDecoration(
          color:
              AppColors.goldSoft,
          shape:
              BoxShape.circle,
        ),
        child:
            const Icon(
          Icons
              .edit_outlined,
          color:
              AppColors.goldDark,
        ),
      ),
      title:
          const Text(
        'Editar nome',
        textAlign:
            TextAlign.center,
      ),
      content:
          Form(
        key:
            _formKey,
        child:
            TextFormField(
          controller:
              _controller,
          autofocus:
              true,
          textCapitalization:
              TextCapitalization.words,
          maxLength:
              80,
          validator:
              _validateName,
          decoration:
              const InputDecoration(
            labelText:
                'Nome completo',
            prefixIcon:
                Icon(
              Icons
                  .person_outline,
            ),
          ),
          textInputAction:
              TextInputAction.done,
          onFieldSubmitted:
              (_) {
            _save();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
              const Text(
            'CANCELAR',
          ),
        ),
        FilledButton(
          onPressed:
              _save,
          child:
              const Text(
            'SALVAR',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ERRO AO CARREGAR PERFIL
// ============================================================

class _ProfileError
    extends StatelessWidget {
  final VoidCallback onRetry;

  const _ProfileError({
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  82,
              height:
                  82,
              decoration:
                  const BoxDecoration(
                color:
                    AppColors.errorSoft,
                shape:
                    BoxShape.circle,
              ),
              child:
                  const Icon(
                Icons
                    .error_outline_rounded,
                size:
                    38,
                color:
                    AppColors.error,
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            const Text(
              'Não foi possível carregar seu perfil',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors.textPrimary,
                fontSize:
                    20,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            const Text(
              'Verifique sua conexão e tente novamente.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    AppColors
                        .textSecondary,
                fontSize:
                    13,
              ),
            ),

            const SizedBox(
              height:
                  22,
            ),

            FilledButton.icon(
              onPressed:
                  onRetry,
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
              ),
              label:
                  const Text(
                'TENTAR NOVAMENTE',
              ),
            ),
          ],
        ),
      ),
    );
  }
}