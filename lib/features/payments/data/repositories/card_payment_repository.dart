import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ============================================================
// EXCEPTION
// ============================================================

class CardPaymentException implements Exception {
  final String message;
  final String? code;

  const CardPaymentException(
    this.message, {
    this.code,
  });

  @override
  String toString() {
    return message;
  }
}

// ============================================================
// PREPARAÇÃO DO PAGAMENTO
// ============================================================

class CardPaymentPreparation {
  final String appointmentId;
  final String amount;
  final String realAppointmentAmount;
  final bool testMode;

  const CardPaymentPreparation({
    required this.appointmentId,
    required this.amount,
    required this.realAppointmentAmount,
    required this.testMode,
  });

  factory CardPaymentPreparation.fromMap(
    Map<String, dynamic> map,
  ) {
    return CardPaymentPreparation(
      appointmentId:
          map['appointmentId']?.toString() ?? '',
      amount:
          map['amount']?.toString() ?? '',
      realAppointmentAmount:
          map['realAppointmentAmount']?.toString() ?? '',
      testMode:
          map['testMode'] == true,
    );
  }
}

// ============================================================
// RESULTADO DO PAGAMENTO
// ============================================================

class CardPaymentResult {
  final String appointmentId;

  final String orderId;
  final String paymentId;

  final String status;
  final String statusDetail;

  final String orderStatus;
  final String orderStatusDetail;

  final bool approved;
  final bool requiresAction;

  final String amount;
  final String realAppointmentAmount;

  final bool testMode;

  final String paymentMethodId;
  final String paymentMethodType;

  final int installments;

  const CardPaymentResult({
    required this.appointmentId,
    required this.orderId,
    required this.paymentId,
    required this.status,
    required this.statusDetail,
    required this.orderStatus,
    required this.orderStatusDetail,
    required this.approved,
    required this.requiresAction,
    required this.amount,
    required this.realAppointmentAmount,
    required this.testMode,
    required this.paymentMethodId,
    required this.paymentMethodType,
    required this.installments,
  });

  factory CardPaymentResult.fromMap(
    Map<String, dynamic> map,
  ) {
    final card =
        map['card'] is Map
            ? Map<String, dynamic>.from(
                map['card'] as Map,
              )
            : <String, dynamic>{};

    return CardPaymentResult(
      appointmentId:
          map['appointmentId']?.toString() ?? '',
      orderId:
          map['orderId']?.toString() ?? '',
      paymentId:
          map['paymentId']?.toString() ?? '',
      status:
          map['status']?.toString() ?? '',
      statusDetail:
          map['statusDetail']?.toString() ?? '',
      orderStatus:
          map['orderStatus']?.toString() ?? '',
      orderStatusDetail:
          map['orderStatusDetail']?.toString() ?? '',
      approved:
          map['approved'] == true,
      requiresAction:
          map['requiresAction'] == true,
      amount:
          map['amount']?.toString() ?? '',
      realAppointmentAmount:
          map['realAppointmentAmount']?.toString() ?? '',
      testMode:
          map['testMode'] == true,
      paymentMethodId:
          card['paymentMethodId']?.toString() ?? '',
      paymentMethodType:
          card['paymentMethodType']?.toString() ?? '',
      installments:
          int.tryParse(
                card['installments']?.toString() ?? '',
              ) ??
              1,
    );
  }
}

// ============================================================
// REPOSITORY
// ============================================================

class CardPaymentRepository {
  // Android Emulator -> computador Windows.
  static const String _baseUrl =
      'http://10.0.2.2:8080';

  final FirebaseAuth _auth;

  CardPaymentRepository({
    FirebaseAuth? auth,
  }) : _auth =
           auth ??
           FirebaseAuth.instance;

  // ============================================================
  // PREPARAR PAGAMENTO
  // ============================================================

  Future<CardPaymentPreparation> prepareCard({
    required String appointmentId,
  }) async {
    final normalizedAppointmentId =
        appointmentId.trim();

    if (normalizedAppointmentId.isEmpty) {
      throw const CardPaymentException(
        'Agendamento inválido.',
      );
    }

    try {
      final data =
          await _authenticatedPost(
        path:
            '/v1/payments/card/prepare',
        body: {
          'appointmentId':
              normalizedAppointmentId,
        },
        fallbackMessage:
            'Não foi possível preparar '
            'o pagamento com cartão.',
      );

      if (data['ok'] != true) {
        throw const CardPaymentException(
          'O servidor não confirmou '
          'a preparação do pagamento.',
        );
      }

      final preparation =
          CardPaymentPreparation.fromMap(
        data,
      );

      if (preparation.amount.isEmpty) {
        throw const CardPaymentException(
          'O servidor não retornou '
          'o valor do pagamento.',
        );
      }

      return preparation;
    } on CardPaymentException {
      rethrow;
    } on TimeoutException {
      throw const CardPaymentException(
        'O servidor demorou muito '
        'para responder.',
      );
    } on http.ClientException {
      throw const CardPaymentException(
        'Não foi possível conectar '
        'ao servidor de pagamentos.',
      );
    } catch (_) {
      throw const CardPaymentException(
        'Não foi possível preparar '
        'o pagamento com cartão.',
      );
    }
  }

