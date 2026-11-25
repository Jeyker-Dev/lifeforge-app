import 'area.dart';

/// Port for reading and mutating life areas in the local store.
///
/// Every local write stamps `updated_at` in UTC and records an outbox entry
/// so the sync service can push the change to the server.
abstract interface class AreaRepository {
  /// Watches all active (non-deleted) areas ordered by [Area.position].
  Stream<List<Area>> watchAll();

  /// Creates a new area at the next available position.
  Future<Area> create({required String name, required String color});

  /// Renames an existing area.
  Future<void> rename({required String id, required String name});

  /// Changes the hex color of an existing area.
  Future<void> changeColor({required String id, required String color});

  /// Soft-deletes an area by setting `deleted_at` and `updated_at`.
  Future<void> delete(String id);
}
