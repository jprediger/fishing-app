import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/establishment.dart';
import 'api_exception.dart';

// Reexportado para compatibilidade com quem importa `ApiException` daqui.
export 'api_exception.dart';

/// Acesso ao recurso `/api/establishments` do backend.
///
/// A busca combina filtros opcionais: texto no nome (`q`), categoria e
/// proximidade (`lat`/`lon` + `radiusM`). O [http.Client] é injetável para
/// permitir testes com um cliente simulado.
class EstablishmentService {
  final http.Client _client;
  final String _baseUrl;
  final bool _ownsClient;

  EstablishmentService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _ownsClient = client == null,
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  Future<List<Establishment>> search({
    String? q,
    EstablishmentCategory? category,
    double? lat,
    double? lon,
    double? radiusM,
    int? limit,
  }) async {
    final queryParameters = <String, String>{};
    if (q != null && q.trim().isNotEmpty) {
      queryParameters['q'] = q.trim();
    }
    if (category != null) {
      queryParameters['category'] = category.apiValue;
    }
    if (lat != null) queryParameters['lat'] = '$lat';
    if (lon != null) queryParameters['lon'] = '$lon';
    if (radiusM != null) queryParameters['radiusM'] = '$radiusM';
    if (limit != null) queryParameters['limit'] = '$limit';

    final uri = Uri.parse('$_baseUrl/api/establishments').replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );

    final http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );
    } catch (_) {
      throw ApiException('Não foi possível conectar ao servidor em $uri.');
    }

    if (response.statusCode != 200) {
      throw ApiException(
        'Erro ao buscar estabelecimentos (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const ApiException('Resposta inesperada do servidor.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Establishment.fromJson)
        .toList();
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
