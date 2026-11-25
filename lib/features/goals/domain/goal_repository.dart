import 'goal.dart';

/// Port for reading and mutating life goals in the local store.
///
/// Every local write stamps `updated_at` in UTC and records an outbox entry
/// so the sync service can push the change to the server.
abstract interface class GoalRepository {
  /// Watches all active (non-deleted) goals belonging to [areaId].
  Stream<List<Goal>> watchByArea(String areaId);

  /// Creates or updates a goal and records a sync outbox entry.
  ///
  /// When [id] is omitted, a new client UUID is generated.
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
  });

  /// Soft-deletes a goal and all of its active actions locally, enqueueing
  /// separate outbox entries for the goal and each soft-deleted action.
  Future<void> delete(String id);
}
