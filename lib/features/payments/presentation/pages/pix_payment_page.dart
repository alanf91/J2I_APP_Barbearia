import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/payments/data/models/pix_payment_result.dart';
import 'package:j2i_app_barbearia/features/payments/data/repositories/pix_payment_repository.dart';

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
  final PixPaymentRepository _repository = PixPaymentRepository();

  bool _isLoading = false;

  PixPaymentResult? _payment;

  String? _errorMessage;

  // ============================================================
  // GERAR PIX
  // ============================================================

  Future<void> _generatePix() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payment = await _repository.createPix(
        appointmentId: widget.appointmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment = payment;
        _isLoading = false;
      });
    } on PixPaymentException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Não foi possível gerar o pagamento.';
      });
    }
  }

  // ============================================================
  // COPIAR PIX
  // ============================================================

  Future<void> _copyPix() async {
    final payment = _payment;

    if (payment == null || payment.qrCode.isEmpty) {
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
  // DECODIFICAR QR CODE
  // ============================================================

  Uint8List? _decodeQrCodeImage(
    String value,
  ) {
    if (value.trim().isEmpty) {
      return null;
    }

    try {
      var normalized = value.trim();

      if (normalized.contains(',')) {
        normalized = normalized.split(',').last;
      }

      return base64Decode(
        normalized,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // FORMATAR VALOR
  // ============================================================

  String _formatAmount(
    String value,
  ) {
    final number = double.tryParse(value);

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
    if (payment.status == 'action_required' &&
        payment.statusDetail == 'waiting_transfer') {
      return 'Aguardando pagamento';
    }

    return payment.statusDetail.isNotEmpty
        ? payment.statusDetail
        : payment.status;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final payment = _payment;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pagamento Pix',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 10),

            const Icon(
              Icons.pix,
              size: 72,
            ),

            const SizedBox(height: 18),

            const Text(
              'Pague com Pix',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Gere o QR Code e conclua '
              'o pagamento pelo aplicativo '
              'do seu banco.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            if (payment == null && !_isLoading)
              _buildGenerateButton(),

            if (_isLoading)
              _buildLoading(),

            if (_errorMessage != null)
              _buildError(),

            if (payment != null)
              _buildPayment(
                payment,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GERAR PIX
  // ============================================================

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 54,
      child: FilledButton.icon(
        onPressed: _generatePix,
        icon: const Icon(
          Icons.pix,
        ),
        label: const Text(
          'GERAR PIX',
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        vertical: 50,
      ),
      child: Column(
        children: [
          CircularProgressIndicator(),

          SizedBox(height: 18),

          Text(
            'Gerando pagamento Pix...',
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context)
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

        FilledButton(
          onPressed: _generatePix,
          child: const Text(
            'TENTAR NOVAMENTE',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAGAMENTO GERADO
  // ============================================================

  Widget _buildPayment(
    PixPaymentResult payment,
  ) {
    final qrImage = _decodeQrCodeImage(
      payment.qrCodeBase64,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ======================================================
        // AMBIENTE DE TESTE
        // ======================================================

        if (payment.testMode) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.science_outlined,
                ),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Ambiente de teste. '
                    'Nenhum dinheiro real será movimentado.',
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
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 4),

        Text(
          _formatAmount(
            payment.amount,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          _statusText(
            payment,
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 24),

        // ======================================================
        // QR CODE
        // ======================================================

        if (qrImage != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.memory(
                qrImage,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          )
        else
          const Center(
            child: Icon(
              Icons.qr_code_2,
              size: 180,
            ),
          ),

        const SizedBox(height: 24),

        // ======================================================
        // PIX COPIA E COLA
        // ======================================================

        const Text(
          'Pix Copia e Cola',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            payment.qrCode,
            maxLines: 4,
          ),
        ),

        const SizedBox(height: 14),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _copyPix,
            icon: const Icon(
              Icons.copy,
            ),
            label: const Text(
              'COPIAR PIX',
            ),
          ),
        ),

        const SizedBox(height: 26),

        // ======================================================
        // INFORMAÇÕES DE TESTE
        // ======================================================

        if (payment.testMode)
          ExpansionTile(
            title: const Text(
              'Dados do teste',
            ),
            childrenPadding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
            ),
            children: [
              _InfoRow(
                label: 'Order ID',
                value: payment.orderId,
              ),

              _InfoRow(
                label: 'Payment ID',
                value: payment.paymentId,
              ),

              _InfoRow(
                label: 'Status',
                value: payment.status,
              ),

              _InfoRow(
                label: 'Status detail',
                value: payment.statusDetail,
              ),

              _InfoRow(
                label: 'Valor real do serviço',
                value: _formatAmount(
                  payment.realAppointmentAmount,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Expanded(
            child: SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }
}