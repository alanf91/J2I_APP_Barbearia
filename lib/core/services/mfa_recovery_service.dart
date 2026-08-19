import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ============================================================
// RESULTADO DO INÍCIO DA RECUPERAÇÃO
// ============================================================

class MfaRecoveryStartResult {
  final String requestId;
  final String recoveryToken;
  final int expiresInMinutes;

  const MfaRecoveryStartResult({
    required this.requestId,
    required this.recoveryToken,
    required this.expiresInMinutes,
  });
}

// ============================================================
// EXCEÇÃO
// ============================================================

class MfaRecoveryException implements Exception {
  final String message;
  final String? code;

  const MfaRecoveryException(this.message, {this.code});

  @override
  String toString() {
    return message;
  }
}

// ============================================================
// SERVIÇO
// ============================================================

class MfaRecoveryService {
  static const String _baseUrl = 'http://10.0.2.2:8080';

  // ==========================================================
  // HEALTH CHECK
  // ==========================================================

  Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return false;
      }

      final data = _decodeResponse(response);

      return data['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================================
  // INICIAR RECUPERAÇÃO
  // ==========================================================

  Future<MfaRecoveryStartResult> startRecovery({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw const MfaRecoveryException('Informe seu e-mail.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/mfa-recovery/start'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({'email': normalizedEmail}),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MfaRecoveryException(
          _readMessage(
            data,
            fallback:
                'Não foi possível iniciar '
                'a recuperação.',
          ),
          code: data['code']?.toString(),
        );
      }

      final requestId = data['requestId']?.toString();

      final recoveryToken = data['recoveryToken']?.toString();

      if (requestId == null ||
          requestId.isEmpty ||
          recoveryToken == null ||
          recoveryToken.isEmpty) {
        throw const MfaRecoveryException(
          'O servidor retornou uma '
          'resposta inválida.',
        );
      }

      final rawExpiration = data['expiresInMinutes'];

      var expiresInMinutes = 15;

      if (rawExpiration is int) {
        expiresInMinutes = rawExpiration;
      } else if (rawExpiration != null) {
        expiresInMinutes = int.tryParse(rawExpiration.toString()) ?? 15;
      }

      return MfaRecoveryStartResult(
        requestId: requestId,
        recoveryToken: recoveryToken,
        expiresInMinutes: expiresInMinutes,
      );
    } on MfaRecoveryException {
      rethrow;
    } on TimeoutException {
      throw const MfaRecoveryException(
        'O servidor demorou muito '
        'para responder.',
      );
    } on http.ClientException {
      throw const MfaRecoveryException(
        'Não foi possível conectar '
        'ao servidor de recuperação.',
      );
    } catch (e) {
      throw const MfaRecoveryException(
        'Não foi possível iniciar '
        'a recuperação.',
      );
    }
  }

  // ==========================================================
  // CONCLUIR RECUPERAÇÃO DO MFA ANTIGO
  // ==========================================================

  Future<String> completeRecovery({
    required String requestId,
    required String recoveryToken,
  }) async {
    if (requestId.trim().isEmpty || recoveryToken.trim().isEmpty) {
      throw const MfaRecoveryException('Dados da recuperação inválidos.');
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/mfa-recovery/complete'),
            headers: const {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode({
              'requestId': requestId.trim(),
              'recoveryToken': recoveryToken.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MfaRecoveryException(
          _readMessage(
            data,
            fallback:
                'Não foi possível concluir '
                'a recuperação.',
          ),
          code: data['code']?.toString(),
        );
      }

      return _readMessage(data, fallback: 'Recuperação concluída.');
    } on MfaRecoveryException {
      rethrow;
    } on TimeoutException {
      throw const MfaRecoveryException(
        'O servidor demorou muito '
        'para responder.',
      );
    } on http.ClientException {
      throw const MfaRecoveryException(
        'Não foi possível conectar '
        'ao servidor de recuperação.',
      );
    } catch (_) {
      throw const MfaRecoveryException(
        'Não foi possível concluir '
        'a recuperação.',
      );
    }
  }

  // ==========================================================
  // FINALIZAR NOVO TELEFONE APÓS RECUPERAÇÃO
  // ==========================================================

  Future<String> finalizeRecoveredPhone({required String phoneNumber}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const MfaRecoveryException(
        'Nenhum usuário autenticado.',
        code: 'NOT_AUTHENTICATED',
      );
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null || idToken.isEmpty) {
      throw const MfaRecoveryException(
        'Não foi possível validar '
        'a sessão atual.',
        code: 'INVALID_TOKEN',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/v1/mfa-recovery/finalize-phone'),
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',

              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'phoneNumber': phoneNumber}),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MfaRecoveryException(
          _readMessage(
            data,
            fallback:
                'Não foi possível finalizar '
                'o novo telefone.',
          ),
          code: data['code']?.toString(),
        );
      }

      return _readMessage(
        data,
        fallback:
            'Novo telefone cadastrado '
            'com sucesso.',
      );
    } on MfaRecoveryException {
      rethrow;
    } on TimeoutException {
      throw const MfaRecoveryException(
        'O servidor demorou muito '
        'para responder.',
      );
    } on http.ClientException {
      throw const MfaRecoveryException(
        'Não foi possível conectar '
        'ao servidor de recuperação.',
      );
    } catch (_) {
      throw const MfaRecoveryException(
        'Não foi possível finalizar '
        'o novo telefone.',
      );
    }
  }

  // ==========================================================
  // DECODIFICAR RESPOSTA
  // ==========================================================

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

  // ==========================================================
  // MENSAGEM
  // ==========================================================

  String _readMessage(Map<String, dynamic> data, {required String fallback}) {
    final message = data['message']?.toString().trim();

    if (message == null || message.isEmpty) {
      return fallback;
    }

    return message;
  }
}
