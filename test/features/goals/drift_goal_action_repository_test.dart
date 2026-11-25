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
}
