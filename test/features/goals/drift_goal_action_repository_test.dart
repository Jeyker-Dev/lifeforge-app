import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/features/goals/data/drift_goal_action_repository.dart';
import 'package:lifeforge/features/goals/domain/goal_action.dart';

void main() {
  late AppDatabase db;
  late DriftGoalActionRepository repo;
  late DateTime now;
  int idSeq = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 25, 12);
    idSeq = 0;
    repo = DriftGoalActionRepository(
      db,
      clock: () => now,
      idGenerator: () => 'action-${++idSeq}',
    );
  });

  tearDown(() => db.close());

  test(
    'upsert creates action with UTC updated_at and enqueues outbox entry',
    () async {
      final created = await repo.upsert(
        goalId: 'goal-1',
        title: 'Actualizar CV',
        kind: GoalActionKind.task,
      );

      expect(created.id, 'action-1');
      expect(created.goalId, 'goal-1');
      expect(created.title, 'Actualizar CV');
      expect(created.kind, GoalActionKind.task);
      expect(created.done, isFalse);
      expect(created.position, 0);
      expect(created.updatedAt, now);
      expect(created.deletedAt, isNull);
      expect(created.serverUpdatedAt, isNull);
      expect(created.pendingSync, isTrue);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'goal_action');
      expect(outbox.single.entityId, 'action-1');
    },
  );

  test(
    'watchByGoal orders by position, supports updates, and hides soft-deleted actions',
    () async {
      final third = await repo.upsert(
        goalId: 'goal-1',
        title: 'Hito 3',
        kind: GoalActionKind.milestone,
        position: 2,
      );
      final first = await repo.upsert(
        goalId: 'goal-1',
        title: 'Paso 1',
        kind: GoalActionKind.task,
        position: 0,
      );
      final second = await repo.upsert(
        goalId: 'goal-1',
        title: 'Paso 2',
        kind: GoalActionKind.task,
        position: 1,
      );
      await repo.upsert(
        goalId: 'goal-2',
        title: 'Otra meta',
        kind: GoalActionKind.task,
      );

      final watched = await repo.watchByGoal('goal-1').first;
      expect(watched.map((a) => a.id), [first.id, second.id, third.id]);

      now = now.add(const Duration(minutes: 2));
      final updated = await repo.upsert(
        id: first.id,
        goalId: 'goal-1',
        title: 'Paso 1 listo',
        kind: GoalActionKind.task,
        done: true,
      );
      expect(updated.position, 0);
      expect(updated.done, isTrue);

      now = now.add(const Duration(minutes: 3));
      await repo.delete(second.id);

      final afterDelete = await repo.watchByGoal('goal-1').first;
      expect(afterDelete.map((a) => a.id), [first.id, third.id]);

      final deletedRow = await (db.select(
        db.goalActions,
      )..where((t) => t.id.equals(second.id))).getSingle();
      expect(deletedRow.deletedAt, now.toIso8601String());
      expect(deletedRow.updatedAt, now.toIso8601String());
    },
  );

  test(
    'upsert without position appends new action after existing max position',
    () async {
      final first = await repo.upsert(
        goalId: 'goal-1',
        title: 'Paso 1',
        kind: GoalActionKind.task,
      );
      final jumped = await repo.upsert(
        goalId: 'goal-1',
        title: 'Paso saltado',
        kind: GoalActionKind.milestone,
        position: 4,
      );
      final appended = await repo.upsert(
        goalId: 'goal-1',
        title: 'Paso final',
        kind: GoalActionKind.task,
      );

      expect(first.position, 0);
      expect(jumped.position, 4);
      expect(appended.position, 5);

      final watched = await repo.watchByGoal('goal-1').first;
      expect(watched.map((a) => a.id), [first.id, jumped.id, appended.id]);
    },
  );

  test(
    'reorder rewrites positions in one transaction and enqueues only moved actions',
    () async {
      final a1 = await repo.upsert(
        goalId: 'goal-1',
        title: 'Acción 1',
        kind: GoalActionKind.task,
      );
      final a2 = await repo.upsert(
        goalId: 'goal-1',
        title: 'Acción 2',
        kind: GoalActionKind.task,
      );
      final a3 = await repo.upsert(
        goalId: 'goal-1',
        title: 'Acción 3',
        kind: GoalActionKind.milestone,
      );

      await db.delete(db.syncOutbox).go();

      final reorderTime = now.add(const Duration(minutes: 10));
      now = reorderTime;

      // Move a2 before a1 while leaving a3 at position 2.
      await repo.reorder('goal-1', [a2.id, a1.id, a3.id]);

      final watched = await repo.watchByGoal('goal-1').first;
      expect(watched.map((a) => a.id), [a2.id, a1.id, a3.id]);
      expect(watched.map((a) => a.position), [0, 1, 2]);
      expect(watched[0].updatedAt, reorderTime);
      expect(watched[1].updatedAt, reorderTime);
      expect(watched[2].updatedAt, DateTime.utc(2026, 11, 25, 12));

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(2));
      expect(outbox.every((e) => e.entity == 'goal_action'), isTrue);
      expect(outbox.map((e) => e.entityId), unorderedEquals([a1.id, a2.id]));

      // Reordering with identical order leaves timestamps and outbox untouched.
      await db.delete(db.syncOutbox).go();
      now = now.add(const Duration(minutes: 5));
      await repo.reorder('goal-1', [a2.id, a1.id, a3.id]);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );
}
