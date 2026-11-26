/// Lifecycle status of a [Goal].
enum GoalStatus {
  active('active'),
  completed('completed');

  const GoalStatus(this.value);

  /// Wire value expected by the LifeForge API (`active` or `completed`).
  final String value;

  static GoalStatus fromValue(String value) => switch (value) {
    'active' => GoalStatus.active,
    'completed' => GoalStatus.completed,
    _ => throw FormatException('Unknown goal status: $value'),
  };
}

/// A life goal inside an area, with progress metric and weekly hours target.
class Goal {
  const Goal({
    required this.id,
    required this.areaId,
    required this.title,
    this.why,
    this.targetDate,
    required this.metricCurrent,
    required this.metricTarget,
    required this.metricUnit,
    required this.weeklyHoursTarget,
    required this.status,
    required this.updatedAt,
    this.deletedAt,
    this.serverUpdatedAt,
    this.pendingSync = false,
  });

  final String id;
  final String areaId;
  final String title;
  final String? why;
  final DateTime? targetDate;
  final double metricCurrent;
  final double metricTarget;
  final String metricUnit;
  final double weeklyHoursTarget;
  final GoalStatus status;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? serverUpdatedAt;

  /// True when the goal has a pending entry in the local sync outbox.
  final bool pendingSync;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          id == other.id &&
          areaId == other.areaId &&
          title == other.title &&
          why == other.why &&
          targetDate == other.targetDate &&
          metricCurrent == other.metricCurrent &&
          metricTarget == other.metricTarget &&
          metricUnit == other.metricUnit &&
          weeklyHoursTarget == other.weeklyHoursTarget &&
          status == other.status &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          serverUpdatedAt == other.serverUpdatedAt &&
          pendingSync == other.pendingSync;

  @override
  int get hashCode => Object.hash(
    id,
    areaId,
    title,
    why,
    targetDate,
    metricCurrent,
    metricTarget,
    metricUnit,
    weeklyHoursTarget,
    status,
    updatedAt,
    deletedAt,
    serverUpdatedAt,
    pendingSync,
  );
}
