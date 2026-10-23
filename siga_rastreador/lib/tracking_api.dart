import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Corresponds to backend/src/tracking.js in the SIGA repository.
class TrackingApi {
  static final Uri base = Uri.parse('https://siga-05o2.onrender.com');
  static final RegExp keyPattern = RegExp(
    r'^([0-9a-fA-F-]{36})\.([0-9a-fA-F]{64})$',
  );

  static ({String id, String token}) decodeKey(String value) {
    final parts = keyPattern.firstMatch(value.trim());
    if (parts == null) {
      throw const TrackingException('Chave inválida. Cole o código completo gerado pelo administrador.');
    }
    return (id: parts.group(1)!, token: parts.group(2)!);
  }

  static Future<void> sendPosition({
    required String id,
    required String token,
    required Position position,
  }) async {
    final captured = position.timestamp.millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (captured < now - 25000 || captured > now + 5000) {
      throw const TrackingException('Posição antiga. Aguarde uma nova leitura do GPS.');
    }
    if (!position.accuracy.isFinite || position.accuracy < 0 || position.accuracy > 100) {
      throw const TrackingException('Sinal GPS impreciso. Aguarde precisão melhor que 100 m.');
    }
    final response = await http.put(
      base.resolve('/api/rastreamento/$id/posicao'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'precisao': position.accuracy,
        'capturado_em': captured,
      }),
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode == 200) return;
    String message = 'Erro ao enviar posição (${response.statusCode}).';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map && error['message'] is String) message = error['message'] as String;
    } catch (_) { /* Resposta não JSON. */ }
    throw TrackingException(message, statusCode: response.statusCode);
  }

  static Future<void> endSession({required String id, required String token}) async {
    final response = await http.delete(
      base.resolve('/api/rastreamento/$id'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 204 && response.statusCode != 401 && response.statusCode != 404) {
      throw TrackingException('Não foi possível apagar a sessão (${response.statusCode}).');
    }
  }
}

class TrackingException implements Exception {
  const TrackingException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
