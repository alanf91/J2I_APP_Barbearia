import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/date_selection_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/professionals/data/repositories/professional_repository.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class ProfessionalSelectionPage extends StatefulWidget {
  final BarbershopService service;

  const ProfessionalSelectionPage({
    super.key,
    required this.service,
  });

  @override
  State<ProfessionalSelectionPage> createState() =>
      _ProfessionalSelectionPageState();
}

class _ProfessionalSelectionPageState
    extends State<ProfessionalSelectionPage> {
  final ProfessionalRepository _repository =
      ProfessionalRepository();

  Professional? _selectedProfessional;

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
  // SELECIONAR PROFISSIONAL
  // ============================================================

  void _selectProfessional(
    Professional professional,
  ) {
    setState(() {
      _selectedProfessional =
          professional;
    });
  }

  // ============================================================
  // CONTINUAR
  // ============================================================

  void _continue() {
    final professional =
        _selectedProfessional;

    if (professional == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) =>
                DateSelectionPage(
          service: widget.service,
          professional: professional,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Escolha o profissional',
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // ===================================================
            // SERVIÇO SELECIONADO
            // ===================================================

            _SelectedServiceCard(
              service:
                  widget.service,

              formattedPrice:
                  _formatPrice(
                widget
                    .service
                    .priceCents,
              ),
            ),

            // ===================================================
            // LISTA DE PROFISSIONAIS
            // ===================================================

            Expanded(
              child:
                  StreamBuilder<
                      List<Professional>>(
                stream:
                    _repository
                        .watchActiveProfessionalsForService(
                  widget.service.id,
                ),

                builder:
                    (
                      context,
                      snapshot,
                    ) {
                  if (
                    snapshot
                            .connectionState ==
                        ConnectionState
                            .waiting
                  ) {
                    return const _ProfessionalsLoading();
                  }

                  if (snapshot.hasError) {
                    debugPrint(
                      'PROFESSIONALS ERROR -> '
                      '${snapshot.error}',
                    );

                    return const _ProfessionalsError();
                  }

                  final professionals =
                      snapshot.data ??
                      [];

                  if (
                    professionals
                        .isEmpty
                  ) {
                    return const _EmptyProfessionals();
                  }

                  return ListView(
                    padding:
                        const EdgeInsets
                            .fromLTRB(
                      18,
                      16,
                      18,
                      30,
                    ),

                    children: [
                      // ===========================================
                      // CABEÇALHO
                      // ===========================================

                      const _ProfessionalsHeader(),

                      const SizedBox(
                        height: 22,
                      ),

                      // ===========================================
                      // QUANTIDADE
                      // ===========================================

                      Row(
                        children: [
                          Text(
                            'Disponíveis para este serviço',

                            style:
                                Theme.of(
                              context,
                            )
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontSize:
                                          15,

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
                              horizontal:
                                  10,
                              vertical:
                                  5,
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
                              '${professionals.length} '
                              '${professionals.length == 1 ? 'profissional' : 'profissionais'}',

                              style:
                                  const TextStyle(
                                color:
                                    AppColors
                                        .goldDark,

                                fontSize:
                                    10.5,

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

                      // ===========================================
                      // CARDS
                      // ===========================================

                      ...professionals.map(
                        (
                          professional,
                        ) {
                          final selected =
                              _selectedProfessional
                                      ?.id ==
                                  professional
                                      .id;

                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom:
                                  13,
                            ),

                            child:
                                _ProfessionalCard(
                              professional:
                                  professional,

                              selected:
                                  selected,

                              onTap:
                                  () {
                                _selectProfessional(
                                  professional,
                                );
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const _SelectionTip(),
                    ],
                  );
                },
              ),
            ),

            // ===================================================
            // BOTÃO CONTINUAR
            // ===================================================

            _BottomContinueButton(
              professional:
                  _selectedProfessional,

              onPressed:
                  _continue,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SERVIÇO SELECIONADO
// ============================================================

class _SelectedServiceCard
    extends StatelessWidget {
  final BarbershopService service;
  final String formattedPrice;

  const _SelectedServiceCard({
    required this.service,
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,

      margin:
          const EdgeInsets
              .fromLTRB(
        18,
        10,
        18,
        0,
      ),

      padding:
          const EdgeInsets.all(
        16,
      ),

      decoration:
          BoxDecoration(
        color:
            AppColors.black,

        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),

      child: Row(
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
                14,
              ),
            ),

            child:
                const Icon(
              Icons
                  .content_cut_rounded,

              color:
                  AppColors.black,

              size:
                  24,
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
                  'SERVIÇO ESCOLHIDO',

                  style:
                      TextStyle(
                    color:
                        AppColors.gold,

                    fontSize:
                        10,

                    fontWeight:
                        FontWeight
                            .w800,

                    letterSpacing:
                        0.8,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  service.name,

                  maxLines: 1,

                  overflow:
                      TextOverflow
                          .ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white,

                    fontSize:
                        16,

                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 4,

                  children: [
                    _ServiceInfoPill(
                      icon:
                          Icons
                              .schedule_rounded,

                      text:
                          '${service.durationMinutes} min',
                    ),

                    _ServiceInfoPill(
                      icon:
                          Icons
                              .payments_outlined,

                      text:
                          formattedPrice,
                    ),
                  ],
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
// INFORMAÇÃO DO SERVIÇO
// ============================================================

class _ServiceInfoPill
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ServiceInfoPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        Icon(
          icon,

          size: 14,

          color:
              const Color(
            0xFFD0CCC6,
          ),
        ),

        const SizedBox(
          width: 4,
        ),

        Text(
          text,

          style:
              const TextStyle(
            color:
                Color(
              0xFFD0CCC6,
            ),

            fontSize: 11,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// CABEÇALHO
// ============================================================

class _ProfessionalsHeader
    extends StatelessWidget {
  const _ProfessionalsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          'Quem vai cuidar de você?',

          style:
              Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontSize: 24,

                    fontWeight:
                        FontWeight
                            .w800,

                    letterSpacing:
                        -0.5,
                  ),
        ),

        const SizedBox(
          height: 7,
        ),

        Text(
          'Escolha o profissional de sua '
          'preferência para realizar o atendimento.',

          style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppColors
                            .textSecondary,

                    fontSize: 13.5,

                    height: 1.4,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// CARD DO PROFISSIONAL
// ============================================================

class _ProfessionalCard
    extends StatelessWidget {
  final Professional professional;
  final bool selected;
  final VoidCallback onTap;

  const _ProfessionalCard({
    required this.professional,
    required this.selected,
    required this.onTap,
  });

  String get _initial {
    final name =
        professional.name
            .trim();

    if (name.isEmpty) {
      return '?';
    }

    return name
        .substring(
          0,
          1,
        )
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final specialty =
        professional.specialty
            .trim();

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 180,
      ),

      decoration:
          BoxDecoration(
        color:
            selected
                ? AppColors
                    .goldSoft
                : AppColors
                    .surface,

        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border:
            Border.all(
          color:
              selected
                  ? AppColors.gold
                  : AppColors
                      .border,

          width:
              selected
                  ? 1.6
                  : 1,
        ),
      ),

      child: Material(
        color:
            Colors.transparent,

        child: InkWell(
          onTap:
              onTap,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          child: Padding(
            padding:
                const EdgeInsets
                    .all(
              16,
            ),

            child: Row(
              children: [
                // ===============================================
                // AVATAR
                // ===============================================

                Container(
                  width: 58,
                  height: 58,

                  decoration:
                      BoxDecoration(
                    color:
                        selected
                            ? AppColors
                                .black
                            : AppColors
                                .surfaceSecondary,

                    borderRadius:
                        BorderRadius
                            .circular(
                      18,
                    ),
                  ),

                  alignment:
                      Alignment.center,

                  child: Text(
                    _initial,

                    style:
                        TextStyle(
                      color:
                          selected
                              ? AppColors
                                  .gold
                              : AppColors
                                  .textPrimary,

                      fontSize: 22,

                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 14,
                ),

                // ===============================================
                // DADOS
                // ===============================================

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Text(
                        professional.name,

                        maxLines: 1,

                        overflow:
                            TextOverflow
                                .ellipsis,

                        style:
                            const TextStyle(
                          color:
                              AppColors
                                  .textPrimary,

                          fontSize: 16,

                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      if (
                        specialty
                            .isNotEmpty
                      ) ...[
                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          specialty,

                          maxLines: 1,

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
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 9,
                      ),

                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,

                            decoration:
                                const BoxDecoration(
                              color:
                                  AppColors
                                      .success,

                              shape:
                                  BoxShape
                                      .circle,
                            ),
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          const Text(
                            'Disponível para este serviço',

                            style:
                                TextStyle(
                              color:
                                  AppColors
                                      .success,

                              fontSize:
                                  10.5,

                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                // ===============================================
                // SELEÇÃO
                // ===============================================

                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds:
                        180,
                  ),

                  width: 34,
                  height: 34,

                  decoration:
                      BoxDecoration(
                    color:
                        selected
                            ? AppColors
                                .black
                            : AppColors
                                .surface,

                    shape:
                        BoxShape
                            .circle,

                    border:
                        Border.all(
                      color:
                          selected
                              ? AppColors
                                  .black
                              : AppColors
                                  .border,
                    ),
                  ),

                  child:
                      Icon(
                    selected
                        ? Icons
                            .check_rounded
                        : Icons
                            .add_rounded,

                    size: 19,

                    color:
                        selected
                            ? AppColors
                                .gold
                            : AppColors
                                .textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DICA DE SELEÇÃO
// ============================================================

class _SelectionTip
    extends StatelessWidget {
  const _SelectionTip();

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
            AppColors
                .surfaceSecondary,

        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),

      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            Icons
                .touch_app_outlined,

            color:
                AppColors.goldDark,

            size: 20,
          ),

          SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              'Toque em um profissional para '
              'selecioná-lo. Na próxima etapa '
              'você poderá escolher a data e o horário.',

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
// BOTÃO INFERIOR
// ============================================================

class _BottomContinueButton
    extends StatelessWidget {
  final Professional? professional;
  final VoidCallback onPressed;

  const _BottomContinueButton({
    required this.professional,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final selected =
        professional != null;

    return SafeArea(
      top: false,

      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          16,
        ),

        decoration:
            const BoxDecoration(
          color:
              AppColors.background,

          border:
              Border(
            top:
                BorderSide(
              color:
                  AppColors.border,
            ),
          ),
        ),

        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            if (selected) ...[
              Row(
                children: [
                  const Icon(
                    Icons
                        .check_circle_rounded,

                    color:
                        AppColors.success,

                    size: 18,
                  ),

                  const SizedBox(
                    width: 7,
                  ),

                  Expanded(
                    child: Text(
                      '${professional!.name} selecionado',

                      maxLines: 1,

                      overflow:
                          TextOverflow
                              .ellipsis,

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
                  ),
                ],
              ),

              const SizedBox(
                height: 10,
              ),
            ],

            SizedBox(
              width:
                  double.infinity,

              height:
                  54,

              child: FilledButton(
                onPressed:
                    selected
                        ? onPressed
                        : null,

                style:
                    ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty
                          .resolveWith(
                    (
                      states,
                    ) {
                      if (
                        states.contains(
                          WidgetState
                              .disabled,
                        )
                      ) {
                        return AppColors
                            .surfaceSecondary;
                      }

                      return AppColors
                          .black;
                    },
                  ),

                  foregroundColor:
                      WidgetStateProperty
                          .resolveWith(
                    (
                      states,
                    ) {
                      if (
                        states.contains(
                          WidgetState
                              .disabled,
                        )
                      ) {
                        return AppColors
                            .textSecondary;
                      }

                      return Colors.white;
                    },
                  ),
                ),

                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,

                  children: [
                    Text(
                      selected
                          ? 'ESCOLHER DATA E HORÁRIO'
                          : 'ESCOLHA UM PROFISSIONAL',

                      style:
                          const TextStyle(
                        fontSize: 12.5,

                        fontWeight:
                            FontWeight
                                .w800,

                        letterSpacing:
                            0.3,
                      ),
                    ),

                    if (selected) ...[
                      const SizedBox(
                        width: 8,
                      ),

                      const Icon(
                        Icons
                            .arrow_forward_rounded,

                        size: 18,

                        color:
                            AppColors.gold,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _ProfessionalsLoading
    extends StatelessWidget {
  const _ProfessionalsLoading();

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
              'Buscando profissionais...',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SEM PROFISSIONAIS
// ============================================================

class _EmptyProfessionals
    extends StatelessWidget {
  const _EmptyProfessionals();

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
              width: 84,
              height: 84,

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
                    .person_search_outlined,

                size: 38,

                color:
                    AppColors
                        .goldDark,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Nenhum profissional disponível',

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
              height: 8,
            ),

            Text(
              'Ainda não há profissionais '
              'disponíveis para realizar '
              'este serviço.',

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

class _ProfessionalsError
    extends StatelessWidget {
  const _ProfessionalsError();

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
                    .error_outline_rounded,

                size: 38,

                color:
                    AppColors
                        .error,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Não foi possível carregar os profissionais',

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
              height: 8,
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