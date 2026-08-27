import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:j2i_app_barbearia/features/payments/data/repositories/card_payment_repository.dart';
import 'package:j2i_app_barbearia/features/payments/data/services/mercado_pago_native_bridge.dart';

class CardPaymentPage extends StatefulWidget {
  final String appointmentId;

  const CardPaymentPage({
    super.key,
    required this.appointmentId,
  });

  @override
  State<CardPaymentPage> createState() =>
      _CardPaymentPageState();
}

class _CardPaymentPageState
    extends State<CardPaymentPage> {
  final CardPaymentRepository _repository =
      CardPaymentRepository();

  bool _isLoading =
      true;

  bool _flowStarted =
      false;

  String? _errorMessage;

  CardPaymentPreparation? _preparation;

  CardPaymentResult? _payment;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding
        .instance
        .addPostFrameCallback(
      (_) {
        _startAutomatically();
      },
    );
  }

  // ============================================================
  // INICIAR AUTOMATICAMENTE
  // ============================================================

  Future<void> _startAutomatically() async {
    if (_flowStarted) {
      return;
    }

    _flowStarted =
        true;

    await _startPaymentFlow();
  }

  // ============================================================
  // FLUXO COMPLETO
  // ============================================================

  Future<void> _startPaymentFlow() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading =
          true;

      _errorMessage =
          null;

      _payment =
          null;
    });

    try {
      // ========================================================
      // 1. BACKEND DETERMINA O VALOR
      // ========================================================

      final preparation =
          await _repository.prepareCard(
        appointmentId:
            widget.appointmentId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _preparation =
            preparation;
      });

      // ========================================================
      // 2. ABRIR TELA PCI NATIVA
      // ========================================================

      final cardData =
          await MercadoPagoNativeBridge
              .createCardToken(
        amount:
            preparation.amount,
      );

      if (!mounted) {
        return;
      }

      // Usuário cancelou.
      if (cardData == null) {
        setState(() {
          _isLoading =
              false;
        });

        Navigator
            .of(context)
            .pop();

        return;
      }

      // ========================================================
      // 3. ENVIAR TOKEN IMEDIATAMENTE AO BACKEND
      // ========================================================
      //
      // cardData.token existe apenas nesta chamada.
      // Não armazenamos em State, Firestore ou disco.
      // ========================================================

      final payment =
          await _repository
              .createCardPayment(
        appointmentId:
            widget.appointmentId,

        cardToken:
            cardData.token,

        paymentMethodId:
            cardData.paymentMethodId,

        paymentMethodType:
            cardData.paymentMethodType,

        installments:
            cardData.installments,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _payment =
            payment;

        _isLoading =
            false;

        _errorMessage =
            null;
      });
    } on CardPaymentException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            e.message;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            e.message ??
            'Não foi possível processar '
                'o cartão.';
      });
    } on MissingPluginException {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            'A integração Android '
            'do Mercado Pago '
            'não foi encontrada.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading =
            false;

        _errorMessage =
            'Não foi possível processar '
            'o pagamento com cartão.';
      });
    }
  }

  // ============================================================
  // MOEDA
  // ============================================================

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

  // ============================================================
  // BANDEIRA
  // ============================================================

  String _brandName(
    String value,
  ) {
    switch (
      value.toLowerCase()
    ) {
      case 'master':
      case 'mastercard':
        return 'Mastercard';

      case 'visa':
        return 'Visa';

      case 'amex':
        return 'American Express';

      case 'elo':
        return 'Elo';

      case 'hipercard':
        return 'Hipercard';

      default:
        return value.toUpperCase();
    }
  }

  String _paymentTypeName(
    String value,
  ) {
    switch (
      value
    ) {
      case 'credit_card':
        return 'Crédito';

      case 'debit_card':
        return 'Débito';

      case 'prepaid_card':
        return 'Pré-pago';

      default:
        return 'Cartão';
    }
  }

  // ============================================================
  // CONCLUIR
  // ============================================================

  void _finish() {
    Navigator.of(context).popUntil(
      (route) =>
          route.isFirst,
    );
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
        title: const Text(
          'Pagamento com cartão',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(
            20,
          ),
          children: [
            if (_isLoading)
              _buildLoading(),

            if (!_isLoading &&
                _errorMessage !=
                    null)
              _buildError(),

            if (!_isLoading &&
                payment != null)
              _buildPaymentResult(
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
    final preparation =
        _preparation;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 70,
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),

          const SizedBox(
            height: 22,
          ),

          Text(
            preparation == null
                ? 'Preparando pagamento...'
                : 'Processando pagamento...',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 17,
            ),
          ),

          if (preparation !=
              null) ...[
            const SizedBox(
              height: 12,
            ),

            Text(
              _formatAmount(
                preparation.amount,
              ),
              style:
                  const TextStyle(
                fontSize: 26,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // ERRO
  // ============================================================

  Widget _buildError() {
    return Column(
      children: [
        const SizedBox(
          height: 40,
        ),

        Icon(
          Icons.error_outline,
          size: 82,
          color:
              Theme.of(context)
                  .colorScheme
                  .error,
        ),

        const SizedBox(
          height: 22,
        ),

        const Text(
          'Pagamento não concluído',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            fontSize: 25,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        Text(
          _errorMessage!,
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 30,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              54,
          child:
              FilledButton.icon(
            onPressed:
                _startPaymentFlow,
            icon:
                const Icon(
              Icons.refresh,
            ),
            label:
                const Text(
              'TENTAR NOVAMENTE',
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              52,
          child:
              OutlinedButton(
            onPressed: () {
              Navigator
                  .of(context)
                  .pop();
            },
            child:
                const Text(
              'VOLTAR',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // RESULTADO
  // ============================================================

  Widget _buildPaymentResult(
    CardPaymentResult payment,
  ) {
    if (payment.approved) {
      return _buildApproved(
        payment,
      );
    }

    if (payment.requiresAction ||
        payment.status ==
            'pending' ||
        payment.status ==
            'action_required') {
      return _buildPending(
        payment,
      );
    }

    return _buildNotApproved(
      payment,
    );
  }

  // ============================================================
  // APROVADO
  // ============================================================

  Widget _buildApproved(
    CardPaymentResult payment,
  ) {
    return Column(
      children: [
        const SizedBox(
          height: 30,
        ),

        const Icon(
          Icons.check_circle_outline,
          size: 100,
        ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Pagamento aprovado!',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        const Text(
          'O Mercado Pago confirmou '
          'o pagamento.',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 28,
        ),

        _buildPaymentCard(
          payment,
        ),

        const SizedBox(
          height: 28,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              54,
          child:
              FilledButton.icon(
            onPressed:
                _finish,
            icon:
                const Icon(
              Icons.check,
            ),
            label:
                const Text(
              'CONCLUIR',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PENDENTE
  // ============================================================

  Widget _buildPending(
    CardPaymentResult payment,
  ) {
    return Column(
      children: [
        const SizedBox(
          height: 30,
        ),

        const Icon(
          Icons.schedule_outlined,
          size: 94,
        ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Pagamento em análise',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            fontSize: 26,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        const Text(
          'O Mercado Pago ainda está '
          'processando a transação.',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 28,
        ),

        _buildPaymentCard(
          payment,
        ),

        const SizedBox(
          height: 28,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              54,
          child:
              FilledButton(
            onPressed:
                _finish,
            child:
                const Text(
              'CONCLUIR',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NÃO APROVADO
  // ============================================================

  Widget _buildNotApproved(
    CardPaymentResult payment,
  ) {
    return Column(
      children: [
        const SizedBox(
          height: 30,
        ),

        Icon(
          Icons.cancel_outlined,
          size: 94,
          color:
              Theme.of(context)
                  .colorScheme
                  .error,
        ),

        const SizedBox(
          height: 24,
        ),

        const Text(
          'Pagamento não aprovado',
          textAlign:
              TextAlign.center,
          style:
              TextStyle(
            fontSize: 26,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        const Text(
          'Tente novamente com '
          'outro cartão ou escolha Pix.',
          textAlign:
              TextAlign.center,
        ),

        const SizedBox(
          height: 28,
        ),

        _buildPaymentCard(
          payment,
        ),

        const SizedBox(
          height: 28,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              54,
          child:
              FilledButton.icon(
            onPressed:
                _startPaymentFlow,
            icon:
                const Icon(
              Icons.credit_card,
            ),
            label:
                const Text(
              'TENTAR OUTRO CARTÃO',
            ),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        SizedBox(
          width:
              double.infinity,
          height:
              52,
          child:
              OutlinedButton(
            onPressed: () {
              Navigator
                  .of(context)
                  .pop();
            },
            child:
                const Text(
              'ESCOLHER OUTRA FORMA',
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CARTÃO COM DADOS DA TRANSAÇÃO
  // ============================================================

  Widget _buildPaymentCard(
    CardPaymentResult payment,
  ) {
    final brand =
        _brandName(
      payment.paymentMethodId,
    );

    final type =
        _paymentTypeName(
      payment.paymentMethodType,
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _InfoLine(
            label:
                'Valor',
            value:
                _formatAmount(
              payment.amount,
            ),
          ),

          _InfoLine(
            label:
                'Cartão',
            value:
                '$brand • $type',
          ),

          _InfoLine(
            label:
                'Parcelas',
            value:
                '${payment.installments}x',
          ),

          if (payment.testMode) ...[
            const Divider(),

            _InfoLine(
              label:
                  'Ambiente',
              value:
                  'Teste / Sandbox',
            ),

            _InfoLine(
              label:
                  'Payment ID',
              value:
                  payment.paymentId,
            ),

            _InfoLine(
              label:
                  'Status',
              value:
                  payment.status,
            ),

            _InfoLine(
              label:
                  'Detalhe',
              value:
                  payment.statusDetail,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// INFO
// ============================================================

class _InfoLine extends StatelessWidget {
  final String label;

  final String value;

  const _InfoLine({
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
        bottom: 10,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
                90,
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
                Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}