import 'package:flutter/services.dart';

// ============================================================
// RESULTADO DA TELA NATIVA DO CARTÃO
// ============================================================

class NativeCardTokenizationResult {
  final String token;

  final String paymentMethodId;

  final String paymentMethodType;

  final int installments;

  const NativeCardTokenizationResult({
    required this.token,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.installments,
  });

  factory NativeCardTokenizationResult.fromMap(
    Map<String, dynamic> map,
  ) {
    return NativeCardTokenizationResult(
      token:
          map['token']
              ?.toString()
              .trim() ??
          '',

      paymentMethodId:
          map['paymentMethodId']
              ?.toString()
              .trim() ??
          '',

      paymentMethodType:
          map['paymentMethodType']
              ?.toString()
              .trim() ??
          '',

      installments:
          int.tryParse(
                map['installments']
                        ?.toString() ??
                    '',
              ) ??
              1,
    );
  }
}

// ============================================================
// PONTE FLUTTER ↔ ANDROID / MERCADO PAGO
// ============================================================

class MercadoPagoNativeBridge {
  MercadoPagoNativeBridge._();

  static const MethodChannel _channel =
      MethodChannel(
    'com.j2i.barbearia/mercado_pago',
  );

  // ============================================================
  // VERIFICAR SE O SDK ESTÁ DISPONÍVEL
  // ============================================================

  static Future<bool> isReady() async {
    try {
      final result =
          await _channel.invokeMapMethod<
              String,
              dynamic>(
        'isMercadoPagoReady',
      );

      return result?['ready'] == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // ============================================================
  // ABRIR TELA NATIVA E TOKENIZAR CARTÃO
  // ============================================================

  static Future<NativeCardTokenizationResult?>
      createCardToken({
    required String amount,
  }) async {
    final normalizedAmount =
        amount.trim();

    if (normalizedAmount.isEmpty) {
      throw PlatformException(
        code: 'INVALID_AMOUNT',
        message:
            'Valor do pagamento inválido.',
      );
    }

    final result =
        await _channel.invokeMapMethod<
            String,
            dynamic>(
      'createCardToken',
      {
        'amount': normalizedAmount,
      },
    );

    final status =
        result?['status']
            ?.toString()
            .trim();

    // ==========================================================
    // USUÁRIO CANCELOU
    // ==========================================================

    if (status == 'cancelled') {
      return null;
    }

    // ==========================================================
    // RESPOSTA INVÁLIDA
    // ==========================================================

    if (status != 'success') {
      throw PlatformException(
        code:
            'INVALID_CARD_RESPONSE',
        message:
            'Resposta inválida do '
            'pagamento com cartão.',
      );
    }

    final normalized =
        Map<String, dynamic>.from(
      result ??
          <String, dynamic>{},
    );

    final tokenization =
        NativeCardTokenizationResult.fromMap(
      normalized,
    );

    // ==========================================================
    // VALIDAR TOKEN
    // ==========================================================

    if (tokenization.token.isEmpty) {
      throw PlatformException(
        code:
            'EMPTY_CARD_TOKEN',
        message:
            'O Mercado Pago não retornou '
            'um token válido.',
      );
    }

    // ==========================================================
    // VALIDAR MEIO DE PAGAMENTO
    // ==========================================================

    if (tokenization.paymentMethodId.isEmpty ||
        tokenization.paymentMethodType.isEmpty) {
      throw PlatformException(
        code:
            'EMPTY_PAYMENT_METHOD',
        message:
            'Não foi possível identificar '
            'o cartão.',
      );
    }

    // ==========================================================
    // VALIDAR PARCELAS
    // ==========================================================

    if (tokenization.installments < 1) {
      throw PlatformException(
        code:
            'INVALID_INSTALLMENTS',
        message:
            'Parcelamento inválido.',
      );
    }

    return tokenization;
  }
}