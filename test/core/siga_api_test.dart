import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:siga/core/services/siga_api.dart';

http.Response jsonResponse(Object data) => http.Response(
      jsonEncode({'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  test(
    'envia filtros codificados e converte o contrato de ecopontos',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/ecopontos');
        expect(request.url.queryParameters['busca'], 'São Brás');
        expect(request.url.queryParameters['categoria'], 'Eletronicos');
        expect(request.url.queryParameters['latitude'], '0.0');
        expect(request.headers.containsKey('Authorization'), false);
        return jsonResponse([
          {
            'id': 3,
            'nome': 'Ponto de teste',
            'endereco': 'Endereço de teste',
            'categoria': 'Eletronicos',
            'categoria_nome': 'Eletrônicos',
            'horario': 'Seg a Sex',
            'latitude': 0,
            'longitude': 0,
            'demonstrativo': true,
            'distancia_km': 0,
          },
        ]);
      });
      final api = SigaApi(
        client: client,
        baseUrl: 'http://localhost:3000/api/',
      );
      addTearDown(api.close);
      final points = await api.ecopontos(
        busca: 'São Brás',
        categoria: 'Eletronicos',
        origem: const LatLng(0, 0),
      );
      expect(points.single.posicao.latitude, 0);
      expect(points.single.categoriaNome, 'Eletrônicos');
      expect(points.single.distanciaKm, 0);
      expect(points.single.demonstrativo, true);
    },
  );

  test(
    'retorna lista vazia sem inventar pontos e omite filtro Todos',
    () async {
      final api = SigaApi(
        client: MockClient((request) async {
          expect(request.url.queryParameters.containsKey('categoria'), false);
          expect(request.url.queryParameters.containsKey('latitude'), false);
          return jsonResponse([]);
        }),
      );
      addTearDown(api.close);
      expect(await api.ecopontos(categoria: 'Todos'), isEmpty);
    },
  );

  test('guia reúne resíduos e dicas sem perder acentos', () async {
    final api = SigaApi(
      client: MockClient(
        (request) async => request.url.path.endsWith('/residuos')
            ? jsonResponse([
                {
                  'codigo': 'Organicos',
                  'titulo': 'Orgânicos',
                  'descricao': 'Cascas de frutas.',
                },
              ])
            : jsonResponse([
                {'texto': 'Separe o óleo.'},
              ]),
      ),
    );
    addTearDown(api.close);
    final guia = await api.guia();
    expect(guia.residuos.single.titulo, 'Orgânicos');
    expect(guia.dicas.single, 'Separe o óleo.');
  });

  test('erros HTTP e respostas inválidas produzem mensagem de falha', () async {
    for (final response in [
      http.Response('Unavailable', 503),
      http.Response('not JSON', 200),
      http.Response('{"data":{}}', 200),
      http.Response('{"data":[42]}', 200),
    ]) {
      final api = SigaApi(client: MockClient((_) async => response));
      addTearDown(api.close);
      await expectLater(api.bairros(), throwsA(isA<ApiException>()));
    }
  });

  test('sem conexão e timeout são tratados pelo cliente', () async {
    final offline = SigaApi(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    final slow = SigaApi(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 5),
    );
    addTearDown(offline.close);
    addTearDown(slow.close);
    await expectLater(offline.bairros(), throwsA(isA<ApiException>()));
    await expectLater(slow.bairros(), throwsA(isA<ApiException>()));
  });
}