  // ============================================================
  // CRIAR PAGAMENTO
  // ============================================================

  Future<CardPaymentResult> createCardPayment({
    required String appointmentId,
    required String cardToken,
    required String paymentMethodId,
    required String paymentMethodType,
    required int installments,
  }) async {
    final normalizedAppointmentId =
        appointmentId.trim();

    final normalizedCardToken =
        cardToken.trim();

    final normalizedPaymentMethodId =
        paymentMethodId.trim();

    final normalizedPaymentMethodType =
        paymentMethodType.trim();

    if (normalizedAppointmentId.isEmpty) {
      throw const CardPaymentException(
        'Agendamento inválido.',
      );
    }

    if (normalizedCardToken.isEmpty) {
      throw const CardPaymentException(
        'Token do cartão inválido.',
      );
    }

    if (normalizedPaymentMethodId.isEmpty ||
        normalizedPaymentMethodType.isEmpty) {
      throw const CardPaymentException(
        'Meio de pagamento inválido.',
      );
    }

    if (installments < 1) {
      throw const CardPaymentException(
        'Quantidade de parcelas inválida.',
      );
    }

    try {
      final data =
          await _authenticatedPost(
        path:
            '/v1/payments/card',
        body: {
          'appointmentId':
              normalizedAppointmentId,

          'cardToken':
              normalizedCardToken,

          'paymentMethodId':
              normalizedPaymentMethodId,

          'paymentMethodType':
              normalizedPaymentMethodType,

          'installments':
              installments,
        },
        fallbackMessage:
            'Não foi possível processar '
            'o pagamento com cartão.',
      );

      if (data['ok'] != true) {
        throw const CardPaymentException(
          'O servidor não confirmou '
          'o pagamento.',
        );
      }

      final result =
          CardPaymentResult.fromMap(
        data,
      );

      if (result.orderId.isEmpty ||
          result.paymentId.isEmpty) {
        throw const CardPaymentException(
          'O Mercado Pago retornou '
          'dados incompletos.',
        );
      }

      return result;
    } on CardPaymentException {
      rethrow;
    } on TimeoutException {
      throw const CardPaymentException(
        'O servidor demorou muito '
        'para responder.',
      );
    } on http.ClientException {
      throw const CardPaymentException(
        'Não foi possível conectar '
        'ao servidor de pagamentos.',
      );
    } catch (_) {
      throw const CardPaymentException(
        'Não foi possível processar '
        'o pagamento com cartão.',
      );
    }
  }

  // ============================================================
  // POST AUTENTICADO
  // ============================================================

  Future<Map<String, dynamic>>
      _authenticatedPost({
    required String path,
    required Map<String, dynamic> body,
    required String fallbackMessage,
  }) async {
    final user =
        _auth.currentUser;

    if (user == null) {
      throw const CardPaymentException(
        'Sua sessão expirou. '
        'Entre novamente.',
        code:
            'NOT_AUTHENTICATED',
      );
    }

    final idToken =
        await user.getIdToken(true);

    if (idToken == null ||
        idToken.isEmpty) {
      throw const CardPaymentException(
        'Não foi possível validar '
        'sua sessão.',
      );
    }

    final response =
        await http
            .post(
              Uri.parse(
                '$_baseUrl$path',
              ),
              headers: {
                'Content-Type':
                    'application/json; charset=UTF-8',

                'Authorization':
                    'Bearer $idToken',
              },
              body:
                  jsonEncode(
                body,
              ),
            )
            .timeout(
              const Duration(
                seconds: 25,
              ),
            );

    final data =
        _decodeResponse(
      response,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw CardPaymentException(
        _readMessage(
          data,
          fallback:
              fallbackMessage,
        ),
        code:
            data['code']
                ?.toString(),
      );
    }

    return data;
  }

  // ============================================================
  // JSON
  // ============================================================

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    if (response.bodyBytes.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded =
          jsonDecode(
        utf8.decode(
          response.bodyBytes,
        ),
      );

      if (decoded is Map) {
        return Map<String, dynamic>.from(
          decoded,
        );
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _readMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final message =
        data['message']
            ?.toString()
            .trim();

    if (message == null ||
        message.isEmpty) {
      return fallback;
    }

    return message;
  }
}