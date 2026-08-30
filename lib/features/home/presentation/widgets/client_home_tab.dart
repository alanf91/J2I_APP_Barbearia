import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';


class ClientHomeTab extends StatelessWidget {
  final void Function(int index) onNavigate;
  final VoidCallback onOpenSecurity;

  // Mantemos os dados que o client_home_page atual já envia.
  final dynamic userName;
  final dynamic email;
  final dynamic appointmentsStream;

  const ClientHomeTab({
    super.key,
    required this.onNavigate,
    required this.onOpenSecurity,
    required this.userName,
    required this.email,
    required this.appointmentsStream,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUserName =
    userName
            ?.toString()
            .trim() ??
        '';

final firstName =
    normalizedUserName.isNotEmpty
        ? normalizedUserName
            .split(
              RegExp(r'\s+'),
            )
            .first
        : null;

    return SafeArea(
      top: true,
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          30,
        ),
        children: [
          // =====================================================
          // CABEÇALHO
          // =====================================================

          _Header(
            firstName: firstName,
          ),

          const SizedBox(height: 22),

          // =====================================================
          // HERO PRINCIPAL
          // =====================================================

          _ScheduleHeroCard(
            onTap: () {
              // Serviços
              onNavigate(2);
            },
          ),

          const SizedBox(height: 28),

          // =====================================================
          // PRÓXIMO HORÁRIO
          // =====================================================

          const _SectionHeader(
            title: 'Seu próximo horário',
            subtitle:
                'Acompanhe seus agendamentos',
          ),

          const SizedBox(height: 12),

          _NextAppointmentCard(
            onTap: () {
              // Agenda
              onNavigate(1);
            },
          ),

          const SizedBox(height: 28),

          // =====================================================
          // ACESSO RÁPIDO
          // =====================================================

          const _SectionHeader(
            title: 'Acesso rápido',
            subtitle:
                'Tudo o que você precisa',
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon:
                      Icons.calendar_month_outlined,

                  title:
                      'Agendamentos',

                  subtitle:
                      'Próximos horários',

                  onTap: () {
                    onNavigate(1);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _QuickActionCard(
                  icon:
                      Icons.content_cut_outlined,

                  title:
                      'Serviços',

                  subtitle:
                      'Escolha seu estilo',

                  onTap: () {
                    onNavigate(2);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon:
                      Icons.person_outline_rounded,

                  title:
                      'Meu perfil',

                  subtitle:
                      'Dados da sua conta',

                  onTap: () {
                    onNavigate(3);
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _QuickActionCard(
                  icon:
                      Icons.shield_outlined,

                  title:
                      'Segurança',

                  subtitle:
                      'Proteção da conta',

                  onTap:
                      onOpenSecurity,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // =====================================================
          // EXPERIÊNCIA
          // =====================================================

          const _ExperienceCard(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _Header extends StatelessWidget {
  final String? firstName;

  const _Header({
    required this.firstName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                firstName != null
                    ? 'Olá, $firstName'
                    : 'Olá',

                style:
                    Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontSize: 27,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
              ),

              const SizedBox(height: 4),

              Text(
                'Pronto para cuidar do seu estilo?',

                style:
                    Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color:
                              AppColors
                                  .textSecondary,

                          fontSize: 14,
                        ),
              ),
            ],
          ),
        ),

        Container(
          width: 48,
          height: 48,

          decoration: BoxDecoration(
            color:
                AppColors.surface,

            borderRadius:
                BorderRadius.circular(
              15,
            ),

            border: Border.all(
              color:
                  AppColors.border,
            ),
          ),

          child: const Icon(
            Icons.content_cut_rounded,
            size: 22,
            color:
                AppColors.goldDark,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CARD PRINCIPAL - AGENDAMENTO
// ============================================================

class _ScheduleHeroCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _ScheduleHeroCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          AppColors.black,

      borderRadius:
          BorderRadius.circular(22),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(22),

        child: Container(
          padding:
              const EdgeInsets.all(
            22,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              22,
            ),

            border:
                Border.all(
              color:
                  Colors.white
                      .withValues(
                alpha: 0.06,
              ),
            ),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,

                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.gold,

                      borderRadius:
                          BorderRadius
                              .circular(
                        15,
                      ),
                    ),

                    child:
                        const Icon(
                      Icons
                          .calendar_month_rounded,

                      color:
                          AppColors.black,

                      size: 26,
                    ),
                  ),

                  const Spacer(),

                  Container(
                    width: 40,
                    height: 40,

                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white
                              .withValues(
                        alpha: 0.08,
                      ),

                      shape:
                          BoxShape.circle,
                    ),

                    child:
                        const Icon(
                      Icons
                          .arrow_forward_rounded,

                      color:
                          Colors.white,

                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Agende seu próximo horário',

                style:
                    TextStyle(
                  color:
                      Colors.white,

                  fontSize:
                      22,

                  height:
                      1.15,

                  fontWeight:
                      FontWeight.w800,

                  letterSpacing:
                      -0.4,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Escolha o serviço, o profissional '
                'e o melhor horário para você.',

                style:
                    TextStyle(
                  color:
                      Color(
                    0xFFC9C6C0,
                  ),

                  fontSize:
                      14,

                  height:
                      1.45,
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Container(
                width:
                    double.infinity,

                height:
                    48,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.gold,

                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),

                child:
                    const Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [
                    Icon(
                      Icons
                          .event_available_outlined,

                      color:
                          AppColors.black,

                      size:
                          20,
                    ),

                    SizedBox(
                      width: 9,
                    ),

                    Text(
                      'AGENDAR AGORA',

                      style:
                          TextStyle(
                        color:
                            AppColors
                                .black,

                        fontSize:
                            14,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CABEÇALHO DAS SEÇÕES
// ============================================================

class _SectionHeader
    extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
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
                          19,

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
                        11,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// PRÓXIMO AGENDAMENTO
// ============================================================

class _NextAppointmentCard
    extends StatelessWidget {
  final VoidCallback onTap;

  const _NextAppointmentCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          AppColors.surface,

      borderRadius:
          BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(18),

        child: Container(
          padding:
              const EdgeInsets.all(17),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border:
                Border.all(
              color:
                  AppColors.border,
            ),
          ),

          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .goldSoft,

                  borderRadius:
                      BorderRadius
                          .circular(
                    15,
                  ),
                ),

                child:
                    const Icon(
                  Icons
                      .event_available_outlined,

                  color:
                      AppColors
                          .goldDark,

                  size:
                      27,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Text(
                      'Nenhum horário agendado',

                      style:
                          TextStyle(
                        fontSize:
                            15,

                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      'Quando você agendar, '
                      'o próximo atendimento aparecerá aqui.',

                      style:
                          Theme.of(
                        context,
                      )
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontSize:
                                    12,

                                height:
                                    1.35,
                              ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 6,
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,

                color:
                    AppColors
                        .textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ACESSO RÁPIDO
// ============================================================

class _QuickActionCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          AppColors.surface,

      borderRadius:
          BorderRadius.circular(18),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(18),

        child: Container(
          height: 132,

          padding:
              const EdgeInsets.all(
            15,
          ),

          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),

            border:
                Border.all(
              color:
                  AppColors.border,
            ),
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors
                          .goldSoft,

                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),

                child:
                    Icon(
                  icon,

                  size:
                      21,

                  color:
                      AppColors
                          .goldDark,
                ),
              ),

              const Spacer(),

              Text(
                title,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    const TextStyle(
                  fontSize:
                      14,

                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                subtitle,

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

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
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EXPERIÊNCIA / MARCA
// ============================================================

class _ExperienceCard
    extends StatelessWidget {
  const _ExperienceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.goldSoft,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          Container(
            width:
                45,

            height:
                45,

            decoration:
                const BoxDecoration(
              color:
                  AppColors.black,

              shape:
                  BoxShape.circle,
            ),

            child:
                const Icon(
              Icons
                  .workspace_premium_outlined,

              color:
                  AppColors.gold,

              size:
                  23,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Sua experiência começa aqui',

                  style:
                      TextStyle(
                    fontSize:
                        14,

                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 4,
                ),

                Text(
                  'Agendamento rápido, seguro '
                  'e pensado para valorizar seu tempo.',

                  style:
                      TextStyle(
                    fontSize:
                        11.5,

                    height:
                        1.35,

                    color:
                        AppColors
                            .textSecondary,
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