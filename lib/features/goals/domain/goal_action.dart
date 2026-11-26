/// Kind of action inside a goal's action plan.
enum GoalActionKind {
  task('task'),
  milestone('milestone');

  const GoalActionKind(this.value);

  /// Wire value expected by the LifeForge API (`task` or `milestone`).
  final String value;

  static GoalActionKind fromValue(String value) => switch (value) {
    'task' => GoalActionKind.task,
    'milestone' => GoalActionKind.milestone,
    _ => throw FormatException('Unknown goal action kind: $value'),
  };
}

/// A task or milestone inside a goal's action plan.
class GoalAction {
  const GoalAction({
    required this.id,
    required this.goalId,
    required this.title,
    required this.kind,
    required this.done,
    required this.position,
    required this.updatedAt,
    this.deletedAt,
    this.serverUpdatedAt,
    this.pendingSync = false,
  });

  final String id;
  final String goalId;
  final String title;
  final GoalActionKind kind;
  final bool done;
  final int position;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? serverUpdatedAt;

  /// True when the action has a pending entry in the local sync outbox.
  final bool pendingSync;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalAction &&
          id == other.id &&
          goalId == other.goalId &&
          title == other.title &&
          kind == other.kind &&
          done == other.done &&
          position == other.position &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          serverUpdatedAt == other.serverUpdatedAt &&
          pendingSync == other.pendingSync;

  @override
  int get hashCode => Object.hash(
    id,
    goalId,
    title,
    kind,
    done,
    position,
    updatedAt,
    deletedAt,
    serverUpdatedAt,
    pendingSync,
  );
}
