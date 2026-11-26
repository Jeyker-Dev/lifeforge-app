import 'package:drift/drift.dart';

import '../../features/areas/data/areas_remote.dart';
import '../../features/areas/data/drift_area_repository.dart';
import '../../features/areas/domain/area_defaults.dart';
import '../../features/areas/domain/area_repository.dart';
import '../../features/goals/data/drift_goal_action_repository.dart';
import '../../features/goals/data/drift_goal_repository.dart';
import '../../features/goals/data/goal_actions_remote.dart';
import '../../features/goals/data/goals_remote.dart';
import '../db/app_database.dart';

enum _PullOutcome { succeeded, clientError, networkError }

/// Synchronizes local areas, goals, and goal actions with the LifeForge API
/// using a push-then-pull flow.
///
/// Only one sync runs at a time; concurrent callers share the in-flight run.
class SyncService {
  SyncService(
    this._db,
    this._areasRemote, {
    GoalsRemote? goalsRemote,
    GoalActionsRemote? goalActionsRemote,
    AreaRepository? areaRepository,
  }) : _goalsRemote = goalsRemote,
       _goalActionsRemote = goalActionsRemote,
       _areaRepository = areaRepository ?? DriftAreaRepository(_db);

  static const _areaEntity = DriftAreaRepository.entityName;
  static const _goalEntity = DriftGoalRepository.entityName;
  static const _goalActionEntity = DriftGoalActionRepository.entityName;

  final AppDatabase _db;
  final AreasRemote _areasRemote;
  final GoalsRemote? _goalsRemote;
  final GoalActionsRemote? _goalActionsRemote;
  final AreaRepository _areaRepository;
  Future<void>? _inFlight;

  /// Pushes queued local changes and pulls remote changes in order:
  /// areas, goals, goal actions.
  Future<void> syncAll() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  /// Alias for [syncAll] kept for existing area-sync callers.
  Future<void> syncAreas() => syncAll();

  Future<void> _run() async {
    if (!await _pushAreas()) return;
    if (!await _pushGoals()) return;
    if (!await _pushGoalActions()) return;

    final areaPull = await _pullAreas();
    if (areaPull == _PullOutcome.networkError) return;
    if (areaPull == _PullOutcome.succeeded) {
      final seeded = await _seedDefaultAreasIfNeeded();
      if (seeded && !await _pushAreas()) return;
    }

    if (await _pullGoals() == _PullOutcome.networkError) return;
    await _pullGoalActions();
  }

  Future<bool> _pushAreas() => _pushEntity<AreaRow, RemoteArea>(
    entity: _areaEntity,
    findLocal: (id) => (_db.select(
      _db.areas,
    )..where((t) => t.id.equals(id))).getSingleOrNull(),
    pushRemote: (row) => _areasRemote.putArea(
      AreaPushPayload(
        id: row.id,
        name: row.name,
        color: row.color,
        position: row.position,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      ),
    ),
    upsertRemote: _upsertRemoteArea,
  );

  Future<bool> _pushGoals() {
    final remote = _goalsRemote;
    if (remote == null) return Future.value(true);
    return _pushEntity<GoalRow, RemoteGoal>(
      entity: _goalEntity,
      findLocal: (id) => (_db.select(
        _db.goals,
      )..where((t) => t.id.equals(id))).getSingleOrNull(),
      pushRemote: (row) => remote.putGoal(
        GoalPushPayload(
          id: row.id,
          areaId: row.areaId,
          title: row.title,
          why: row.why,
          targetDate: row.targetDate,
          metricCurrent: row.metricCurrent,
          metricTarget: row.metricTarget,
          metricUnit: row.metricUnit,
          weeklyHoursTarget: row.weeklyHoursTarget,
          status: row.status,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
        ),
      ),
      upsertRemote: _upsertRemoteGoal,
    );
  }

