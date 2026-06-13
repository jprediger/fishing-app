import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Catálogo de peixes mockado, no mesmo formato paginado (`Page`) que o
/// backend Spring Boot retorna em `GET /api/fish`.
const Map<String, dynamic> mockFishPage = {
  'content': [
    {
      'id': 1,
      'name': 'Tucunaré',
      'description': 'Peixe predador de água doce, popular na pesca esportiva.',
      'region': 'Bacia Amazônica',
      'type': 'FRESHWATER',
      'icon': {'path': '/icons/tucunare.png'},
    },
    {
      'id': 2,
      'name': 'Dourado',
      'description': 'Conhecido pela briga e pelos saltos; espécie de água doce.',
      'region': 'Pantanal',
      'type': 'FRESHWATER',
      'icon': {'path': '/icons/dourado.png'},
    },
    {
      'id': 3,
      'name': 'Robalo',
      'description': 'Peixe de água salgada muito procurado no litoral.',
      'region': 'Litoral Sudeste',
      'type': 'SALTWATER',
      'icon': {'path': '/icons/robalo.png'},
    },
    {
      'id': 4,
      'name': 'Traíra',
      'description': 'Predador comum em lagoas e açudes de água doce.',
      'region': 'Rio Grande do Sul',
      'type': 'FRESHWATER',
      'icon': {'path': '/icons/traira.png'},
    },
    {
      'id': 5,
      'name': 'Tainha',
      'description': 'Espécie de água salobra/salgada, abundante no inverno.',
      'region': 'Lagoa dos Patos',
      'type': 'BRACKISH',
      'icon': {'path': '/icons/tainha.png'},
    },
    {
      'id': 6,
      'name': 'Corvina',
      'description': 'Peixe costeiro de água salgada, comum na pesca de praia.',
      'region': 'Litoral Sul',
      'type': 'SALTWATER',
      'icon': {'path': '/icons/corvina.png'},
    },
  ],
  'totalElements': 6,
  'totalPages': 1,
  'number': 0,
  'size': 20,
};

/// Cria um [http.Client] que responde às chamadas de `/api/fish` com o
/// catálogo mockado acima, simulando uma pequena latência de rede.
///
/// Usado quando o app roda em modo mock (sem backend disponível).
http.Client createMockClient() {
  return MockClient((request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (request.url.path.startsWith('/api/fish')) {
      return http.Response(
        jsonEncode(mockFishPage),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response('Not found', 404);
  });
}
