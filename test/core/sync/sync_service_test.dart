import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/sync/sync_service.dart';
import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/areas/data/drift_area_repository.dart';

import '../../fakes.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository repo;
  late FakeAreasRemote remote;
  late SyncService sync;
  late DateTime now;
  int idSeq = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime.utc(2026, 11, 24, 12);
    idSeq = 0;
    repo = DriftAreaRepository(
      db,
      clock: () => now,
      idGenerator: () => 'area-${++idSeq}',
    );
    remote = FakeAreasRemote();
    sync = SyncService(db, remote);
  });

  tearDown(() => db.close());

  test(
    'a create while offline stays in the outbox and is pushed later',
    () async {
      final area = await repo.create(name: 'Salud', color: '#E07A5F');
      remote.putError = const SyncNetworkException();

      await sync.syncAreas();

      expect(remote.pushed, hasLength(1));
      expect((await repo.watchAll().first).single.pendingSync, isTrue);
      expect(await db.select(db.syncOutbox).get(), hasLength(1));
      expect(remote.pulledSince, isEmpty);

      remote.putError = null;
      await sync.syncAreas();

      expect(remote.pushed, hasLength(2));
      expect(remote.pushed.last.id, area.id);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
      final synced = (await repo.watchAll().first).single;
      expect(synced.pendingSync, isFalse);
      expect(synced.serverUpdatedAt, DateTime.utc(2026, 11, 24, 12, 5));
    },
  );

  test(
    'a server response with a newer version overwrites the local row',
    () async {
      final area = await repo.create(name: 'Salud', color: '#E07A5F');
      remote.onPut = (payload) => RemoteArea(
        id: payload.id,
        name: 'Salud desde servidor',
        color: '#81B29A',
        position: 3,
        updatedAt: '2026-11-24T13:00:00.000Z',
        deletedAt: null,
        serverUpdatedAt: '2026-11-24T13:00:01.000Z',
      );

      await sync.syncAreas();

      final local = (await repo.watchAll().first).single;
      expect(local.id, area.id);
      expect(local.name, 'Salud desde servidor');
      expect(local.color, '#81B29A');
      expect(local.position, 3);
      expect(local.updatedAt, DateTime.utc(2026, 11, 24, 13));
      expect(local.pendingSync, isFalse);
      expect(await db.select(db.syncOutbox).get(), isEmpty);
    },
  );

  test(
    'a 4xx on push drops the outbox entry and keeps the local row',
    () async {
      final area = await repo.create(name: 'Salud', color: '#E07A5F');
      remote.putError = const SyncClientException(422);

      await sync.syncAreas();

      expect(await db.select(db.syncOutbox).get(), isEmpty);
      final local = (await repo.watchAll().first).single;
      expect(local.id, area.id);
      expect(local.name, 'Salud');
      expect(local.pendingSync, isFalse);
    },
  );

  test('a pull does not overwrite an area with a pending local edit', () async {
    final area = await repo.create(name: 'Salud', color: '#E07A5F');
    await sync.syncAreas();

    now = now.add(const Duration(minutes: 10));
    await repo.rename(id: area.id, name: 'Salud editada offline');

    remote.onPut = (_) => throw const SyncNetworkException();
    await sync.syncAreas();

    // Simulate a pull running while the area still has a pending outbox entry
    // (for instance, if an outbox entry exists when pull processes the response).
    remote.onPut = null;
    remote.pullResponseAreas = [
      RemoteArea(
        id: area.id,
        name: 'Salud vieja del servidor',
        color: '#E07A5F',
        position: 0,
        updatedAt: '2026-11-24T12:00:00.000Z',
        deletedAt: null,
        serverUpdatedAt: '2026-11-24T12:05:00.000Z',
      ),
    ];

    // Insert a second local edit during push so pull sees a pending outbox row.
    remote.onPut = (payload) {
      db
          .into(db.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              entity: DriftAreaRepository.entityName,
              entityId: area.id,
              createdAt: now.toIso8601String(),
            ),
          );
      return RemoteArea(
        id: payload.id,
        name: 'Salud editada offline',
        color: payload.color,
        position: payload.position,
        updatedAt: payload.updatedAt,
        deletedAt: payload.deletedAt,
        serverUpdatedAt: '2026-11-24T12:15:00.000Z',
      );
    };

    await sync.syncAreas();

    final local = (await repo.watchAll().first).single;
    expect(local.name, 'Salud editada offline');
    expect(local.pendingSync, isTrue);
  });

  test('deleted areas from a pull disappear from watchAll()', () async {
    final area = await repo.create(name: 'Salud', color: '#E07A5F');
    await sync.syncAreas();
    expect(await repo.watchAll().first, hasLength(1));

    remote.pullResponseAreas = [
      RemoteArea(
        id: area.id,
        name: 'Salud',
        color: '#E07A5F',
        position: 0,
        updatedAt: '2026-11-24T14:00:00.000Z',
        deletedAt: '2026-11-24T14:00:00.000Z',
        serverUpdatedAt: '2026-11-24T14:00:01.000Z',
      ),
    ];

    await sync.syncAreas();

    expect(await repo.watchAll().first, isEmpty);
  });

  test('the cursor is stored and reused across pulls', () async {
    remote.nextCursor = 'cursor-1';
    await sync.syncAreas();

    remote.nextCursor = 'cursor-2';
    await sync.syncAreas();

    await sync.syncAreas();

    expect(remote.pulledSince, [null, 'cursor-1', 'cursor-2']);
  });

  test('two concurrent syncAreas() calls produce one push', () async {
    await repo.create(name: 'Salud', color: '#E07A5F');
    remote.putGate = Completer<void>();

    final first = sync.syncAreas();
    final second = sync.syncAreas();
    remote.putGate!.complete();
    await Future.wait([first, second]);

    expect(remote.pushed, hasLength(1));
    expect(remote.pulledSince, hasLength(1));
  });
}
