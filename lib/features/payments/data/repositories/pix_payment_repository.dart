import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'package:j2i_app_barbearia/features/payments/data/models/pix_payment_result.dart';

class PixPaymentException implements Exception {
  final String message;
  final String? code;

  const PixPaymentException(this.message, {this.code});

  @override
  String toString() {
    return message;
  }
}

class PixPaymentRepository {
  // Android Emulator -> computador Windows.
  static const String _baseUrl = 'http://10.0.2.2:8080';

  final FirebaseAuth _auth;

  PixPaymentRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  Future<PixPaymentResult> createPix({required String appointmentId}) async {
    final normalizedAppointmentId = appointmentId.trim();

    if (normalizedAppointmentId.isEmpty) {
      throw const PixPaymentException('Agendamento inválido.');
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw const PixPaymentException(
        'Sua sessão expirou. Entre novamente.',
        code: 'NOT_AUTHENTICATED',
      );
    }

    try {
      final idToken = await user.getIdToken(true);

      if (idToken == null || idToken.isEmpty) {
        throw const PixPaymentException('Não foi possível validar sua sessão.');
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/payments/pix'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'appointmentId': normalizedAppointmentId}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw PixPaymentException(
          _readMessage(data, fallback: 'Não foi possível gerar o Pix.'),
          code: data['code']?.toString(),
        );
      }

      if (data['ok'] != true) {
        throw const PixPaymentException(
          'O servidor não confirmou '
          'a criação do Pix.',
        );
      }

      final result = PixPaymentResult.fromMap(data);

      if (result.orderId.isEmpty ||
          result.paymentId.isEmpty ||
          result.qrCode.isEmpty) {
        throw const PixPaymentException(
          'Os dados do Pix retornaram incompletos.',
        );
      }

      return result;
    } on PixPaymentException {
      rethrow;
    } on TimeoutException {
      throw const PixPaymentException(
        'O servidor demorou muito para responder.',
      );
    } on http.ClientException {
      throw const PixPaymentException(
        'Não foi possível conectar '
        'ao servidor de pagamentos.',
      );
    } catch (e) {
      throw PixPaymentException(
        'Não foi possível gerar o Pix. '
        'Detalhes: $e',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _readMessage(Map<String, dynamic> data, {required String fallback}) {
    final message = data['message']?.toString().trim();

    if (message == null || message.isEmpty) {
      return fallback;
    }

    return message;
  }
}
