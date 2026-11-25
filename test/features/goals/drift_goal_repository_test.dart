import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/features/goals/data/drift_goal_action_repository.dart';
import 'package:lifeforge/features/goals/data/drift_goal_repository.dart';
import 'package:lifeforge/features/goals/domain/goal.dart';
import 'package:lifeforge/features/goals/domain/goal_action.dart';

void main() {
  late AppDatabase db;
  late DriftGoalRepository goalRepo;
  late DriftGoalActionRepository actionRepo;
  late DateTime now;
  int goalSeq = 0;
  int actionSeq = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 25, 12);
    goalSeq = 0;
    actionSeq = 0;
    goalRepo = DriftGoalRepository(
      db,
      clock: () => now,
      idGenerator: () => 'goal-${++goalSeq}',
    );
    actionRepo = DriftGoalActionRepository(
      db,
      clock: () => now,
      idGenerator: () => 'action-${++actionSeq}',
    );
  });

  tearDown(() => db.close());

  test(
    'upsert creates goal with UTC updated_at and enqueues outbox entry',
    () async {
      final targetDate = DateTime.utc(2027, 3, 1);
      final created = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Conseguir trabajo',
        why: 'Crecimiento profesional',
        targetDate: targetDate,
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 8.5,
      );

      expect(created.id, 'goal-1');
      expect(created.areaId, 'area-1');
      expect(created.title, 'Conseguir trabajo');
      expect(created.why, 'Crecimiento profesional');
      expect(created.targetDate, targetDate);
      expect(created.metricCurrent, 3);
      expect(created.metricTarget, 10);
      expect(created.metricUnit, 'entrevistas');
      expect(created.weeklyHoursTarget, 8.5);
      expect(created.status, GoalStatus.active);
      expect(created.updatedAt, now);
      expect(created.deletedAt, isNull);
      expect(created.serverUpdatedAt, isNull);
      expect(created.pendingSync, isTrue);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'goal');
      expect(outbox.single.entityId, 'goal-1');
    },
  );

  test(
    'upsert updates existing goal, preserves serverUpdatedAt, and enqueues outbox',
    () async {
      final created = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Conseguir trabajo',
        metricCurrent: 1,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );
      await (db.update(db.goals)..where((t) => t.id.equals(created.id))).write(
        const GoalsCompanion(
          serverUpdatedAt: Value('2026-11-25T12:01:00.000Z'),
        ),
      );

      now = now.add(const Duration(minutes: 5));
      final updated = await goalRepo.upsert(
        id: created.id,
        areaId: 'area-1',
        title: 'Conseguir trabajo backend',
        why: 'Estabilidad',
        targetDate: DateTime.utc(2027, 4, 15),
        metricCurrent: 4,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 10,
        status: GoalStatus.completed,
      );

      expect(updated.title, 'Conseguir trabajo backend');
      expect(updated.status, GoalStatus.completed);
      expect(updated.metricCurrent, 4);
      expect(updated.updatedAt, now);
      expect(updated.serverUpdatedAt, DateTime.utc(2026, 11, 25, 12, 1));
      expect(updated.pendingSync, isTrue);

      final watched = await goalRepo.watchByArea('area-1').first;
      expect(watched, [updated]);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(2));
      expect(outbox.every((e) => e.entity == 'goal'), isTrue);
    },
  );

  test(
    'watchByArea filters by areaId and excludes soft-deleted goals',
    () async {
      final g1 = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Meta 1',
        metricCurrent: 0,
        metricTarget: 5,
        metricUnit: 'pasos',
        weeklyHoursTarget: 3,
      );
      await goalRepo.upsert(
        areaId: 'area-2',
        title: 'Meta otra área',
        metricCurrent: 0,
        metricTarget: 5,
        metricUnit: 'pasos',
        weeklyHoursTarget: 2,
      );
      final g3 = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Meta 2',
        metricCurrent: 1,
        metricTarget: 5,
        metricUnit: 'pasos',
        weeklyHoursTarget: 4,
      );

      expect((await goalRepo.watchByArea('area-1').first).map((g) => g.id), [
        g1.id,
        g3.id,
      ]);

      now = now.add(const Duration(minutes: 2));
      await goalRepo.delete(g1.id);

      expect((await goalRepo.watchByArea('area-1').first).map((g) => g.id), [
        g3.id,
      ]);
    },
  );

  test(
    'watchAll returns all active goals across areas and excludes soft-deleted ones',
    () async {
      final g1 = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Meta Salud',
        metricCurrent: 1,
        metricTarget: 5,
        metricUnit: 'km',
        weeklyHoursTarget: 3,
      );
      now = now.add(const Duration(minutes: 1));
      final g2 = await goalRepo.upsert(
        areaId: 'area-2',
        title: 'Meta Carrera',
        metricCurrent: 3,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 6,
      );
      now = now.add(const Duration(minutes: 1));
      final g3 = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Meta borrada',
        metricCurrent: 0,
        metricTarget: 2,
        metricUnit: 'sesiones',
        weeklyHoursTarget: 1,
      );

      now = now.add(const Duration(minutes: 1));
      await goalRepo.delete(g3.id);

      final watched = await goalRepo.watchAll().first;
      expect(watched.map((g) => g.id), [g1.id, g2.id]);
      expect(watched.every((g) => g.pendingSync), isTrue);
    },
  );

  test(
    'delete soft-deletes the goal and cascades to active actions with separate outbox entries (A1)',
    () async {
      final goal = await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Conseguir trabajo',
        metricCurrent: 0,
        metricTarget: 10,
        metricUnit: 'entrevistas',
        weeklyHoursTarget: 8,
      );
      final a1 = await actionRepo.upsert(
        goalId: goal.id,
        title: 'Actualizar CV',
        kind: GoalActionKind.task,
      );
      final a2 = await actionRepo.upsert(
        goalId: goal.id,
        title: 'Primera oferta',
        kind: GoalActionKind.milestone,
      );
      final alreadyDeletedAction = await actionRepo.upsert(
        goalId: goal.id,
        title: 'Vieja acción',
        kind: GoalActionKind.task,
      );
      final deletedEarlier = now.add(const Duration(minutes: 1));
      now = deletedEarlier;
      await actionRepo.delete(alreadyDeletedAction.id);

      // Clear prior outbox entries so we assert exactly the entries produced by delete().
      await db.delete(db.syncOutbox).go();

      final deleteTime = now.add(const Duration(minutes: 5));
      now = deleteTime;
      await goalRepo.delete(goal.id);

      expect(await goalRepo.watchByArea('area-1').first, isEmpty);
      expect(await actionRepo.watchByGoal(goal.id).first, isEmpty);

      final goalRow = await (db.select(
        db.goals,
      )..where((t) => t.id.equals(goal.id))).getSingle();
      expect(goalRow.deletedAt, deleteTime.toIso8601String());
      expect(goalRow.updatedAt, deleteTime.toIso8601String());

      final actionRows = await (db.select(
        db.goalActions,
      )..where((t) => t.goalId.equals(goal.id))).get();
      final byId = {for (final r in actionRows) r.id: r};
      expect(byId[a1.id]!.deletedAt, deleteTime.toIso8601String());
      expect(byId[a2.id]!.deletedAt, deleteTime.toIso8601String());
      expect(
        byId[alreadyDeletedAction.id]!.deletedAt,
        deletedEarlier.toIso8601String(),
      );

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(3));
      expect(
        outbox.map((e) => (e.entity, e.entityId)),
        unorderedEquals([
          ('goal', goal.id),
          ('goal_action', a1.id),
          ('goal_action', a2.id),
        ]),
      );
    },
  );
}
