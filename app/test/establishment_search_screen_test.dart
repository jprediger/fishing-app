// Testes de widget da tela de busca de estabelecimentos, exercitando a
// integração tela -> EstablishmentService -> camada HTTP com cliente simulado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/models/establishment.dart';
import 'package:mobile_app/screens/establishment_search_screen.dart';
import 'package:mobile_app/services/establishment_service.dart';

const _listJson = '''
[
  { "id": 1, "name": "Loja do Pescador", "category": "LOJA_PESCA",
    "address": "Centro", "lon": -51.2, "lat": -30.0 },
  { "id": 2, "name": "Pesqueiro Sol", "category": "PESQUEIRO",
    "address": "Zona rural", "lon": -51.3, "lat": -30.1 }
]
''';

Widget _wrap(EstablishmentService service) =>
    MaterialApp(home: EstablishmentSearchScreen(service: service));

void main() {
  testWidgets('exibe a lista de estabelecimentos vinda do backend', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        _listJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpWidget(_wrap(EstablishmentService(client: client)));

    // Estado de carregamento inicial.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Loja do Pescador'), findsOneWidget);
    expect(find.text('Pesqueiro Sol'), findsOneWidget);
  });

  testWidgets('mostra erro e permite tentar novamente', (tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('erro', 500);
      return http.Response(
        _listJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await tester.pumpWidget(_wrap(EstablishmentService(client: client)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Erro ao buscar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Loja do Pescador'), findsOneWidget);
  });

  testWidgets('"Ver no mapa" dispara onShowOnMap com o estabelecimento', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        _listJson,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    Establishment? shown;
    await tester.pumpWidget(
      MaterialApp(
        home: EstablishmentSearchScreen(
          service: EstablishmentService(client: client),
          onShowOnMap: (e) => shown = e,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o detalhe e aciona "Ver no mapa".
    await tester.tap(find.text('Loja do Pescador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver no mapa'));
    await tester.pumpAndSettle();

    expect(shown, isNotNull);
    expect(shown!.name, 'Loja do Pescador');
  });
}
