import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/goal_action.dart';
import '../domain/goal_action_repository.dart';

/// Drift-backed implementation of [GoalActionRepository].
class DriftGoalActionRepository implements GoalActionRepository {
  DriftGoalActionRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    void Function()? onWrite,
  }) : _clock = clock ?? _utcNow,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _onWrite = onWrite;

  static const entityName = 'goal_action';

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final void Function()? _onWrite;

  static DateTime _utcNow() => DateTime.now().toUtc();

  DateTime _nowUtc() => _clock().toUtc();

  @override
  Stream<List<GoalAction>> watchByGoal(String goalId) {
    final query = _db.customSelect(
      '''
      SELECT a.id,
             a.goal_id,
             a.title,
             a.kind,
             a.done,
             a.position,
             a.updated_at,
             a.deleted_at,
             a.server_updated_at,
             EXISTS (
               SELECT 1 FROM sync_outbox o
               WHERE o.entity = ? AND o.entity_id = a.id
             ) AS pending_sync
      FROM goal_actions a
      WHERE a.goal_id = ? AND a.deleted_at IS NULL
      ORDER BY a.position ASC, a.id ASC
      ''',
      variables: [Variable.withString(entityName), Variable.withString(goalId)],
      readsFrom: {_db.goalActions, _db.syncOutbox},
    );
    return query.watch().map((rows) => rows.map(_rowToAction).toList());
  }

  @override
  Future<GoalAction> upsert({
    String? id,
    required String goalId,
    required String title,
    required GoalActionKind kind,
    bool done = false,
    int? position,
  }) async {
    final now = _nowUtc();
    final nowIso = now.toIso8601String();
    final actionId = id ?? _idGenerator();

    final action = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.goalActions,
      )..where((t) => t.id.equals(actionId))).getSingleOrNull();

      final int resolvedPosition;
      if (position != null) {
        resolvedPosition = position;
      } else if (existing != null) {
        resolvedPosition = existing.position;
      } else {
        final maxPosExp = _db.goalActions.position.max();
        final posQuery = _db.selectOnly(_db.goalActions)
          ..addColumns([maxPosExp])
          ..where(_db.goalActions.goalId.equals(goalId));
        final posRow = await posQuery.getSingle();
        resolvedPosition = (posRow.read(maxPosExp) ?? -1) + 1;
      }

      if (existing == null) {
        await _db
            .into(_db.goalActions)
            .insert(
              GoalActionsCompanion.insert(
                id: actionId,
                goalId: goalId,
                title: title,
                kind: kind.value,
                done: done,
                position: resolvedPosition,
                updatedAt: nowIso,
              ),
            );
      } else {
        await (_db.update(
          _db.goalActions,
        )..where((t) => t.id.equals(actionId))).write(
          GoalActionsCompanion(
            goalId: Value(goalId),
            title: Value(title),
            kind: Value(kind.value),
            done: Value(done),
            position: Value(resolvedPosition),
            updatedAt: Value(nowIso),
            deletedAt: const Value(null),
          ),
        );
      }

      await _db.enqueueOutbox(
        entity: entityName,
        entityId: actionId,
        createdAt: nowIso,
      );

      final serverUpdatedAt = existing?.serverUpdatedAt;
      return GoalAction(
        id: actionId,
        goalId: goalId,
        title: title,
        kind: kind,
        done: done,
        position: resolvedPosition,
        updatedAt: now,
        serverUpdatedAt: serverUpdatedAt == null
            ? null
            : DateTime.parse(serverUpdatedAt).toUtc(),
        pendingSync: true,
      );
    });
    _onWrite?.call();
    return action;
  }

  @override
  Future<void> delete(String id) async {
    final nowIso = _nowUtc().toIso8601String();
    var wrote = false;
    await _db.transaction(() async {
      final count =
          await (_db.update(
            _db.goalActions,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            GoalActionsCompanion(
              deletedAt: Value(nowIso),
              updatedAt: Value(nowIso),
            ),
          );
      if (count > 0) {
        wrote = true;
        await _db.enqueueOutbox(
          entity: entityName,
          entityId: id,
          createdAt: nowIso,
        );
      }
    });
    if (wrote) _onWrite?.call();
  }

  GoalAction _rowToAction(QueryRow row) {
    final deletedAt = row.readNullable<String>('deleted_at');
    final serverUpdatedAt = row.readNullable<String>('server_updated_at');
    return GoalAction(
      id: row.read<String>('id'),
      goalId: row.read<String>('goal_id'),
      title: row.read<String>('title'),
      kind: GoalActionKind.fromValue(row.read<String>('kind')),
      done: row.read<bool>('done'),
      position: row.read<int>('position'),
      updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
      deletedAt: deletedAt == null ? null : DateTime.parse(deletedAt).toUtc(),
      serverUpdatedAt: serverUpdatedAt == null
          ? null
          : DateTime.parse(serverUpdatedAt).toUtc(),
      pendingSync: row.read<bool>('pending_sync'),
    );
  }
}
