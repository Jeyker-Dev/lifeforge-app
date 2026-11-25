import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/app/theme.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/db/database_provider.dart';
import 'package:lifeforge/core/sync/providers.dart';
import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/areas/data/drift_area_repository.dart';
import 'package:lifeforge/features/home/presentation/home_screen.dart';

import '../../fakes.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    AppDatabase db,
    FakeAreasRemote remote,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          areasRemoteProvider.overrideWithValue(remote),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: MaterialApp(theme: buildForgeTheme(), home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'creating an area offline shows it with the "pendiente de sincronizar" label',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final remote = FakeAreasRemote()..putError = const SyncNetworkException();

      await pumpHome(tester, db, remote);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Salud');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsOneWidget);
      expect(find.text('pendiente de sincronizar'), findsOneWidget);
    },
  );

  testWidgets('renaming an area updates its name in the list', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final remote = FakeAreasRemote()..putError = const SyncNetworkException();
    final repo = DriftAreaRepository(db);
    await repo.create(name: 'Salud', color: '#E07A5F');

    await pumpHome(tester, db, remote);

    await tester.tap(find.byTooltip('Opciones de Salud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Bienestar');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Bienestar'), findsOneWidget);
    expect(find.text('Salud'), findsNothing);
    final row = (await db.select(db.areas).get()).single;
    expect(row.name, 'Bienestar');
  });

  testWidgets(
    'changing an area color updates the swatch while keeping the name visible',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final remote = FakeAreasRemote()..putError = const SyncNetworkException();
      final repo = DriftAreaRepository(db);
      await repo.create(name: 'Salud', color: '#E07A5F');

      await pumpHome(tester, db, remote);

      await tester.tap(find.byTooltip('Opciones de Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar color'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Salud'), findsWidgets);
      await tester.tap(find.text('Salvia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsOneWidget);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundColor, ForgeColors.areaFinance);
      final row = (await db.select(db.areas).get()).single;
      expect(row.color, '#81B29A');
    },
  );

  testWidgets(
    'deleting an area requires confirmation and cancel keeps the area',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final remote = FakeAreasRemote()..putError = const SyncNetworkException();
      final repo = DriftAreaRepository(db);
      await repo.create(name: 'Salud', color: '#E07A5F');

      await pumpHome(tester, db, remote);

      await tester.tap(find.byTooltip('Opciones de Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsOneWidget);
      expect((await db.select(db.areas).get()).single.deletedAt, isNull);

      await tester.tap(find.byTooltip('Opciones de Salud'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsNothing);
      expect(find.text('Tu día se forja aquí.'), findsOneWidget);
      final row = (await db.select(db.areas).get()).single;
      expect(row.deletedAt, isNotNull);
    },
  );
}
