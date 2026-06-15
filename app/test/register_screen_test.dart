import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/register_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/token_storage.dart';
import 'package:mobile_app/state/auth_controller.dart';

import 'support/fake_store.dart';

AuthController _auth(MockClient client) => AuthController(
  authService: AuthService(client: client, baseUrl: 'http://test.local'),
  storage: TokenStorage(store: FakeStore()),
);

Widget _wrap(AuthController auth) =>
    MaterialApp(home: RegisterScreen(auth: auth));

Future<void> _fill(
  WidgetTester tester, {
  required String name,
  required String email,
  required String password,
}) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), name);
  await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), password);
}

void main() {
  testWidgets('senha curta (< 8) mostra erro e não chama a API', (
    tester,
  ) async {
    var called = false;
    final auth = _auth(
      MockClient((_) async {
        called = true;
        return http.Response('', 201);
      }),
    );
    await tester.pumpWidget(_wrap(auth));

    await _fill(tester, name: 'Ana', email: 'ana@test.local', password: '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
    await tester.pump();

    expect(find.text('A senha deve ter ao menos 8 caracteres'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('nome vazio mostra erro', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('', 201)));
    await tester.pumpWidget(_wrap(auth));

    await _fill(
      tester,
      name: '',
      email: 'ana@test.local',
      password: '12345678',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
    await tester.pump();

    expect(find.text('Informe seu nome'), findsOneWidget);
  });

  testWidgets('e-mail duplicado (409) mostra mensagem', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('', 409)));
    await tester.pumpWidget(_wrap(auth));

    await _fill(
      tester,
      name: 'Ana',
      email: 'dup@test.local',
      password: '12345678',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
    await tester.pumpAndSettle();

    expect(find.text('Este e-mail já está cadastrado.'), findsOneWidget);
  });
}
