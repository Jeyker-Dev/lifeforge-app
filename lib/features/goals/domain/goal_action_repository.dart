import 'goal_action.dart';

/// Port for reading and mutating goal actions in the local store.
///
/// Every local write stamps `updated_at` in UTC and records an outbox entry
/// so the sync service can push the change to the server.
abstract interface class GoalActionRepository {
  /// Watches all active (non-deleted) actions for [goalId] ordered by
  /// [GoalAction.position].
  Stream<List<GoalAction>> watchByGoal(String goalId);

  /// Creates or updates a goal action and records a sync outbox entry.
  ///
  /// When [id] is omitted, a new client UUID is generated. When [position] is
  /// omitted on create, the action is appended after existing actions for the
  /// goal; on update, the existing position is preserved.
  Future<GoalAction> upsert({
    String? id,
    required String goalId,
    required String title,
    required GoalActionKind kind,
    bool done = false,
    int? position,
  });

  /// Rewrites action positions for [goalId] in [orderedIds] order within a
  /// single transaction, stamping `updated_at` and enqueueing outbox entries
  /// only for actions whose position changed.
  Future<void> reorder(String goalId, List<String> orderedIds);

  /// Soft-deletes a goal action by setting `deleted_at` and `updated_at`.
  Future<void> delete(String id);
}
