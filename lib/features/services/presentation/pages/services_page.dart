import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/professionals/presentation/pages/professional_selection_page.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';
import 'package:j2i_app_barbearia/features/services/data/repositories/service_repository.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  final ServiceRepository _repository =
      ServiceRepository();

  // ============================================================
  // FORMATAÇÃO DE PREÇO
  // ============================================================

  String _formatPrice(int priceCents) {
    final reais = priceCents ~/ 100;

    final cents =
        (priceCents % 100)
            .toString()
            .padLeft(2, '0');

    return 'R\$ $reais,$cents';
  }

  // ============================================================
  // SELECIONAR SERVIÇO
  // ============================================================

  void _selectService(
    BarbershopService service,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                ProfessionalSelectionPage(
          service: service,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child:
          StreamBuilder<
              List<BarbershopService>>(
        stream:
            _repository
                .watchActiveServices(),

        builder:
            (
              context,
              snapshot,
            ) {
          if (
            snapshot.connectionState ==
            ConnectionState.waiting
          ) {
            return const _ServicesLoading();
          }

          if (snapshot.hasError) {
            debugPrint(
              'SERVICES ERROR -> '
              '${snapshot.error}',
            );

            return const _ServicesError();
          }

          final services =
              snapshot.data ?? [];

          if (services.isEmpty) {
            return const _EmptyServices();
          }

          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              32,
            ),

            children: [
              // =================================================
              // CABEÇALHO
              // =================================================

              const _ServicesHeader(),

              const SizedBox(
                height: 26,
              ),

              // =================================================
              // CONTADOR DE SERVIÇOS
              // =================================================

              Row(
                children: [
                  Text(
                    'Serviços disponíveis',

                    style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                  ),

                  const Spacer(),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          AppColors
                              .goldSoft,

                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),

                    child: Text(
                      '${services.length} '
                      '${services.length == 1 ? 'opção' : 'opções'}',

                      style:
                          const TextStyle(
                        color:
                            AppColors
                                .goldDark,

                        fontSize: 11,

                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              // =================================================
              // SERVIÇOS
              // =================================================

              ...services.map(
                (service) {
                  return Padding(
                    padding:
                        const EdgeInsets
                            .only(
                      bottom: 14,
                    ),

                    child:
                        _ServiceCard(
                      service:
                          service,

                      formattedPrice:
                          _formatPrice(
                        service
                            .priceCents,
                      ),

                      onTap: () {
                        _selectService(
                          service,
                        );
                      },
                    ),
                  );
                },
              ),

              const SizedBox(
                height: 8,
              ),

              // =================================================
              // RODAPÉ
              // =================================================

              const _ServicesFooter(),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CABEÇALHO
// ============================================================

class _ServicesHeader
    extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,

              decoration:
                  BoxDecoration(
                color:
                    AppColors.black,

                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),

              child:
                  const Icon(
                Icons
                    .content_cut_rounded,

                color:
                    AppColors.gold,

                size: 23,
              ),
            ),

            const SizedBox(
              width: 13,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  Text(
                    'Escolha seu serviço',

                    style:
                        Theme.of(
                      context,
                    )
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontSize:
                                  25,

                              fontWeight:
                                  FontWeight
                                      .w800,

                              letterSpacing:
                                  -0.5,
                            ),
                  ),

                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    'Seu próximo atendimento '
                    'começa aqui.',

                    style:
                        Theme.of(
                      context,
                    )
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontSize:
                                  12.5,
                            ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 18,
        ),

        Text(
          'Selecione o cuidado que deseja e, '
          'em seguida, escolha o profissional '
          'e o melhor horário para você.',

          style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppColors
                            .textSecondary,

                    fontSize: 14,

                    height: 1.45,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// CARD DO SERVIÇO
// ============================================================

class _ServiceCard
    extends StatelessWidget {
  final BarbershopService service;
  final String formattedPrice;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.formattedPrice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final description =
        service.description.trim();

    return Material(
      color:
          AppColors.surface,

      borderRadius:
          BorderRadius.circular(
        20,
      ),

      child: InkWell(
        onTap: onTap,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        child: Container(
          padding:
              const EdgeInsets.all(
            17,
          ),

          decoration:
              BoxDecoration(
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
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // =================================================
              // TOPO
              // =================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

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
                        Icon(
                      _getServiceIcon(
                        service.name,
                      ),

                      color:
                          AppColors
                              .goldDark,

                      size: 26,
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
                        Text(
                          service.name,

                          style:
                              const TextStyle(
                            color:
                                AppColors
                                    .textPrimary,

                            fontSize:
                                17,

                            fontWeight:
                                FontWeight
                                    .w800,

                            height:
                                1.2,
                          ),
                        ),

                        if (
                          description
                              .isNotEmpty
                        ) ...[
                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            description,

                            maxLines: 2,

                            overflow:
                                TextOverflow
                                    .ellipsis,

                            style:
                                const TextStyle(
                              color:
                                  AppColors
                                      .textSecondary,

                              fontSize:
                                  12.5,

                              height:
                                  1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios_rounded,

                    color:
                        AppColors
                            .textSecondary,

                    size: 15,
                  ),
                ],
              ),

              const SizedBox(
                height: 17,
              ),

              const Divider(),

              const SizedBox(
                height: 14,
              ),

              // =================================================
              // DURAÇÃO + PREÇO
              // =================================================

              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,

                children: [
                  _DurationBadge(
                    durationMinutes:
                        service
                            .durationMinutes,
                  ),

                  const Spacer(),

                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,

                    children: [
                      const Text(
                        'a partir de',

                        style:
                            TextStyle(
                          color:
                              AppColors
                                  .textSecondary,

                          fontSize:
                              10.5,
                        ),
                      ),

                      const SizedBox(
                        height: 1,
                      ),

                      Text(
                        formattedPrice,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .textPrimary,

                          fontSize:
                              19,

                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              // =================================================
              // CTA
              // =================================================

              Container(
                width:
                    double.infinity,

                height:
                    46,

                decoration:
                    BoxDecoration(
                  color:
                      AppColors.black,

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
                    Text(
                      'ESCOLHER SERVIÇO',

                      style:
                          TextStyle(
                        color:
                            Colors.white,

                        fontSize:
                            12.5,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            0.4,
                      ),
                    ),

                    SizedBox(
                      width: 8,
                    ),

                    Icon(
                      Icons
                          .arrow_forward_rounded,

                      color:
                          AppColors.gold,

                      size: 18,
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

  // ============================================================
  // ÍCONE DO SERVIÇO
  // ============================================================

  IconData _getServiceIcon(
    String name,
  ) {
    final normalized =
        name
            .trim()
            .toLowerCase();

    if (
      normalized.contains(
        'barba',
      ) &&
      normalized.contains(
        'corte',
      )
    ) {
      return Icons.auto_awesome;
    }

    if (
      normalized.contains(
        'barba',
      )
    ) {
      return Icons.face_outlined;
    }

    if (
      normalized.contains(
        'sobrancelha',
      )
    ) {
      return Icons
          .visibility_outlined;
    }

    if (
      normalized.contains(
        'cabelo',
      ) ||
      normalized.contains(
        'corte',
      )
    ) {
      return Icons
          .content_cut_rounded;
    }

    return Icons
        .spa_outlined;
  }
}

// ============================================================
// DURAÇÃO
// ============================================================

class _DurationBadge
    extends StatelessWidget {
  final int durationMinutes;

  const _DurationBadge({
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 11,
        vertical: 8,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors
                .surfaceSecondary,

        borderRadius:
            BorderRadius.circular(
          11,
        ),
      ),

      child: Row(
        mainAxisSize:
            MainAxisSize.min,

        children: [
          const Icon(
            Icons
                .schedule_rounded,

            size: 17,

            color:
                AppColors
                    .goldDark,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            '$durationMinutes min',

            style:
                const TextStyle(
              color:
                  AppColors
                      .textPrimary,

              fontSize: 12,

              fontWeight:
                  FontWeight
                      .w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RODAPÉ
// ============================================================

class _ServicesFooter
    extends StatelessWidget {
  const _ServicesFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.goldSoft,

        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),

      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            Icons
                .info_outline_rounded,

            size: 20,

            color:
                AppColors.goldDark,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Na próxima etapa você poderá '
              'escolher o profissional e consultar '
              'os horários disponíveis.',

              style:
                  TextStyle(
                color:
                    AppColors
                        .textSecondary,

                fontSize: 11.5,

                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARREGAMENTO
// ============================================================

class _ServicesLoading
    extends StatelessWidget {
  const _ServicesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 18,
            ),

            Text(
              'Carregando serviços...',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SEM SERVIÇOS
// ============================================================

class _EmptyServices
    extends StatelessWidget {
  const _EmptyServices();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width: 86,
              height: 86,

              decoration:
                  const BoxDecoration(
                color:
                    AppColors
                        .goldSoft,

                shape:
                    BoxShape.circle,
              ),

              child:
                  const Icon(
                Icons
                    .content_cut_outlined,

                size: 40,

                color:
                    AppColors
                        .goldDark,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Nenhum serviço disponível',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize: 21,

                fontWeight:
                    FontWeight
                        .w800,
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              'No momento não há serviços '
              'disponíveis para agendamento.',

              textAlign:
                  TextAlign.center,

              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color:
                            AppColors
                                .textSecondary,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERRO
// ============================================================

class _ServicesError
    extends StatelessWidget {
  const _ServicesError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Container(
              width: 82,
              height: 82,

              decoration:
                  const BoxDecoration(
                color:
                    AppColors
                        .errorSoft,

                shape:
                    BoxShape.circle,
              ),

              child:
                  const Icon(
                Icons
                    .wifi_off_rounded,

                size: 36,

                color:
                    AppColors
                        .error,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Não foi possível carregar os serviços',

              textAlign:
                  TextAlign.center,

              style:
                  TextStyle(
                fontSize: 20,

                fontWeight:
                    FontWeight
                        .w800,
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              'Verifique sua conexão e '
              'tente novamente em alguns instantes.',

              textAlign:
                  TextAlign.center,

              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color:
                            AppColors
                                .textSecondary,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}