  Future<bool> _pushGoalActions() {
    final remote = _goalActionsRemote;
    if (remote == null) return Future.value(true);
    return _pushEntity<GoalActionRow, RemoteGoalAction>(
      entity: _goalActionEntity,
      findLocal: (id) => (_db.select(
        _db.goalActions,
      )..where((t) => t.id.equals(id))).getSingleOrNull(),
      pushRemote: (row) => remote.putGoalAction(
        GoalActionPushPayload(
          id: row.id,
          goalId: row.goalId,
          title: row.title,
          kind: row.kind,
          done: row.done,
          position: row.position,
          updatedAt: row.updatedAt,
          deletedAt: row.deletedAt,
        ),
      ),
      upsertRemote: _upsertRemoteGoalAction,
    );
  }

  Future<_PullOutcome> _pullAreas() => _pullEntity<RemoteArea>(
    entity: _areaEntity,
    pullRemote: (since) async {
      final response = await _areasRemote.pullAreas(since: since);
      return (items: response.areas, cursor: response.cursor);
    },
    remoteId: (item) => item.id,
    remoteUpdatedAt: (item) => item.updatedAt,
    findLocalUpdatedAt: (id) async {
      final row = await (_db.select(
        _db.areas,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      return row?.updatedAt;
    },
    upsertRemote: _upsertRemoteArea,
  );

  /// Seeds the 5 default areas (A3) only when no areas exist at all (including
  /// soft-deleted rows) after a successful pull confirmed the server is empty.
  Future<bool> _seedDefaultAreasIfNeeded() async {
    final countExp = _db.areas.id.count();
    final countRow = await (_db.selectOnly(
      _db.areas,
    )..addColumns([countExp])).getSingle();
    final existingCount = countRow.read(countExp) ?? 0;
    if (existingCount > 0) return false;

    for (final spec in defaultLifeAreas) {
      await _areaRepository.create(name: spec.name, color: spec.color);
    }
    return true;
  }

  Future<_PullOutcome> _pullGoals() {
    final remote = _goalsRemote;
    if (remote == null) return Future.value(_PullOutcome.succeeded);
    return _pullEntity<RemoteGoal>(
      entity: _goalEntity,
      pullRemote: (since) async {
        final response = await remote.pullGoals(since: since);
        return (items: response.goals, cursor: response.cursor);
      },
      remoteId: (item) => item.id,
      remoteUpdatedAt: (item) => item.updatedAt,
      findLocalUpdatedAt: (id) async {
        final row = await (_db.select(
          _db.goals,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.updatedAt;
      },
      upsertRemote: _upsertRemoteGoal,
    );
  }

  Future<_PullOutcome> _pullGoalActions() {
    final remote = _goalActionsRemote;
    if (remote == null) return Future.value(_PullOutcome.succeeded);
    return _pullEntity<RemoteGoalAction>(
      entity: _goalActionEntity,
      pullRemote: (since) async {
        final response = await remote.pullGoalActions(since: since);
        return (items: response.goalActions, cursor: response.cursor);
      },
      remoteId: (item) => item.id,
      remoteUpdatedAt: (item) => item.updatedAt,
      findLocalUpdatedAt: (id) async {
        final row = await (_db.select(
          _db.goalActions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return row?.updatedAt;
      },
      upsertRemote: _upsertRemoteGoalAction,
    );
  }

  /// Pushes outbox entries for [entity] in creation order.
  ///
  /// Returns `false` if a network error interrupted the push so the caller skips
  /// remaining pushes and pulls until connectivity returns.
  Future<bool> _pushEntity<TRow, TRemote>({
    required String entity,
    required Future<TRow?> Function(String id) findLocal,
    required Future<TRemote> Function(TRow row) pushRemote,
    required Future<void> Function(TRemote canonical) upsertRemote,
  }) async {
    final entries =
        await (_db.select(_db.syncOutbox)
              ..where((t) => t.entity.equals(entity))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();

    for (final entry in entries) {
      final row = await findLocal(entry.entityId);
      if (row == null) {
        await _deleteOutboxEntry(entry.id);
        continue;
      }

      try {
        final canonical = await pushRemote(row);
        await _db.transaction(() async {
          await upsertRemote(canonical);
          await _deleteOutboxEntry(entry.id);
        });
      } on SyncNetworkException {
        return false;
      } on SyncClientException {
        // Drop the invalid outbox entry without logging sensitive data and keep
        // the local row untouched.
        await _deleteOutboxEntry(entry.id);
      }
    }
    return true;
  }

  /// Pulls remote changes for [entity] since its stored cursor using
  /// last-edit-wins (`updatedAt`): a strictly newer remote timestamp overwrites,
  /// while an older timestamp or tie keeps the local row.
  Future<_PullOutcome> _pullEntity<TRemote>({
    required String entity,
    required Future<({List<TRemote> items, String? cursor})> Function(
      String? since,
    )
    pullRemote,
    required String Function(TRemote item) remoteId,
    required String Function(TRemote item) remoteUpdatedAt,
    required Future<String?> Function(String id) findLocalUpdatedAt,
    required Future<void> Function(TRemote item) upsertRemote,
  }) async {
    final cursorRow = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.entity.equals(entity))).getSingleOrNull();

    final ({List<TRemote> items, String? cursor}) response;
    try {
      response = await pullRemote(cursorRow?.cursor);
    } on SyncNetworkException {
      return _PullOutcome.networkError;
    } on SyncClientException {
      return _PullOutcome.clientError;
    }

    await _db.transaction(() async {
      final pendingRows = await (_db.select(
        _db.syncOutbox,
      )..where((t) => t.entity.equals(entity))).get();
      final pendingIds = pendingRows.map((row) => row.entityId).toSet();

      for (final item in response.items) {
        final id = remoteId(item);
        if (pendingIds.contains(id)) continue;

        final localUpdatedAtStr = await findLocalUpdatedAt(id);
        if (localUpdatedAtStr != null) {
          final localUpdatedAt = DateTime.parse(localUpdatedAtStr).toUtc();
          final incomingUpdatedAt = DateTime.parse(
            remoteUpdatedAt(item),
          ).toUtc();
          if (!incomingUpdatedAt.isAfter(localUpdatedAt)) {
            continue;
          }
        }

        await upsertRemote(item);
      }

      final nextCursor = response.cursor;
      if (nextCursor != null) {
        await _db
            .into(_db.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(entity: entity, cursor: nextCursor),
            );
      }
    });
    return _PullOutcome.succeeded;
  }

  Future<void> _upsertRemoteArea(RemoteArea area) async {
    await _db
        .into(_db.areas)
        .insertOnConflictUpdate(
          AreasCompanion.insert(
            id: area.id,
            name: area.name,
            color: area.color,
            position: area.position,
            updatedAt: area.updatedAt,
            deletedAt: Value(area.deletedAt),
            serverUpdatedAt: Value(area.serverUpdatedAt),
          ),
        );
  }

  Future<void> _upsertRemoteGoal(RemoteGoal goal) async {
    await _db
        .into(_db.goals)
        .insertOnConflictUpdate(
          GoalsCompanion.insert(
            id: goal.id,
            areaId: goal.areaId,
            title: goal.title,
            why: Value(goal.why),
            targetDate: Value(goal.targetDate),
            metricCurrent: goal.metricCurrent,
            metricTarget: goal.metricTarget,
            metricUnit: goal.metricUnit,
            weeklyHoursTarget: goal.weeklyHoursTarget,
            status: goal.status,
            updatedAt: goal.updatedAt,
            deletedAt: Value(goal.deletedAt),
            serverUpdatedAt: Value(goal.serverUpdatedAt),
          ),
        );
  }

  Future<void> _upsertRemoteGoalAction(RemoteGoalAction action) async {
    await _db
        .into(_db.goalActions)
        .insertOnConflictUpdate(
          GoalActionsCompanion.insert(
            id: action.id,
            goalId: action.goalId,
            title: action.title,
            kind: action.kind,
            done: action.done,
            position: action.position,
            updatedAt: action.updatedAt,
            deletedAt: Value(action.deletedAt),
            serverUpdatedAt: Value(action.serverUpdatedAt),
          ),
        );
  }

  Future<void> _deleteOutboxEntry(int id) async {
    await (_db.delete(_db.syncOutbox)..where((t) => t.id.equals(id))).go();
  }
}
