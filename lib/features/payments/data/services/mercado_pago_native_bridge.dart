import 'package:flutter/services.dart';

class MercadoPagoNativeBridge {
  MercadoPagoNativeBridge._();

  static const MethodChannel _channel = MethodChannel(
    'com.j2i.barbearia/mercado_pago',
  );

  // ============================================================
  // VERIFICAR SDK
  // ============================================================

  static Future<bool> isReady() async {
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>(
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
  // GERAR TOKEN DO CARTÃO
  // ============================================================

  static Future<String?> createCardToken() async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>(
      'createCardToken',
    );

    final status =
        result?['status']?.toString();

    if (status == 'cancelled') {
      return null;
    }

    if (status != 'success') {
      throw PlatformException(
        code: 'INVALID_CARD_TOKEN_RESPONSE',
        message:
            'Resposta inválida da tokenização do cartão.',
      );
    }

    final token =
        result?['token']?.toString();

    if (token == null ||
        token.trim().isEmpty) {
      throw PlatformException(
        code: 'EMPTY_CARD_TOKEN',
        message:
            'O Mercado Pago não retornou um token.',
      );
    }

    return token;
  }
}