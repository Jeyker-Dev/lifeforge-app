import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/app/theme.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/db/database_provider.dart';
import 'package:lifeforge/core/sync/providers.dart';
import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/home/presentation/home_screen.dart';

import '../../fakes.dart';

void main() {
  testWidgets(
    'creating an area offline shows it with the "pendiente de sincronizar" label',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final remote = FakeAreasRemote()..putError = const SyncNetworkException();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            areasRemoteProvider.overrideWithValue(remote),
            connectivityStreamProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: MaterialApp(
            theme: buildForgeTheme(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Salud');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.text('Salud'), findsOneWidget);
      expect(find.text('pendiente de sincronizar'), findsOneWidget);
    },
  );
}
