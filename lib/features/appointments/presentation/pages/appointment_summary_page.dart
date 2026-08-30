import 'package:flutter/material.dart';

import 'package:j2i_app_barbearia/app/theme/app_theme.dart';
import 'package:j2i_app_barbearia/features/appointments/data/repositories/appointment_repository.dart';
import 'package:j2i_app_barbearia/features/appointments/presentation/pages/appointment_success_page.dart';
import 'package:j2i_app_barbearia/features/professionals/data/models/professional.dart';
import 'package:j2i_app_barbearia/features/services/data/models/barbershop_service.dart';

class AppointmentSummaryPage extends StatefulWidget {
  final BarbershopService service;
  final Professional professional;
  final DateTime date;
  final int startMinutes;

  const AppointmentSummaryPage({
    super.key,
    required this.service,
    required this.professional,
    required this.date,
    required this.startMinutes,
  });

  @override
  State<AppointmentSummaryPage> createState() =>
      _AppointmentSummaryPageState();
}

class _AppointmentSummaryPageState
    extends State<AppointmentSummaryPage> {
  final AppointmentRepository _appointmentRepository =
      AppointmentRepository();

  bool _isConfirming = false;

  // ============================================================
  // FORMATAR HORÁRIO
  // ============================================================

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // FORMATAR VALOR
  // ============================================================

  String _formatPrice(int priceCents) {
    final value = priceCents / 100;

    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // DIA DA SEMANA
  // ============================================================

  String _weekdayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'segunda-feira';

      case DateTime.tuesday:
        return 'terça-feira';

      case DateTime.wednesday:
        return 'quarta-feira';

      case DateTime.thursday:
        return 'quinta-feira';

      case DateTime.friday:
        return 'sexta-feira';

      case DateTime.saturday:
        return 'sábado';

      case DateTime.sunday:
        return 'domingo';

      default:
        return '';
    }
  }

  // ============================================================
  // NOME DO MÊS
  // ============================================================

  String _monthName(int month) {
    switch (month) {
      case 1:
        return 'janeiro';

      case 2:
        return 'fevereiro';

      case 3:
        return 'março';

      case 4:
        return 'abril';

      case 5:
        return 'maio';

      case 6:
        return 'junho';

      case 7:
        return 'julho';

      case 8:
        return 'agosto';

      case 9:
        return 'setembro';

      case 10:
        return 'outubro';

      case 11:
        return 'novembro';

      case 12:
        return 'dezembro';

      default:
        return '';
    }
  }

  // ============================================================
  // FORMATAR DATA
  // ============================================================

  String _formatDate(DateTime date) {
    return '${_weekdayName(date)}, '
        '${date.day} de '
        '${_monthName(date.month)} de '
        '${date.year}';
  }

  // ============================================================
  // CONFIRMAR / RESERVAR AGENDAMENTO
  // ============================================================

  Future<void> _confirmAppointment() async {
    if (_isConfirming) {
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // ========================================================
      // CRIAR AGENDAMENTO
      // ========================================================

      final appointmentId =
          await _appointmentRepository.createAppointment(
        service: widget.service,
        professional: widget.professional,
        date: widget.date,
        startMinutes: widget.startMinutes,
      );

      if (!mounted) {
        return;
      }

      // ========================================================
      // IR PARA PAGAMENTO
      //
      // O appointmentId gerado será usado no fluxo de pagamento.
      // ========================================================

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AppointmentSuccessPage(
            appointmentId: appointmentId,
          ),
        ),
      );
    } on AppointmentConflictException {
      if (!mounted) {
        return;
      }

      // ========================================================
      // OUTRO CLIENTE RESERVOU O HORÁRIO
      // ========================================================

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.goldSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                size: 31,
                color: AppColors.goldDark,
              ),
            ),
            title: const Text(
              'Horário indisponível',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Este horário acabou de ser reservado '
              'por outro cliente.\n\n'
              'Escolha outro horário disponível para continuar.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text(
                  'ESCOLHER OUTRO HORÁRIO',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) {
        return;
      }

      // Volta para a seleção de horário.
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint(
        'CREATE APPOINTMENT ERROR -> $e',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível reservar este horário. '
            'Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final endMinutes =
        widget.startMinutes +
        widget.service.durationMinutes;

    final formattedPrice =
        _formatPrice(
      widget.service.priceCents,
    );

    final formattedDate =
        _formatDate(
      widget.date,
    );

    final startTime =
        _formatTime(
      widget.startMinutes,
    );

    final endTime =
        _formatTime(
      endMinutes,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Revisar agendamento',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===================================================
            // CONTEÚDO
            // ===================================================

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  14,
                  18,
                  28,
                ),
                children: [
                  // ===============================================
                  // PROGRESSO
                  // ===============================================

                  const _BookingProgress(),

                  const SizedBox(
                    height: 24,
                  ),

                  // ===============================================
                  // CABEÇALHO
                  // ===============================================

                  const _Header(),

                  const SizedBox(
                    height: 24,
                  ),

                  // ===============================================
                  // RESUMO PRINCIPAL
                  // ===============================================

                  _AppointmentDetailsCard(
                    serviceName:
                        widget.service.name,
                    professionalName:
                        widget.professional.name,
                    professionalSpecialty:
                        widget.professional.specialty,
                    date:
                        formattedDate,
                    startTime:
                        startTime,
                    endTime:
                        endTime,
                    durationMinutes:
                        widget.service.durationMinutes,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // ===============================================
                  // VALOR
                  // ===============================================

                  _PriceCard(
                    formattedPrice:
                        formattedPrice,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // ===============================================
                  // RESERVA TEMPORÁRIA
                  // ===============================================

                  const _ReservationInfoCard(),

                  const SizedBox(
                    height: 18,
                  ),

                  // ===============================================
                  // SEGURANÇA
                  // ===============================================

                  const _SecurityInfoCard(),
                ],
              ),
            ),

            // ===================================================
            // AÇÕES
            // ===================================================

            _BottomActions(
              isConfirming:
                  _isConfirming,
              onConfirm:
                  _confirmAppointment,
              onBack: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROGRESSO DO AGENDAMENTO
// ============================================================

class _BookingProgress extends StatelessWidget {
  const _BookingProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        children: [
          _ProgressItem(
            label: 'Serviço',
          ),

          _ProgressLine(),

          _ProgressItem(
            label: 'Profissional',
          ),

          _ProgressLine(),

          _ProgressItem(
            label: 'Data',
          ),

          _ProgressLine(),

          _ProgressItem(
            label: 'Horário',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ITEM DO PROGRESSO
// ============================================================

class _ProgressItem extends StatelessWidget {
  final String label;

  const _ProgressItem({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration:
                const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.gold,
              size: 16,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            label,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize: 8.5,
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
// LINHA DO PROGRESSO
// ============================================================

class _ProgressLine extends StatelessWidget {
  const _ProgressLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 2,
      margin:
          const EdgeInsets.only(
        bottom: 19,
      ),
      color: AppColors.gold,
    );
  }
}

// ============================================================
// CABEÇALHO
// ============================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration:
              const BoxDecoration(
            color: AppColors.black,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons
                .event_available_rounded,
            color: AppColors.gold,
            size: 34,
          ),
        ),

        const SizedBox(
          height: 16,
        ),

        Text(
          'Está tudo certo?',
          textAlign: TextAlign.center,
          style:
              Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontSize: 25,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
        ),

        const SizedBox(
          height: 7,
        ),

        Text(
          'Revise os detalhes antes de reservar '
          'seu horário e seguir para o pagamento.',
          textAlign: TextAlign.center,
          style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
        ),
      ],
    );
  }
}

// ============================================================
// DETALHES DO AGENDAMENTO
// ============================================================

class _AppointmentDetailsCard
    extends StatelessWidget {
  final String serviceName;
  final String professionalName;
  final String professionalSpecialty;
  final String date;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  const _AppointmentDetailsCard({
    required this.serviceName,
    required this.professionalName,
    required this.professionalSpecialty,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: AppColors.black,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          // =====================================================
          // SERVIÇO
          // =====================================================

          _DarkSummaryRow(
            icon:
                Icons
                    .content_cut_rounded,
            label:
                'SERVIÇO',
            value:
                serviceName,
            subtitle:
                '$durationMinutes minutos',
            highlighted:
                true,
          ),

          const Divider(
            height: 28,
            color:
                AppColors.graphite,
          ),

          // =====================================================
          // PROFISSIONAL
          // =====================================================

          _DarkSummaryRow(
            icon:
                Icons
                    .person_outline_rounded,
            label:
                'PROFISSIONAL',
            value:
                professionalName,
            subtitle:
                professionalSpecialty
                        .trim()
                        .isEmpty
                    ? null
                    : professionalSpecialty,
          ),

          const Divider(
            height: 28,
            color:
                AppColors.graphite,
          ),

          // =====================================================
          // DATA
          // =====================================================

          _DarkSummaryRow(
            icon:
                Icons
                    .calendar_month_outlined,
            label:
                'DATA',
            value:
                date,
          ),

          const Divider(
            height: 28,
            color:
                AppColors.graphite,
          ),

          // =====================================================
          // HORÁRIO
          // =====================================================

          _DarkSummaryRow(
            icon:
                Icons
                    .schedule_rounded,
            label:
                'HORÁRIO',
            value:
                '$startTime às $endTime',
            subtitle:
                'Duração prevista: '
                '$durationMinutes min',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LINHA ESCURA
// ============================================================

class _DarkSummaryRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final bool highlighted;

  const _DarkSummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle =
        subtitle != null &&
        subtitle!.trim().isNotEmpty;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration:
              BoxDecoration(
            color:
                highlighted
                    ? AppColors.gold
                    : AppColors.graphite,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
          ),
          child: Icon(
            icon,
            color:
                highlighted
                    ? AppColors.black
                    : AppColors.gold,
            size: 22,
          ),
        ),

        const SizedBox(
          width: 13,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight:
                      FontWeight.w700,
                  height: 1.3,
                ),
              ),

              if (hasSubtitle) ...[
                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle!,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFFBDB9B3,
                    ),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 18,
        ),
      ],
    );
  }
}

