/// A life area such as "Salud" or "Carrera".
class Area {
  const Area({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.updatedAt,
    this.deletedAt,
    this.serverUpdatedAt,
    this.pendingSync = false,
  });

  final String id;
  final String name;
  final String color;
  final int position;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final DateTime? serverUpdatedAt;

  /// True when the area has a pending entry in the local sync outbox.
  final bool pendingSync;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Area &&
          id == other.id &&
          name == other.name &&
          color == other.color &&
          position == other.position &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          serverUpdatedAt == other.serverUpdatedAt &&
          pendingSync == other.pendingSync;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    position,
    updatedAt,
    deletedAt,
    serverUpdatedAt,
    pendingSync,
  );
}
