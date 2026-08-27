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
  State<PixPaymentPage> createState() => _PixPaymentPageState();
}

class _PixPaymentPageState extends State<PixPaymentPage> {
  final PixPaymentRepository _repository =
      PixPaymentRepository();

  bool _isLoading = false;

  PixPaymentResult? _payment;

  String? _errorMessage;

  // ============================================================
  // INIT
  // ============================================================
  //
  // Ao abrir esta tela:
  //
  // 1. Se ainda não existe Pix:
  //    backend cria o Pix.
  //
  // 2. Se já existe Pix pendente:
  //    backend recupera a MESMA Order.
  //
  // 3. Se a reserva expirou:
  //    backend retorna APPOINTMENT_EXPIRED.
  //
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _loadPix();
      },
    );
  }

  // ============================================================
  // CARREGAR / GERAR PIX
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
    } on PixPaymentException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _payment = null;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _payment = null;
        _errorMessage =
            'Não foi possível carregar o pagamento Pix.';
      });
    }
  }

  // ============================================================
  // COPIAR PIX
  // ============================================================

  Future<void> _copyPix() async {
    final payment = _payment;

    if (
      payment == null ||
      payment.qrCode.trim().isEmpty
    ) {
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: payment.qrCode,
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Código Pix copiado.',
        ),
      ),
    );
  }

  // ============================================================
  // TESTE TEMPORÁRIO - MERCADO PAGO ANDROID
  // ============================================================

  Future<void> _testMercadoPagoAndroid() async {
    final ready =
        await MercadoPagoNativeBridge.isReady();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ready
              ? 'Mercado Pago Android: OK'
              : 'Mercado Pago Android: NÃO INICIALIZADO',
        ),
      ),
    );
  }

  // ============================================================
  // FORMATAR VALOR
  // ============================================================

  String _formatAmount(
    String value,
  ) {
    final number =
        double.tryParse(value);

    if (number == null) {
      return value;
    }

    return 'R\$ '
        '${number.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _statusText(
    PixPaymentResult payment,
  ) {
    if (
      payment.status == 'action_required' &&
      payment.statusDetail == 'waiting_transfer'
    ) {
      return 'Aguardando pagamento';
    }

    if (
      payment.status == 'processed' &&
      payment.statusDetail == 'accredited'
    ) {
      return 'Pagamento aprovado';
    }

    if (
      payment.statusDetail.isNotEmpty
    ) {
      return payment.statusDetail;
    }

    if (
      payment.status.isNotEmpty
    ) {
      return payment.status;
    }

    return 'Aguardando pagamento';
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
      appBar: AppBar(
        title:
            const Text(
          'Pagamento Pix',
        ),
      ),

      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(20),

          children: [
            const SizedBox(height: 10),

            const Icon(
              Icons.pix,
              size: 72,
            ),

            const SizedBox(height: 18),

            const Text(
              'Pague com Pix',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Escaneie o QR Code ou copie '
              'o código Pix para concluir '
              'o pagamento.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(height: 28),

            // ==================================================
            // CARREGANDO
            // ==================================================

            if (_isLoading)
              _buildLoading(),

            // ==================================================
            // ERRO
            // ==================================================

            if (
              !_isLoading &&
              _errorMessage != null
            )
              _buildError(),

            // ==================================================
            // PAGAMENTO
            // ==================================================

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

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 50,
      ),

      child: Column(
        children: [
          CircularProgressIndicator(),

          SizedBox(height: 18),

          Text(
            'Buscando pagamento Pix...',
            textAlign:
                TextAlign.center,
          ),

          SizedBox(height: 8),

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

  // ============================================================
  // ERRO
  // ============================================================

  Widget _buildError() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        Container(
          padding:
              const EdgeInsets.all(16),

          decoration:
              BoxDecoration(
            color:
                Theme.of(context)
                    .colorScheme
                    .errorContainer,

            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),

          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Icon(
                Icons.error_outline,

                color:
                    Theme.of(context)
                        .colorScheme
                        .onErrorContainer,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _errorMessage!,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

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

  // ============================================================
  // PAGAMENTO GERADO / RECUPERADO
  // ============================================================

  Widget _buildPayment(
    PixPaymentResult payment,
  ) {
    final qrCode =
        payment.qrCode.trim();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,

      children: [
        // ======================================================
        // AMBIENTE DE TESTE
        // ======================================================

        if (payment.testMode) ...[
          Container(
            padding:
                const EdgeInsets.all(12),

            decoration:
                BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .secondaryContainer,

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                const Row(
              children: [
                Icon(
                  Icons.science_outlined,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Ambiente de teste. '
                    'Nenhum dinheiro real '
                    'será movimentado.',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],

        // ======================================================
        // VALOR
        // ======================================================

        const Text(
          'Valor do Pix',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(height: 4),

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

        const SizedBox(height: 8),

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

        const SizedBox(height: 24),

        // ======================================================
        // QR CODE
        //
        // IMPORTANTE:
        //
        // O QR é desenhado a partir do "Pix Copia e Cola".
        // Não dependemos mais de qrCodeBase64.
        // ======================================================

        if (qrCode.isNotEmpty)
          Center(
            child: Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child: QrImageView(
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

                    child: Center(
                      child: Text(
                        'Não foi possível '
                        'desenhar o QR Code.',
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
                const EdgeInsets.all(
              16,
            ),

            decoration:
                BoxDecoration(
              color:
                  Theme.of(context)
                      .colorScheme
                      .errorContainer,

              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),

            child:
                const Text(
              'O Mercado Pago não retornou '
              'o código Pix desta cobrança.',
              textAlign:
                  TextAlign.center,
            ),
          ),

        const SizedBox(height: 24),

        // ======================================================
        // PIX COPIA E COLA
        // ======================================================

        const Text(
          'Pix Copia e Cola',

          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding:
              const EdgeInsets.all(
            12,
          ),

          decoration:
              BoxDecoration(
            border:
                Border.all(
              color:
                  Theme.of(context)
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

            maxLines:
                4,
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height:
              52,

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

        const SizedBox(height: 18),

        // ======================================================
        // RECARREGAR MESMO PIX
        // ======================================================

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

        const SizedBox(height: 26),

        // ======================================================
        // DADOS DE DESENVOLVIMENTO
        // ======================================================

        if (payment.testMode)
          ExpansionTile(
            title:
                const Text(
              'Dados do teste',
            ),

            childrenPadding:
                const EdgeInsets.only(
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
                    payment.statusDetail,
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
            ],
          ),

        // ======================================================
        // BOTÃO TEMPORÁRIO SDK ANDROID
        // Mantido para não remover funcionalidade existente.
        // ======================================================

        if (payment.testMode) ...[
          const SizedBox(height: 16),

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
}

// ============================================================
// LINHA DE INFORMAÇÃO
// ============================================================

class _InfoRow extends StatelessWidget {
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

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 120,

            child: Text(
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