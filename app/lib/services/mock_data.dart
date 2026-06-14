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

const List<Map<String, dynamic>> mockWaterBodies = [
  {
    'id': 1,
    'name': 'Lago Guaíba',
    'waterType': 'LAKE',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          [-51.40, -30.14],
          [-51.24, -30.22],
          [-51.04, -30.16],
          [-51.07, -29.98],
          [-51.25, -29.93],
          [-51.40, -30.14]
        ]
      ]
    },
    'osmId': 1001,
    'source': 'OSM',
    'centerLon': -51.20,
    'centerLat': -30.08,
  },
  {
    'id': 2,
    'name': 'Lagoa dos Patos',
    'waterType': 'LAGOON',
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [
          [-52.50, -32.40],
          [-51.90, -32.70],
          [-51.20, -32.80],
          [-50.70, -32.35],
          [-50.95, -31.55],
          [-51.75, -31.35],
          [-52.40, -31.80],
          [-52.50, -32.40]
        ]
      ]
    },
    'osmId': 1002,
    'source': 'OSM',
    'centerLon': -51.75,
    'centerLat': -31.95,
  },
  {
    'id': 3,
    'name': 'Rio Jacuí',
    'waterType': 'RIVER',
    'geometry': {
      'type': 'LineString',
      'coordinates': [
        [-53.45, -29.60],
        [-52.95, -29.85],
        [-52.30, -30.02],
        [-51.45, -30.15]
      ]
    },
    'osmId': 1003,
    'source': 'OSM',
    'centerLon': -52.55,
    'centerLat': -29.90,
  },
];

/// Credenciais de demonstração reconhecidas no modo mock (espelham as do
/// backend em ambiente de desenvolvimento).
class _MockAccount {
  String name;
  final String email;
  String password;
  final String role;
  final int id;

  _MockAccount(this.id, this.name, this.email, this.password, this.role);

  Map<String, dynamic> toUserJson() =>
      {'id': id, 'name': name, 'email': email, 'role': role};
}

Map<String, dynamic> _jsonBody(http.Request request) {
  if (request.body.isEmpty) return const {};
  final decoded = jsonDecode(request.body);
  return decoded is Map<String, dynamic> ? decoded : const {};
}

http.Response _json(Object data, [int status = 200]) => http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Cria um [http.Client] que simula o backend (catálogo `/api/fish`,
/// autenticação `/auth/*` e perfil `/api/users/me`), com uma pequena latência.
///
/// Usado quando o app roda em modo mock (sem backend disponível). Cada cliente
/// mantém seu próprio cadastro em memória, então registrar + logar funciona
/// dentro da mesma sessão de serviço.
http.Client createMockClient() {
  final accounts = <String, _MockAccount>{
    'admin@fishing.local':
        _MockAccount(1, 'Administrador', 'admin@fishing.local', 'admin12345', 'ADMIN'),
    'demo@fishing.local':
        _MockAccount(2, 'Pescador Demo', 'demo@fishing.local', 'demo12345', 'USER'),
  };
  var nextId = 3;

  // Mapa token -> e-mail, para resolver `/api/users/me`.
  final tokens = <String, String>{};
  String issueToken(String email) {
    final token = 'mock-token-$email';
    tokens[token] = email;
    return token;
  }

  String? emailFromAuth(http.BaseRequest request) {
    final header = request.headers['Authorization'] ?? '';
    if (!header.startsWith('Bearer ')) return null;
    return tokens[header.substring(7)];
  }

  return MockClient((request) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final path = request.url.path;
    final method = request.method;

    if (path.startsWith('/api/fish')) {
      return _json(mockFishPage);
    }

    if (path.startsWith('/api/water-bodies')) {
      return _json(mockWaterBodies);
    }

    if (path == '/auth/register' && method == 'POST') {
      final body = _jsonBody(request);
      final email = (body['email'] as String?)?.trim() ?? '';
      if (accounts.containsKey(email)) {
        return _json({'message': 'E-mail já cadastrado'}, 409);
      }
      accounts[email] = _MockAccount(
        nextId++,
        (body['name'] as String?) ?? '',
        email,
        (body['password'] as String?) ?? '',
        'USER',
      );
      return http.Response('', 201);
    }

    if (path == '/auth/login' && method == 'POST') {
      final body = _jsonBody(request);
      final email = (body['email'] as String?)?.trim() ?? '';
      final password = (body['password'] as String?) ?? '';
      final account = accounts[email];
      if (account == null || account.password != password) {
        return _json({'message': 'Credenciais inválidas'}, 401);
      }
      return _json({
        'token': issueToken(email),
        'tokenType': 'Bearer',
        'expiresIn': 604800,
        'user': account.toUserJson(),
      });
    }

    if (path == '/api/users/me') {
      final email = emailFromAuth(request);
      final account = email == null ? null : accounts[email];
      if (account == null) return _json({'message': 'Não autorizado'}, 401);
      if (method == 'PUT') {
        final body = _jsonBody(request);
        final name = (body['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty) account.name = name;
        final password = body['password'] as String?;
        if (password != null && password.isNotEmpty) account.password = password;
      }
      return _json(account.toUserJson());
    }

    return http.Response('Not found', 404);
  });
}
