import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/api_config.dart';
import '../models/siga_models.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

/// Um cliente por tela; fechar em dispose. Credenciais administrativas ficam fora do app.
class SigaApi {
  final http.Client _client;
  final Uri _base;
  final Duration timeout;

  SigaApi({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 12),
  })  : _client = client ?? http.Client(),
        _base = Uri.parse(
          '${(baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/+$'), '')}/',
        );

  static String get defaultBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (ApiConfig.backendOnlineUrl.isNotEmpty) {
      return ApiConfig.backendOnlineUrl;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  Future<List<Map<String, dynamic>>> _getList(
    String path, [
    Map<String, String>? query,
  ]) async {
    if (_base.host == 'localhost' &&
        kIsWeb &&
        Uri.base.host != 'localhost' &&
        Uri.base.host != '127.0.0.1') {
      throw const ApiException(
        'Configure a URL pública da API em lib/core/config/api_config.dart.',
      );
    }
    try {
      final response = await _client.get(
        _base.resolve(path).replace(queryParameters: query),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException(
          'Não foi possível carregar os dados (${response.statusCode}). Tente novamente.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic> || decoded['data'] is! List) {
        throw const FormatException();
      }
      return (decoded['data'] as List).map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        return item;
      }).toList();
    } on TimeoutException {
      throw const ApiException(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Não foi possível conectar. Confira sua conexão e tente novamente.',
      );
    } on FormatException {
      throw const ApiException(
        'O servidor retornou dados inválidos. Tente novamente.',
      );
    }
  }

  Future<List<Bairro>> bairros() async =>
      (await _getList('bairros')).map(Bairro.fromJson).toList();

  Future<List<Categoria>> categorias() async =>
      (await _getList('categorias')).map(Categoria.fromJson).toList();

  Future<List<Ecoponto>> ecopontos({
    String? busca,
    String? categoria,
    LatLng? origem,
  }) async {
    final query = <String, String>{
      if (busca != null && busca.trim().isNotEmpty) 'busca': busca.trim(),
      if (categoria != null && categoria != 'Todos') 'categoria': categoria,
      if (origem != null) 'latitude': origem.latitude.toString(),
      if (origem != null) 'longitude': origem.longitude.toString(),
    };
    return (await _getList('ecopontos', query)).map(Ecoponto.fromJson).toList();
  }

  Future<GuiaData> guia() async {
    final parts = await Future.wait([_getList('residuos'), _getList('dicas')]);
    return GuiaData(
      residuos: parts[0].map(ResiduoInfo.fromJson).toList(),
      dicas: parts[1].map((row) => row['texto'] as String).toList(),
    );
  }

  void close() => _client.close();
}
