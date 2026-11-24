import 'package:drift/drift.dart';

import '../../features/areas/data/areas_remote.dart';
import '../../features/areas/data/drift_area_repository.dart';
import '../db/app_database.dart';

/// Synchronizes local areas with the LifeForge API using a push-then-pull flow.
///
/// Only one sync runs at a time; concurrent callers share the in-flight run.
class SyncService {
  SyncService(this._db, this._remote);

  static const _areaEntity = DriftAreaRepository.entityName;

  final AppDatabase _db;
  final AreasRemote _remote;
  Future<void>? _inFlight;

  /// Pushes queued local area changes and then pulls remote changes.
  Future<void> syncAreas() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    final pushedAll = await _pushAreas();
    if (!pushedAll) return;
    await _pullAreas();
  }

  /// Pushes outbox entries in creation order.
  ///
  /// Returns `false` if a network error interrupted the push so the caller skips
  /// pulling until connectivity returns.
  Future<bool> _pushAreas() async {
    final entries =
        await (_db.select(_db.syncOutbox)
              ..where((t) => t.entity.equals(_areaEntity))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();

    for (final entry in entries) {
      final row = await (_db.select(
        _db.areas,
      )..where((t) => t.id.equals(entry.entityId))).getSingleOrNull();
      if (row == null) {
        await _deleteOutboxEntry(entry.id);
        continue;
      }

      try {
        final canonical = await _remote.putArea(
          AreaPushPayload(
            id: row.id,
            name: row.name,
            color: row.color,
            position: row.position,
            updatedAt: row.updatedAt,
            deletedAt: row.deletedAt,
          ),
        );
        await _db.transaction(() async {
          await _upsertRemoteArea(canonical);
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

  Future<void> _pullAreas() async {
    final cursorRow = await (_db.select(
      _db.syncCursors,
    )..where((t) => t.entity.equals(_areaEntity))).getSingleOrNull();

    final AreasPullResponse response;
    try {
      response = await _remote.pullAreas(since: cursorRow?.cursor);
    } on SyncNetworkException {
      return;
    } on SyncClientException {
      return;
    }

    await _db.transaction(() async {
      final pendingRows = await (_db.select(
        _db.syncOutbox,
      )..where((t) => t.entity.equals(_areaEntity))).get();
      final pendingIds = pendingRows.map((row) => row.entityId).toSet();

      for (final remoteArea in response.areas) {
        if (pendingIds.contains(remoteArea.id)) continue;
        await _upsertRemoteArea(remoteArea);
      }

      final nextCursor = response.cursor;
      if (nextCursor != null) {
        await _db
            .into(_db.syncCursors)
            .insertOnConflictUpdate(
              SyncCursorsCompanion.insert(
                entity: _areaEntity,
                cursor: nextCursor,
              ),
            );
      }
    });
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

  Future<void> _deleteOutboxEntry(int id) async {
    await (_db.delete(_db.syncOutbox)..where((t) => t.id.equals(id))).go();
  }
}
