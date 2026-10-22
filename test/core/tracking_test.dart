import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:siga/core/services/siga_api.dart';

void main() {
  test('consulta caminhão sem enviar credencial administrativa', () async {
    final api = SigaApi(client: MockClient((request) async {
      expect(request.url.path, '/api/rastreamento');
      expect(request.headers.containsKey('Authorization'), false);
      return http.Response(jsonEncode({'data': [{
        'id': 'truck-1', 'nome': 'Caminhão teste', 'latitude': -1.45,
        'longitude': -48.49, 'precisao': 8, 'idade_segundos': 6,
        'status': 'ao_vivo', 'demonstrativo': true,
      }]}), 200, headers: {'content-type':'application/json; charset=utf-8'});
    }));
    addTearDown(api.close);
    final trucks = await api.caminhoes();
    expect(trucks.single.posicao.latitude, -1.45);
    expect(trucks.single.idadeSegundos, 6);
    expect(trucks.single.nome, 'Caminhão teste');
  });
  test('não inventa caminhão sem sinal', () async {
    final api = SigaApi(client: MockClient((_) async => http.Response('{"data":[]}',200)));
    addTearDown(api.close);
    expect(await api.caminhoes(), isEmpty);
  });
  test('contrato inválido vira erro legível', () async {
    final api = SigaApi(client: MockClient((_) async => http.Response('{"data":[{"latitude":"errada"}]}',200)));
    addTearDown(api.close);
    await expectLater(api.caminhoes(), throwsA(isA<ApiException>()));
  });
}
