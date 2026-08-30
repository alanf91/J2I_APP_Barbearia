import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:j2i_app_barbearia/features/payments/data/models/pix_payment_result.dart';
import 'package:j2i_app_barbearia/features/payments/data/repositories/pix_payment_repository.dart';
import 'package:j2i_app_barbearia/features/payments/data/services/mercado_pago_native_bridge.dart';

class PixPaymentPage extends StatefulWidget {
  final String appointmentId;

  const PixPaymentPage({
    super.key,
    required this.appointmentId,
  });

  @override
  State<PixPaymentPage> createState() =>
      _PixPaymentPageState();
}

class _PixPaymentPageState
    extends State<PixPaymentPage> {
  final PixPaymentRepository _repository =
      PixPaymentRepository();

  bool _isLoading = false;

  PixPaymentResult? _payment;

  String? _errorMessage;

  Timer? _countdownTimer;

  Timer? _statusTimer;

  int _remainingSeconds = 0;

  bool _reservationExpired = false;

  bool _silentRefreshInProgress = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _loadPix();
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();

    _statusTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // CARREGAR / RECUPERAR PIX
  // ============================================================

  Future<void> _loadPix() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payment =
          await _repository.createPix(
        appointmentId:
            widget.appointmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = payment;
        _isLoading = false;
        _errorMessage = null;
      });

      _startPaymentTimers(
        payment,
      );
    } on PixPaymentException catch (e) {
      _countdownTimer?.cancel();
      _statusTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _payment = null;
        _errorMessage = e.message;
      });
    } catch (_) {
      _countdownTimer?.cancel();
      _statusTimer?.cancel();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _payment = null;

        _errorMessage =
            'Não foi possível carregar '
            'o pagamento Pix.';
      });
    }
  }

  // ============================================================
  // INICIAR CONTADORES
  // ============================================================

  void _startPaymentTimers(
    PixPaymentResult payment,
  ) {
    _countdownTimer?.cancel();

    _statusTimer?.cancel();

    _startReservationCountdown(
      payment,
    );

    if (
      payment.approved ||
      _reservationExpired
    ) {
      return;
    }

    // Consulta silenciosamente a MESMA Order.
    // Não cria novo Pix.
    _statusTimer =
        Timer.periodic(
      const Duration(
        seconds: 8,
      ),
      (_) {
        _refreshPaymentStatusSilently();
      },
    );
  }

  // ============================================================
  // ATUALIZAR STATUS SEM PISCAR A TELA
  // ============================================================

  Future<void>
      _refreshPaymentStatusSilently() async {
    if (
      _silentRefreshInProgress ||
      _reservationExpired ||
      _payment?.approved == true
    ) {
      return;
    }

    _silentRefreshInProgress =
        true;

    try {
      final refreshed =
          await _repository.createPix(
        appointmentId:
            widget.appointmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = refreshed;
      });

      if (refreshed.approved) {
        _countdownTimer?.cancel();
        _statusTimer?.cancel();

        setState(() {
          _reservationExpired =
              false;

          _remainingSeconds =
              0;
        });
      }
    } on PixPaymentException {
      // Falha momentânea de consulta:
      // mantém a tela funcionando.
    } catch (_) {
      // Polling silencioso.
    } finally {
      _silentRefreshInProgress =
          false;
    }
  }

  // ============================================================
  // CONTAGEM REGRESSIVA
  // ============================================================

  void _startReservationCountdown(
    PixPaymentResult payment,
  ) {
    _countdownTimer?.cancel();

    if (payment.approved) {
      if (!mounted) {
        return;
      }

      setState(() {
        _remainingSeconds = 0;
        _reservationExpired = false;
      });

      return;
    }

    final expiresAtMs =
        payment.reservationExpiresAtMs;

    if (expiresAtMs == null) {
      return;
    }

    void updateCountdown() {
      final nowMs =
          DateTime.now()
              .millisecondsSinceEpoch;

      final remainingMs =
          expiresAtMs -
          nowMs;

      final seconds =
          remainingMs <= 0
              ? 0
              : (
                  remainingMs /
                  1000
                ).ceil();

      if (!mounted) {
        return;
      }

      if (seconds <= 0) {
        _countdownTimer
            ?.cancel();

        _statusTimer
            ?.cancel();

        setState(() {
          _remainingSeconds =
              0;

          _reservationExpired =
              true;
        });

        return;
      }

      setState(() {
        _remainingSeconds =
            seconds;

        _reservationExpired =
            false;
      });
    }

    updateCountdown();

    if (_reservationExpired) {
      return;
    }

    _countdownTimer =
        Timer.periodic(
      const Duration(
        seconds: 1,
      ),
      (_) {
        updateCountdown();
      },
    );
  }

  // ============================================================
  // COPIAR PIX
  // ============================================================

  Future<void> _copyPix() async {
    final payment =
        _payment;

    if (
      payment == null ||
      payment.qrCode
          .trim()
          .isEmpty ||
      _reservationExpired
    ) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text:
            payment.qrCode,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          'Código Pix copiado.',
        ),
      ),
    );
  }

  Future<void>
      _testMercadoPagoAndroid() async {
    final ready =
        await MercadoPagoNativeBridge
            .isReady();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          ready
              ? 'Mercado Pago Android: OK'
              : 'Mercado Pago Android: NÃO INICIALIZADO',
        ),
      ),
    );
  }

  String _formatAmount(
    String value,
  ) {
    final number =
        double.tryParse(
      value,
    );

    if (number == null) {
      return value;
    }

    return 'R\$ '
        '${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _statusText(
    PixPaymentResult payment,
  ) {
    if (
      payment.approved ||
      (
        payment.status ==
            'processed' &&
        payment.statusDetail ==
            'accredited'
      )
    ) {
      return 'Pagamento aprovado';
    }

    if (
      payment.status ==
          'action_required' &&
      payment.statusDetail ==
          'waiting_transfer'
    ) {
      return 'Aguardando pagamento';
    }

    if (
      payment.statusDetail
          .isNotEmpty
    ) {
      return payment.statusDetail;
    }

    if (
      payment.status
          .isNotEmpty
    ) {
      return payment.status;
    }

    return 'Aguardando pagamento';
  }

  String get _countdownText {
    final minutes =
        _remainingSeconds ~/
        60;

    final seconds =
        _remainingSeconds %
        60;

    return
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final payment =
        _payment;

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          'Pagamento Pix',
        ),
      ),

      body:
          SafeArea(
        child:
            ListView(
          padding:
              const EdgeInsets
                  .all(
            20,
          ),

          children: [
            const SizedBox(
              height: 10,
            ),

            const Icon(
              Icons.pix,
              size: 68,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Finalize seu pagamento',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    25,
                fontWeight:
                    FontWeight
                        .bold,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Seu horário fica reservado por até '
              '2 minutos enquanto você realiza '
              'o pagamento.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height: 26,
            ),

            if (_isLoading)
              _buildLoading(),

            if (
              !_isLoading &&
              _errorMessage !=
                  null
            )
              _buildError(),

            if (
              !_isLoading &&
              payment != null
            )
              _buildPayment(
                payment,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 50,
      ),
      child:
          Column(
        children: [
          CircularProgressIndicator(),

          SizedBox(
            height: 18,
          ),

          Text(
            'Buscando pagamento Pix...',
            textAlign:
                TextAlign.center,
          ),

          SizedBox(
            height: 8,
          ),

          Text(
            'Se já existir um Pix para este '
            'agendamento, o mesmo QR Code '
            'será recuperado.',
            textAlign:
                TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,

      children: [
        Container(
          padding:
              const EdgeInsets
                  .all(
            16,
          ),

          decoration:
              BoxDecoration(
            color:
                Theme.of(
              context,
            )
                    .colorScheme
                    .errorContainer,

            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),

          child:
              Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,

            children: [
              Icon(
                Icons
                    .error_outline,

                color:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .onErrorContainer,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child:
                    Text(
                  _errorMessage!,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        FilledButton.icon(
          onPressed:
              _loadPix,

          icon:
              const Icon(
            Icons.refresh,
          ),

          label:
              const Text(
            'TENTAR NOVAMENTE',
          ),
        ),
      ],
    );
  }

  Widget _buildPayment(
    PixPaymentResult payment,
  ) {
    if (payment.approved) {
      return _buildApprovedPayment(
        payment,
      );
    }

    if (_reservationExpired) {
      return _buildExpiredPayment();
    }

    final qrCode =
        payment.qrCode.trim();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,

      children: [
        // ======================================================
        // CONTADOR
        // ======================================================

        Container(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 18,
            vertical: 16,
          ),

          decoration:
              BoxDecoration(
            color:
                Theme.of(
              context,
            )
                    .colorScheme
                    .primaryContainer,

            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),

          child:
              Column(
            children: [
              Text(
                'Seu horário está reservado por',
                textAlign:
                    TextAlign
                        .center,
                style:
                    TextStyle(
                  color:
                      Theme.of(
                    context,
                  )
                          .colorScheme
                          .onPrimaryContainer,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                _countdownText,
                style:
                    TextStyle(
                  fontSize:
                      34,
                  fontWeight:
                      FontWeight
                          .w800,
                  letterSpacing:
                      1.5,
                  color:
                      Theme.of(
                    context,
                  )
                          .colorScheme
                          .onPrimaryContainer,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Após esse tempo, o Pix é encerrado '
                'e o horário volta a ficar disponível.',
                textAlign:
                    TextAlign
                        .center,
                style:
                    TextStyle(
                  fontSize:
                      12,
                  color:
                      Theme.of(
                    context,
                  )
                          .colorScheme
                          .onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height: 20,
        ),

        if (payment.testMode) ...[
          Container(
            padding:
                const EdgeInsets
                    .all(
              12,
            ),

            decoration:
                BoxDecoration(
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .secondaryContainer,

              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),

            child:
                const Row(
              children: [
                Icon(
                  Icons
                      .science_outlined,
                ),

                SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      Text(
                    'Ambiente de teste. '
                    'Nenhum dinheiro real será movimentado.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 20,
          ),
        ],

        const Text(
          'Valor do Pix',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 4,
        ),

        Text(
          _formatAmount(
            payment.amount,
          ),
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            fontSize: 30,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Text(
          _statusText(
            payment,
          ),
          textAlign:
              TextAlign.center,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        if (qrCode.isNotEmpty)
          Center(
            child:
                Container(
              padding:
                  const EdgeInsets
                      .all(
                16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,

                borderRadius:
                    BorderRadius
                        .circular(
                  18,
                ),

                boxShadow:
                    const [
                  BoxShadow(
                    blurRadius:
                        18,
                    spreadRadius:
                        1,
                    offset:
                        Offset(
                      0,
                      6,
                    ),
                    color:
                        Color(
                      0x1A000000,
                    ),
                  ),
                ],
              ),

              child:
                  QrImageView(
                data:
                    qrCode,

                version:
                    QrVersions.auto,

                size:
                    240,

                backgroundColor:
                    Colors.white,

                errorStateBuilder:
                    (
                  context,
                  error,
                ) {
                  return const SizedBox(
                    width: 240,
                    height: 240,
                    child:
                        Center(
                      child:
                          Text(
                        'Não foi possível desenhar o QR Code.',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        else
          Container(
            padding:
                const EdgeInsets
                    .all(
              16,
            ),

            decoration:
                BoxDecoration(
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .errorContainer,

              borderRadius:
                  BorderRadius
                      .circular(
                12,
              ),
            ),

            child:
                const Text(
              'O Mercado Pago não retornou '
              'o código Pix desta cobrança.',
              textAlign:
                  TextAlign
                      .center,
            ),
          ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Pix Copia e Cola',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 8,
        ),

        Container(
          padding:
              const EdgeInsets
                  .all(
            12,
          ),

          decoration:
              BoxDecoration(
            border:
                Border.all(
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .outlineVariant,
            ),

            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),

          child:
              SelectableText(
            qrCode,
            maxLines: 4,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        SizedBox(
          height: 52,

          child:
              FilledButton.icon(
            onPressed:
                qrCode.isEmpty
                    ? null
                    : _copyPix,

            icon:
                const Icon(
              Icons.copy,
            ),

            label:
                const Text(
              'COPIAR PIX',
            ),
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        OutlinedButton.icon(
          onPressed:
              _isLoading
                  ? null
                  : _loadPix,

          icon:
              const Icon(
            Icons.refresh,
          ),

          label:
              const Text(
            'ATUALIZAR PAGAMENTO',
          ),
        ),

        const SizedBox(
          height: 24,
        ),

        if (payment.testMode)
          ExpansionTile(
            title:
                const Text(
              'Dados do teste',
            ),

            childrenPadding:
                const EdgeInsets
                    .only(
              left: 16,
              right: 16,
              bottom: 16,
            ),

            children: [
              _InfoRow(
                label:
                    'Order ID',
                value:
                    payment.orderId,
              ),

              _InfoRow(
                label:
                    'Payment ID',
                value:
                    payment.paymentId,
              ),

              _InfoRow(
                label:
                    'Status',
                value:
                    payment.status,
              ),

              _InfoRow(
                label:
                    'Status detail',
                value:
                    payment
                        .statusDetail,
              ),

              _InfoRow(
                label:
                    'Valor real',
                value:
                    _formatAmount(
                  payment
                      .realAppointmentAmount,
                ),
              ),

              _InfoRow(
                label:
                    'Reutilizado',
                value:
                    payment.reused
                        ? 'Sim'
                        : 'Não',
              ),
            ],
          ),

        if (payment.testMode) ...[
          const SizedBox(
            height: 16,
          ),

          OutlinedButton.icon(
            onPressed:
                _testMercadoPagoAndroid,

            icon:
                const Icon(
              Icons.credit_card,
            ),

            label:
                const Text(
              'TESTAR MERCADO PAGO ANDROID',
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // PAGAMENTO APROVADO
  // ============================================================

  Widget _buildApprovedPayment(
    PixPaymentResult payment,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        24,
      ),

      decoration:
          BoxDecoration(
        color:
            Theme.of(
          context,
        )
                .colorScheme
                .primaryContainer,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child:
          Column(
        children: [
          Icon(
            Icons
                .check_circle_outline,
            size: 58,
            color:
                Theme.of(
              context,
            )
                    .colorScheme
                    .onPrimaryContainer,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            'Pagamento aprovado',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .onPrimaryContainer,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            _formatAmount(
              payment.amount,
            ),
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.w800,
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .onPrimaryContainer,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Recebemos a confirmação do Mercado Pago. '
            'O agendamento será finalizado '
            'automaticamente pelo sistema.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESERVA EXPIRADA
  // ============================================================

  Widget _buildExpiredPayment() {
    return Container(
      padding:
          const EdgeInsets.all(
        22,
      ),

      decoration:
          BoxDecoration(
        color:
            Theme.of(
          context,
        )
                .colorScheme
                .errorContainer,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child:
          Column(
        children: [
          Icon(
            Icons
                .timer_off_outlined,
            size: 52,
            color:
                Theme.of(
              context,
            )
                    .colorScheme
                    .onErrorContainer,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            'Reserva expirada',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .onErrorContainer,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'O prazo de 2 minutos terminou. '
            'O QR Code foi ocultado e o horário '
            'poderá voltar a ficar disponível.',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              color:
                  Theme.of(
                context,
              )
                      .colorScheme
                      .onErrorContainer,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 50,

            child:
                FilledButton.icon(
              onPressed:
                  () {
                Navigator.of(
                  context,
                ).pop();
              },

              icon:
                  const Icon(
                Icons.arrow_back,
              ),

              label:
                  const Text(
                'VOLTAR',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  final String label;

  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 8,
      ),

      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 120,

            child:
                Text(
              '$label:',

              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child:
                SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }
}