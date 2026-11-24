import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/app/app.dart';
import 'package:lifeforge/core/network/providers.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';

import '../../fakes.dart';

void main() {
  late InMemoryTokenStore store;
  late FakeAuthGateway gateway;

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          authGatewayProvider.overrideWithValue(gateway),
        ],
        child: const LifeForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña'),
      password,
    );
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = InMemoryTokenStore();
    gateway = FakeAuthGateway();
  });

  testWidgets('signed out users land on the login screen', (tester) async {
    await pumpApp(tester);

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('a valid login opens the home screen', (tester) async {
    await pumpApp(tester);

    await submit(tester, 'me@example.com', 'secret');

    expect(find.text('Tu día se forja aquí.'), findsOneWidget);
  });

  testWidgets('wrong credentials show an error and stay on login', (
    tester,
  ) async {
    gateway.loginFailure = const InvalidCredentials();
    await pumpApp(tester);

    await submit(tester, 'me@example.com', 'wrong');

    expect(find.text('Email o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('empty fields ask for both values without calling the API', (
    tester,
  ) async {
    await pumpApp(tester);

    await submit(tester, '', '');

    expect(find.text('Ingresa tu email y tu contraseña.'), findsOneWidget);
    expect(gateway.loginCalls, 0);
  });

  testWidgets('logging out returns to the login screen', (tester) async {
    store.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    await pumpApp(tester);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
    expect(store.tokens, isNull);
  });
}
