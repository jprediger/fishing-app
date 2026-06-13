// Testes de widget da tela de busca, exercitando a integração
// tela -> FishService -> camada HTTP com um cliente simulado.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/search_screen.dart';
import 'package:mobile_app/services/fish_service.dart';

const _pageJson = '''
{
  "content": [
    { "id": 1, "name": "Tucunaré", "region": "Amazônia",
      "type": "FRESHWATER", "icon": { "path": "/i.png" } },
    { "id": 2, "name": "Robalo", "region": "Litoral",
      "type": "SALTWATER", "icon": null }
  ],
  "totalElements": 2, "totalPages": 1
}
''';

Widget _wrap(FishService service) =>
    MaterialApp(home: SearchScreen(service: service));

void main() {
  testWidgets('exibe a lista de peixes vinda do backend', (tester) async {
    final client = MockClient((_) async => http.Response(_pageJson, 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpWidget(_wrap(FishService(client: client)));

    // Estado de carregamento inicial.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Tucunaré'), findsOneWidget);
    expect(find.text('Robalo'), findsOneWidget);
  });

  testWidgets('filtra a lista pelo texto digitado', (tester) async {
    final client = MockClient((_) async => http.Response(_pageJson, 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpWidget(_wrap(FishService(client: client)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'robalo');
    await tester.pump();

    expect(find.text('Robalo'), findsOneWidget);
    expect(find.text('Tucunaré'), findsNothing);
  });

  testWidgets('mostra erro e permite tentar novamente', (tester) async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('erro', 500);
      return http.Response(_pageJson, 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await tester.pumpWidget(_wrap(FishService(client: client)));
    await tester.pumpAndSettle();

    // Primeira chamada falhou -> mensagem de erro e botão de retry.
    expect(find.textContaining('Erro ao buscar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    // Segunda chamada teve sucesso.
    expect(find.text('Tucunaré'), findsOneWidget);
  });
}