// ============================================================
// VALOR
// ============================================================

class _PriceCard extends StatelessWidget {
  final String formattedPrice;

  const _PriceCard({
    required this.formattedPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color:
                  AppColors.goldSoft,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color:
                  AppColors.goldDark,
              size: 24,
            ),
          ),

          const SizedBox(
            width: 13,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'VALOR DO ATENDIMENTO',
                  style: TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),

                SizedBox(
                  height: 3,
                ),

                Text(
                  'Pagamento na próxima etapa',
                  style: TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Text(
            formattedPrice,
            style:
                const TextStyle(
              color:
                  AppColors.textPrimary,
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFORMAÇÃO DA RESERVA
// ============================================================

class _ReservationInfoCard
    extends StatelessWidget {
  const _ReservationInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius:
            BorderRadius.circular(17),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .timer_outlined,
            color:
                AppColors.goldDark,
            size: 22,
          ),

          SizedBox(
            width: 11,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Reserva temporária do horário',
                  style: TextStyle(
                    color:
                        AppColors
                            .textPrimary,
                    fontSize: 12.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'Ao continuar, o horário será reservado '
                  'temporariamente por 2 minutos enquanto '
                  'você realiza o pagamento.',
                  style: TextStyle(
                    color:
                        AppColors
                            .textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
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
// SEGURANÇA
// ============================================================

class _SecurityInfoCard
    extends StatelessWidget {
  const _SecurityInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surfaceSecondary,
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: const Row(
        children: [
          Icon(
            Icons
                .verified_user_outlined,
            color:
                AppColors.success,
            size: 20,
          ),

          SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              'Seu horário só será confirmado após '
              'a validação do pagamento.',
              style: TextStyle(
                color:
                    AppColors
                        .textSecondary,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// AÇÕES INFERIORES
// ============================================================

class _BottomActions extends StatelessWidget {
  final bool isConfirming;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _BottomActions({
    required this.isConfirming,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets.fromLTRB(
          18,
          12,
          18,
          14,
        ),
        decoration:
            const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(
              color: AppColors.border,
            ),
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            // ===================================================
            // CONFIRMAR
            // ===================================================

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed:
                    isConfirming
                        ? null
                        : onConfirm,
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    if (isConfirming)
                      const SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(
                        Icons
                            .lock_clock_outlined,
                        size: 19,
                      ),

                    const SizedBox(
                      width: 9,
                    ),

                    Text(
                      isConfirming
                          ? 'RESERVANDO HORÁRIO...'
                          : 'RESERVAR E IR PARA PAGAMENTO',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w800,
                        letterSpacing: 0.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 5,
            ),

            // ===================================================
            // ALTERAR HORÁRIO
            // ===================================================

            TextButton.icon(
              onPressed:
                  isConfirming
                      ? null
                      : onBack,
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
              ),
              label: const Text(
                'ALTERAR HORÁRIO',
              ),
            ),
          ],
        ),
      ),
    );
  }
}