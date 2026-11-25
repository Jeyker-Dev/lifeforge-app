import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/goal.dart';
import '../domain/goal_repository.dart';
import 'drift_goal_action_repository.dart';

/// Drift-backed implementation of [GoalRepository].
class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    void Function()? onWrite,
  }) : _clock = clock ?? _utcNow,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _onWrite = onWrite;

  static const entityName = 'goal';

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final void Function()? _onWrite;

  static DateTime _utcNow() => DateTime.now().toUtc();

  DateTime _nowUtc() => _clock().toUtc();

  @override
  Stream<List<Goal>> watchByArea(String areaId) {
    final query = _db.customSelect(
      '''
      SELECT g.id,
             g.area_id,
             g.title,
             g.why,
             g.target_date,
             g.metric_current,
             g.metric_target,
             g.metric_unit,
             g.weekly_hours_target,
             g.status,
             g.updated_at,
             g.deleted_at,
             g.server_updated_at,
             EXISTS (
               SELECT 1 FROM sync_outbox o
               WHERE o.entity = ? AND o.entity_id = g.id
             ) AS pending_sync
      FROM goals g
      WHERE g.area_id = ? AND g.deleted_at IS NULL
      ORDER BY g.updated_at ASC, g.id ASC
      ''',
      variables: [Variable.withString(entityName), Variable.withString(areaId)],
      readsFrom: {_db.goals, _db.syncOutbox},
    );
    return query.watch().map((rows) => rows.map(_rowToGoal).toList());
  }

  @override
  Future<Goal> upsert({
    String? id,
    required String areaId,
    required String title,
    String? why,
    DateTime? targetDate,
    required double metricCurrent,
    required double metricTarget,
    required String metricUnit,
    required double weeklyHoursTarget,
    GoalStatus status = GoalStatus.active,
  }) async {
    final now = _nowUtc();
    final nowIso = now.toIso8601String();
    final goalId = id ?? _idGenerator();
    final normalizedDate = targetDate == null
        ? null
        : DateTime.utc(targetDate.year, targetDate.month, targetDate.day);
    final targetDateStr = normalizedDate == null
        ? null
        : _formatDate(normalizedDate);

    final goal = await _db.transaction(() async {
      final existing = await (_db.select(
        _db.goals,
      )..where((t) => t.id.equals(goalId))).getSingleOrNull();

      if (existing == null) {
        await _db
            .into(_db.goals)
            .insert(
              GoalsCompanion.insert(
                id: goalId,
                areaId: areaId,
                title: title,
                why: Value(why),
                targetDate: Value(targetDateStr),
                metricCurrent: metricCurrent,
                metricTarget: metricTarget,
                metricUnit: metricUnit,
                weeklyHoursTarget: weeklyHoursTarget,
                status: status.value,
                updatedAt: nowIso,
              ),
            );
      } else {
        await (_db.update(_db.goals)..where((t) => t.id.equals(goalId))).write(
          GoalsCompanion(
            areaId: Value(areaId),
            title: Value(title),
            why: Value(why),
            targetDate: Value(targetDateStr),
            metricCurrent: Value(metricCurrent),
            metricTarget: Value(metricTarget),
            metricUnit: Value(metricUnit),
            weeklyHoursTarget: Value(weeklyHoursTarget),
            status: Value(status.value),
            updatedAt: Value(nowIso),
            deletedAt: const Value(null),
          ),
        );
      }

      await _db.enqueueOutbox(
        entity: entityName,
        entityId: goalId,
        createdAt: nowIso,
      );

      final serverUpdatedAt = existing?.serverUpdatedAt;
      return Goal(
        id: goalId,
        areaId: areaId,
        title: title,
        why: why,
        targetDate: normalizedDate,
        metricCurrent: metricCurrent,
        metricTarget: metricTarget,
        metricUnit: metricUnit,
        weeklyHoursTarget: weeklyHoursTarget,
        status: status,
        updatedAt: now,
        serverUpdatedAt: serverUpdatedAt == null
            ? null
            : DateTime.parse(serverUpdatedAt).toUtc(),
        pendingSync: true,
      );
    });
    _onWrite?.call();
    return goal;
  }

  @override
  Future<void> delete(String id) async {
    final nowIso = _nowUtc().toIso8601String();
    var wrote = false;
    await _db.transaction(() async {
      final count =
          await (_db.update(
            _db.goals,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            GoalsCompanion(deletedAt: Value(nowIso), updatedAt: Value(nowIso)),
          );
      if (count == 0) return;

      wrote = true;
      await _db.enqueueOutbox(
        entity: entityName,
        entityId: id,
        createdAt: nowIso,
      );

      final activeActions = await (_db.select(
        _db.goalActions,
      )..where((t) => t.goalId.equals(id) & t.deletedAt.isNull())).get();
      if (activeActions.isEmpty) return;

      await (_db.update(
        _db.goalActions,
      )..where((t) => t.goalId.equals(id) & t.deletedAt.isNull())).write(
        GoalActionsCompanion(
          deletedAt: Value(nowIso),
          updatedAt: Value(nowIso),
        ),
      );
      for (final action in activeActions) {
        await _db.enqueueOutbox(
          entity: DriftGoalActionRepository.entityName,
          entityId: action.id,
          createdAt: nowIso,
        );
      }
    });
    if (wrote) _onWrite?.call();
  }

  Goal _rowToGoal(QueryRow row) {
    final targetDate = row.readNullable<String>('target_date');
    final deletedAt = row.readNullable<String>('deleted_at');
    final serverUpdatedAt = row.readNullable<String>('server_updated_at');
    return Goal(
      id: row.read<String>('id'),
      areaId: row.read<String>('area_id'),
      title: row.read<String>('title'),
      why: row.readNullable<String>('why'),
      targetDate: targetDate == null ? null : _parseDate(targetDate),
      metricCurrent: row.read<double>('metric_current'),
      metricTarget: row.read<double>('metric_target'),
      metricUnit: row.read<String>('metric_unit'),
      weeklyHoursTarget: row.read<double>('weekly_hours_target'),
      status: GoalStatus.fromValue(row.read<String>('status')),
      updatedAt: DateTime.parse(row.read<String>('updated_at')).toUtc(),
      deletedAt: deletedAt == null ? null : DateTime.parse(deletedAt).toUtc(),
      serverUpdatedAt: serverUpdatedAt == null
          ? null
          : DateTime.parse(serverUpdatedAt).toUtc(),
      pendingSync: row.read<bool>('pending_sync'),
    );
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime _parseDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
