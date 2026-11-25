import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/app/theme.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/db/database_provider.dart';
import 'package:lifeforge/core/sync/providers.dart';
import 'package:lifeforge/core/sync/sync_exceptions.dart';
import 'package:lifeforge/features/areas/data/drift_area_repository.dart';
import 'package:lifeforge/features/goals/data/drift_goal_repository.dart';
import 'package:lifeforge/features/goals/domain/goal.dart';
import 'package:lifeforge/features/goals/presentation/goal_card.dart';
import 'package:lifeforge/features/goals/presentation/goals_screen.dart';

import '../../fakes.dart';

void main() {
  Future<void> pumpGoals(WidgetTester tester, AppDatabase db) async {
    final areasRemote = FakeAreasRemote()
      ..putError = const SyncNetworkException();
    final goalsRemote = FakeGoalsRemote()
      ..putError = const SyncNetworkException();
    final actionsRemote = FakeGoalActionsRemote()
      ..putError = const SyncNetworkException();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          areasRemoteProvider.overrideWithValue(areasRemote),
          goalsRemoteProvider.overrideWithValue(goalsRemote),
          goalActionsRemoteProvider.overrideWithValue(actionsRemote),
          connectivityStreamProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
        child: MaterialApp(theme: buildForgeTheme(), home: const GoalsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows empty state with CTA when there are no goals', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await pumpGoals(tester, db);

    expect(find.text('0 metas activas'), findsOneWidget);
    expect(find.text('Aún no tienes metas'), findsOneWidget);
    expect(find.text('Crear meta'), findsOneWidget);
  });

  testWidgets(
    'groups goals by area in position order, filters with chips, and restores with Todas',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final salud = await areaRepo.create(name: 'Salud', color: '#E07A5F');
      final carrera = await areaRepo.create(name: 'Carrera', color: '#D4A373');

      await goalRepo.upsert(
        areaId: carrera.id,
        title: 'Conseguir trabajo',
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );
      await goalRepo.upsert(
        areaId: salud.id,
        title: 'Correr 10 km',
        metricCurrent: 6,
        metricTarget: 10,
        metricUnit: 'km',
        weeklyHoursTarget: 4.5,
      );

      await pumpGoals(tester, db);

      expect(find.text('2 metas activas'), findsOneWidget);

      // Section headers ordered by area position (Salud at 0, Carrera at 1).
      final saludHeader = find.text('SALUD');
      final carreraHeader = find.text('CARRERA');
      expect(saludHeader, findsOneWidget);
      expect(carreraHeader, findsOneWidget);
      expect(
        tester.getTopLeft(saludHeader).dy,
        lessThan(tester.getTopLeft(carreraHeader).dy),
      );

      // Card shows area name alongside title, metric without decimals, %, and weekly hours.
      final goalCards = find.byType(GoalCard);
      expect(goalCards, findsNWidgets(2));
      expect(
        find.descendant(of: goalCards.first, matching: find.text('Salud')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: goalCards.last, matching: find.text('Carrera')),
        findsOneWidget,
      );
      expect(find.text('Correr 10 km'), findsOneWidget);
      expect(find.text('6 de 10 km'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('4 h 30 min por semana'), findsOneWidget);

      expect(find.text('Conseguir trabajo'), findsOneWidget);
      expect(find.text('3 de 10 entrevistas'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('6 h por semana'), findsOneWidget);

      // Tapping a card does nothing yet (T6 adds detail).
      await tester.tap(find.text('Correr 10 km'));
      await tester.pumpAndSettle();
      expect(find.byType(GoalCard), findsNWidgets(2));

      // Filter by Carrera chip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Carrera'));
      await tester.pumpAndSettle();

      expect(find.text('Conseguir trabajo'), findsOneWidget);
      expect(find.text('Correr 10 km'), findsNothing);

      // Restore all with Todas chip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
      await tester.pumpAndSettle();

      expect(find.text('Conseguir trabajo'), findsOneWidget);
      expect(find.text('Correr 10 km'), findsOneWidget);
    },
  );

  testWidgets(
    'shows 0% when target is 0 and shows Meta cumplida badge in positive color',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final finanzas = await areaRepo.create(
        name: 'Finanzas',
        color: '#81B29A',
      );
      await goalRepo.upsert(
        areaId: finanzas.id,
        title: 'Meta sin objetivo numérico',
        metricCurrent: 2,
        metricTarget: 0,
        metricUnit: 'ahorros',
        weeklyHoursTarget: 2,
      );
      await goalRepo.upsert(
        areaId: finanzas.id,
        title: 'Fondo de emergencia',
        metricCurrent: 3000,
        metricTarget: 3000,
        metricUnit: 'USD',
        weeklyHoursTarget: 1,
        status: GoalStatus.completed,
      );

      await pumpGoals(tester, db);

      expect(find.text('1 meta activa'), findsOneWidget);
      expect(find.text('2 de 0 ahorros'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      expect(find.text('Meta cumplida'), findsOneWidget);
      final badgeText = tester.widget<Text>(find.text('Meta cumplida'));
      expect(badgeText.style?.color, ForgeColors.positive);
    },
  );

  testWidgets(
    'Nueva meta form validates inline in Spanish and saves a new goal into the list',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      await areaRepo.create(name: 'Salud', color: '#E07A5F');
      await areaRepo.create(name: 'Carrera', color: '#D4A373');

      await pumpGoals(tester, db);

      // Open form from FAB.
      await tester.tap(find.text('Nueva meta'));
      await tester.pumpAndSettle();

      // Submit empty form to trigger inline Spanish validation.
      final saveButton = find.widgetWithText(FilledButton, 'Guardar meta');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Elige un área.'), findsOneWidget);
      expect(find.text('Ingresa un título.'), findsOneWidget);
      expect(find.text('Debe ser mayor que 0.'), findsOneWidget);
      expect(find.text('Ingresa una unidad.'), findsOneWidget);
      expect(find.text('Ingresa las horas semanales.'), findsOneWidget);

      // Select area, enter valid values, and test target <= 0 & negative hours first.
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carrera').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Dominar Flutter',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Por qué importa (opcional)'),
        'Construir LifeForge',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objetivo numérico'),
        '0',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Unidad'),
        'proyectos',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Horas por semana'),
        '-1',
      );

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Debe ser mayor que 0.'), findsOneWidget);
      expect(find.text('Debe ser 0 o mayor.'), findsOneWidget);

      // Fix invalid numbers and save.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Avance actual'),
        '1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objetivo numérico'),
        '4',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Horas por semana'),
        '8',
      );

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Returned to GoalsScreen and new goal appears with outbox entry.
      expect(find.text('Dominar Flutter'), findsOneWidget);
      expect(find.text('1 de 4 proyectos'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('8 h por semana'), findsOneWidget);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox.any((e) => e.entity == 'goal'), isTrue);
    },
  );

  testWidgets('Nueva meta preselects the active area filter chip', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final areaRepo = DriftAreaRepository(db);
    final goalRepo = DriftGoalRepository(db);

    final salud = await areaRepo.create(name: 'Salud', color: '#E07A5F');
    await areaRepo.create(name: 'Carrera', color: '#D4A373');
    await goalRepo.upsert(
      areaId: salud.id,
      title: 'Dormir 8 horas',
      metricCurrent: 2,
      metricTarget: 7,
      metricUnit: 'días',
      weeklyHoursTarget: 0,
    );

    await pumpGoals(tester, db);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Salud'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nueva meta'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título'),
      'Tomar agua',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Objetivo numérico'),
      '7',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unidad'),
      'días',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Horas por semana'),
      '1',
    );

    final saveButton = find.widgetWithText(FilledButton, 'Guardar meta');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Tomar agua'), findsOneWidget);
  });

  testWidgets(
    'clamps percentages > 100% and renders optional why and target date',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final ocio = await areaRepo.create(name: 'Ocio', color: '#A88BD9');
      await goalRepo.upsert(
        areaId: ocio.id,
        title: 'Leer 12 libros',
        why: 'Disfrutar la lectura',
        targetDate: DateTime.utc(2027, 3, 1),
        metricCurrent: 15,
        metricTarget: 12,
        metricUnit: 'libros',
        weeklyHoursTarget: 0.5,
      );

      await pumpGoals(tester, db);

      expect(find.text('Disfrutar la lectura'), findsOneWidget);
      expect(find.text('Objetivo: 1 mar 2027'), findsOneWidget);
      expect(find.text('15 de 12 libros'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('30 min por semana'), findsOneWidget);
    },
  );
}
