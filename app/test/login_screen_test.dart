import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/token_storage.dart';
import 'package:mobile_app/state/auth_controller.dart';

import 'support/fake_store.dart';

const _loginBody = {
  'token': 'jwt-123',
  'tokenType': 'Bearer',
  'expiresIn': 604800,
  'user': {
    'id': 1,
    'name': 'Demo',
    'email': 'demo@fishing.local',
    'role': 'USER',
  },
};

AuthController _auth(MockClient client) => AuthController(
  authService: AuthService(client: client, baseUrl: 'http://test.local'),
  storage: TokenStorage(store: FakeStore()),
);

Widget _wrap(AuthController auth) => MaterialApp(home: LoginScreen(auth: auth));

void main() {
  testWidgets('e-mail inválido mostra erro e não chama a API', (tester) async {
    var called = false;
    final auth = _auth(
      MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
    );
    await tester.pumpWidget(_wrap(auth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'invalido',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'qualquer1',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('E-mail inválido'), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('senha vazia mostra erro de campo obrigatório', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('', 200)));
    await tester.pumpWidget(_wrap(auth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'a@a.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('Informe sua senha'), findsOneWidget);
  });

  testWidgets('credenciais inválidas (401) mostram mensagem', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('', 401)));
    await tester.pumpWidget(_wrap(auth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'a@a.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'senhaerrada',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    expect(auth.status, isNot(AuthStatus.authenticated));
  });

  testWidgets('login válido autentica o controller', (tester) async {
    final auth = _auth(
      MockClient(
        (_) async => http.Response(
          jsonEncode(_loginBody),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(_wrap(auth));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'demo@fishing.local',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'demo12345',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();

    expect(auth.status, AuthStatus.authenticated);
  });

  testWidgets('navega para a tela de cadastro', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('', 200)));
    await tester.pumpWidget(_wrap(auth));

    await tester.tap(find.text('Não tem conta? Cadastre-se'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
  });
}
