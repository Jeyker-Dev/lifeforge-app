import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../domain/area.dart';
import '../domain/area_repository.dart';

/// Drift-backed implementation of [AreaRepository].
class DriftAreaRepository implements AreaRepository {
  DriftAreaRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
    void Function()? onWrite,
  }) : _clock = clock ?? _utcNow,
       _idGenerator = idGenerator ?? const Uuid().v4,
       _onWrite = onWrite;

  static const entityName = 'area';

  final AppDatabase _db;
  final DateTime Function() _clock;
  final String Function() _idGenerator;
  final void Function()? _onWrite;

  static DateTime _utcNow() => DateTime.now().toUtc();

  DateTime _nowUtc() => _clock().toUtc();

  @override
  Stream<List<Area>> watchAll() {
    final query = _db.customSelect(
      '''
      SELECT a.id,
             a.name,
             a.color,
             a.position,
             a.updated_at,
             a.deleted_at,
             a.server_updated_at,
             EXISTS (
               SELECT 1 FROM sync_outbox o
               WHERE o.entity = ? AND o.entity_id = a.id
             ) AS pending_sync
      FROM areas a
      WHERE a.deleted_at IS NULL
      ORDER BY a.position ASC, a.id ASC
      ''',
      variables: [Variable.withString(entityName)],
      readsFrom: {_db.areas, _db.syncOutbox},
    );
    return query.watch().map((rows) => rows.map(_rowToArea).toList());
  }

  @override
  Future<Area> create({required String name, required String color}) async {
    final now = _nowUtc();
    final nowIso = now.toIso8601String();
    final id = _idGenerator();

    final area = await _db.transaction(() async {
      final maxPosExp = _db.areas.position.max();
      final posQuery = _db.selectOnly(_db.areas)..addColumns([maxPosExp]);
      final posRow = await posQuery.getSingle();
      final nextPosition = (posRow.read(maxPosExp) ?? -1) + 1;

      await _db
          .into(_db.areas)
          .insert(
            AreasCompanion.insert(
              id: id,
              name: name,
              color: color,
              position: nextPosition,
              updatedAt: nowIso,
            ),
          );
      await _enqueueOutbox(id, nowIso);

      return Area(
        id: id,
        name: name,
        color: color,
        position: nextPosition,
        updatedAt: now,
        pendingSync: true,
      );
    });
    _onWrite?.call();
    return area;
  }

  @override
  Future<void> rename({required String id, required String name}) async {
    final nowIso = _nowUtc().toIso8601String();
    await _db.transaction(() async {
      final count = await (_db.update(_db.areas)..where((t) => t.id.equals(id)))
          .write(AreasCompanion(name: Value(name), updatedAt: Value(nowIso)));
      if (count > 0) {
        await _enqueueOutbox(id, nowIso);
      }
    });
    _onWrite?.call();
  }

  @override
  Future<void> delete(String id) async {
    final nowIso = _nowUtc().toIso8601String();
    await _db.transaction(() async {
      final count = await (_db.update(_db.areas)..where((t) => t.id.equals(id)))
          .write(
            AreasCompanion(deletedAt: Value(nowIso), updatedAt: Value(nowIso)),
          );
      if (count > 0) {
        await _enqueueOutbox(id, nowIso);
      }
    });
    _onWrite?.call();
  }

  Future<void> _enqueueOutbox(String entityId, String createdAt) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            entity: entityName,
            entityId: entityId,
            createdAt: createdAt,
          ),
        );
  }

  Area _rowToArea(QueryRow row) {
    final deletedAt = row.readNullable<String>('deleted_at');
    final serverUpdatedAt = row.readNullable<String>('server_updated_at');
    return Area(
      id: row.read<String>('id'),
      name: row.read<String>('name'),
      color: row.read<String>('color'),
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
