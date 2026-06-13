// Teste end-to-end (headless) do app de pesca.
//
// Roda o widget tree completo (FishingApp) com um cliente HTTP simulado
// injetado na camada de serviço, e verifica a navegação entre as abas
// Mapa, Buscar e Eu, além do consumo do backend na aba Buscar.
//
// Roda via: flutter test test/app_e2e_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/services/fish_service.dart';

const _pageJson = '''
{
  "content": [
    { "id": 1, "name": "Tucunaré", "region": "Amazônia",
      "type": "FRESHWATER", "icon": { "path": "/i.png" } },
    { "id": 2, "name": "Dourado", "region": "Pantanal",
      "type": "FRESHWATER", "icon": null }
  ],
  "totalElements": 2, "totalPages": 1
}
''';

void main() {
  testWidgets('navega entre as abas e carrega peixes do backend',
      (tester) async {
    final client = MockClient((_) async => http.Response(_pageJson, 200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester
        .pumpWidget(FishingApp(fishService: FishService(client: client)));
    await tester.pumpAndSettle();

    // Inicia na aba Mapa.
    expect(find.text('Pontos de pesca'), findsOneWidget);

    // Vai para a aba Buscar.
    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();

    // Os dados do backend simulado aparecem.
    expect(find.text('Tucunaré'), findsOneWidget);
    expect(find.text('Dourado'), findsOneWidget);

    // Vai para a aba Eu.
    await tester.tap(find.text('Eu'));
    await tester.pumpAndSettle();

    expect(find.text('Pescador'), findsOneWidget);
    expect(find.text('Capturas'), findsOneWidget);

    // Volta para o Mapa.
    await tester.tap(find.text('Mapa'));
    await tester.pumpAndSettle();
    expect(find.text('Pontos de pesca'), findsOneWidget);
  });
}
