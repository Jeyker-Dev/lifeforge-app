import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/app/app.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/db/database_provider.dart';
import 'package:lifeforge/core/network/providers.dart';
import 'package:lifeforge/core/sync/providers.dart';
import 'package:lifeforge/core/sync/sync_exceptions.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';

import '../fakes.dart';

void main() {
  Future<void> pumpSignedInApp(WidgetTester tester, AppDatabase db) async {
    final store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'a', refreshToken: 'r'),
    );
    final gateway = FakeAuthGateway();
    final areasRemote = FakeAreasRemote()
      ..putError = const SyncNetworkException()
      ..pullError = const SyncNetworkException();
    final goalsRemote = FakeGoalsRemote()
      ..putError = const SyncNetworkException()
      ..pullError = const SyncNetworkException();
    final actionsRemote = FakeGoalActionsRemote()
      ..putError = const SyncNetworkException()
      ..pullError = const SyncNetworkException();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          authGatewayProvider.overrideWithValue(gateway),
          appDatabaseProvider.overrideWithValue(db),
          areasRemoteProvider.overrideWithValue(areasRemote),
          goalsRemoteProvider.overrideWithValue(goalsRemote),
          goalActionsRemoteProvider.overrideWithValue(actionsRemote),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: const LifeForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bottom NavigationBar switches between Hoy and Metas', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpSignedInApp(tester, db);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Tu día se forja aquí.'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Metas'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no tienes metas'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Hoy'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu día se forja aquí.'), findsOneWidget);
  });

  testWidgets('logging out from Metas redirects to login', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpSignedInApp(tester, db);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Metas'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets(
    'home areas screen (create, rename, color, delete) works in shell',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await pumpSignedInApp(tester, db);

      // Create
      await tester.tap(find.byTooltip('Nueva área'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Salud');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(find.text('Salud'), findsOneWidget);

      // Rename
      await tester.tap(find.byTooltip('Opciones de Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renombrar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bienestar');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Bienestar'), findsOneWidget);

      // Change color
      await tester.tap(find.byTooltip('Opciones de Bienestar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar color'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final areaRow = (await db.select(db.areas).get()).single;
      expect(areaRow.color, '#81B29A');

      // Delete
      await tester.tap(find.byTooltip('Opciones de Bienestar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Bienestar'), findsNothing);
      expect(find.text('Tu día se forja aquí.'), findsOneWidget);
    },
  );
}
