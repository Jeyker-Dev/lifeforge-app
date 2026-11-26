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
import 'package:lifeforge/features/goals/data/drift_goal_action_repository.dart';
import 'package:lifeforge/features/goals/data/drift_goal_repository.dart';
import 'package:lifeforge/features/goals/domain/goal.dart';
import 'package:lifeforge/features/goals/presentation/goal_detail_screen.dart';

import '../../fakes.dart';

void main() {
  Future<void> pumpDetail(
    WidgetTester tester,
    AppDatabase db,
    String goalId,
  ) async {
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
        child: MaterialApp(
          theme: buildForgeTheme(),
          home: GoalDetailScreen(goalId: goalId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'shows header, metric, weekly hours, target date, and hides out-of-scope S7 sections',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final carrera = await areaRepo.create(name: 'Carrera', color: '#D4A373');
      final goal = await goalRepo.upsert(
        areaId: carrera.id,
        title: 'Conseguir trabajo',
        why: 'Crecer profesionalmente',
        targetDate: DateTime.utc(2027, 3, 1),
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );

      await pumpDetail(tester, db, goal.id);

      expect(find.text('Conseguir trabajo'), findsOneWidget);
      expect(find.text('Carrera'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);
      expect(find.text('3 de 10 entrevistas'), findsOneWidget);
      expect(find.text('30%'), findsOneWidget);
      expect(find.text('6 h por semana'), findsOneWidget);
      expect(find.text('Objetivo: 1 mar 2027'), findsOneWidget);
      expect(find.text('Por qué importa'), findsOneWidget);
      expect(find.text('Crecer profesionalmente'), findsOneWidget);

      // Out of scope per S7.
      expect(find.text('Tiempo esta semana'), findsNothing);
      expect(find.text('Últimas 6 semanas'), findsNothing);
      expect(find.text('Planificar bloque'), findsNothing);
      expect(find.textContaining('Hábito'), findsNothing);
      expect(find.textContaining('Hoy 14:00'), findsNothing);
    },
  );

  testWidgets('hides Por qué importa when empty or null', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final areaRepo = DriftAreaRepository(db);
    final goalRepo = DriftGoalRepository(db);

    final salud = await areaRepo.create(name: 'Salud', color: '#E07A5F');
    final goal = await goalRepo.upsert(
      areaId: salud.id,
      title: 'Correr 10 km',
      why: '   ',
      metricCurrent: 2,
      metricTarget: 10,
      metricUnit: 'km',
      weeklyHoursTarget: 3,
    );

    await pumpDetail(tester, db, goal.id);

    expect(find.text('Por qué importa'), findsNothing);
  });

  testWidgets(
    'Registrar avance prefils current value, rejects negative or empty, and updates metric and percentage',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final carrera = await areaRepo.create(name: 'Carrera', color: '#D4A373');
      final goal = await goalRepo.upsert(
        areaId: carrera.id,
        title: 'Conseguir trabajo',
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );

      await pumpDetail(tester, db, goal.id);

      await tester.tap(find.text('Registrar avance'));
      await tester.pumpAndSettle();

      // Prefilled with current value.
      final field = tester.widget<TextFormField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
      );
      expect(field.controller?.text, '3');

      // Empty value rejected.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un valor.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Negative value rejected.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '-2',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa 0 o mayor.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      // Valid value updates metric and percentage.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '7',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('7 de 10 entrevistas'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
    },
  );

  testWidgets(
    'action plan supports adding task and milestone, toggling done, reordering, and deleting',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);
      final actionRepo = DriftGoalActionRepository(db);

      final carrera = await areaRepo.create(name: 'Carrera', color: '#D4A373');
      final goal = await goalRepo.upsert(
        areaId: carrera.id,
        title: 'Conseguir trabajo',
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );

      await pumpDetail(tester, db, goal.id);

      // Add a task.
      await tester.ensureVisible(find.text('Agregar acción'));
      await tester.tap(find.text('Agregar acción'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Actualizar CV y portafolio',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(find.text('Actualizar CV y portafolio'), findsOneWidget);
      expect(find.text('Hito'), findsNothing);

      // Add a milestone.
      await tester.ensureVisible(find.text('Agregar acción'));
      await tester.tap(find.text('Agregar acción'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        'Primera entrevista técnica',
      );
      await tester.tap(find.text('Hito'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(find.text('Primera entrevista técnica'), findsOneWidget);
      expect(find.text('Hito'), findsOneWidget);

      // Title allows up to 2 lines (never truncated to 1 line).
      final actionTitle = tester.widget<Text>(
        find.text('Actualizar CV y portafolio'),
      );
      expect(actionTitle.maxLines, 2);

      // Toggle done and back to undone on first action.
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      var actions = await actionRepo.watchByGoal(goal.id).first;
      expect(actions[0].done, isTrue);
      expect(actions[1].done, isFalse);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      actions = await actionRepo.watchByGoal(goal.id).first;
      expect(actions[0].done, isFalse);

      // Reorder: drag first handle down below second item.
      final firstHandle = find.byIcon(Icons.drag_handle).first;
      await tester.ensureVisible(firstHandle);
      await tester.timedDrag(
        firstHandle,
        const Offset(0, 100),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();

      actions = await actionRepo.watchByGoal(goal.id).first;
      expect(actions.map((a) => a.title), [
        'Primera entrevista técnica',
        'Actualizar CV y portafolio',
      ]);

      // Delete first action with confirmation (cancel first, then confirm).
      await tester.tap(find.byTooltip('Eliminar acción').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Primera entrevista técnica'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar acción').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Primera entrevista técnica'), findsNothing);
      expect(find.text('Actualizar CV y portafolio'), findsOneWidget);
    },
  );

  testWidgets(
    'edits goal through reused form and toggles Marcar cumplida / Reactivar',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final areaRepo = DriftAreaRepository(db);
      final goalRepo = DriftGoalRepository(db);

      final carrera = await areaRepo.create(name: 'Carrera', color: '#D4A373');
      final goal = await goalRepo.upsert(
        areaId: carrera.id,
        title: 'Conseguir trabajo',
        why: 'Crecer',
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );

      await pumpDetail(tester, db, goal.id);

      // Edit goal through reused form.
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar meta'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Título'),
        'Conseguir trabajo remoto',
      );
      final saveButton = find.widgetWithText(FilledButton, 'Guardar cambios');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Conseguir trabajo remoto'), findsOneWidget);

      // Marcar cumplida.
      await tester.tap(find.byTooltip('Opciones de meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marcar cumplida'));
      await tester.pumpAndSettle();

      expect(find.text('Meta cumplida'), findsOneWidget);
      var savedGoal = (await goalRepo.watchAll().first).single;
      expect(savedGoal.status, GoalStatus.completed);

      // Reactivar.
      await tester.tap(find.byTooltip('Opciones de meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reactivar'));
      await tester.pumpAndSettle();

      expect(find.text('Activa'), findsOneWidget);
      savedGoal = (await goalRepo.watchAll().first).single;
      expect(savedGoal.status, GoalStatus.active);
    },
  );
}
