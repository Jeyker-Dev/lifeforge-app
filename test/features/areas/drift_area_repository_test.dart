import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/features/areas/data/drift_area_repository.dart';

void main() {
  late AppDatabase db;
  late DriftAreaRepository repo;
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
  });

  tearDown(() => db.close());

  test(
    'create inserts area with UTC updated_at and enqueues outbox entry',
    () async {
      final created = await repo.create(name: 'Salud', color: '#E07A5F');

      expect(created.id, 'area-1');
      expect(created.name, 'Salud');
      expect(created.color, '#E07A5F');
      expect(created.position, 0);
      expect(created.updatedAt, now);
      expect(created.deletedAt, isNull);
      expect(created.serverUpdatedAt, isNull);
      expect(created.pendingSync, isTrue);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(1));
      expect(outbox.single.entity, 'area');
      expect(outbox.single.entityId, 'area-1');
    },
  );

  test(
    'watchAll emits active areas with pendingSync flag and hides soft-deleted ones',
    () async {
      final first = await repo.create(name: 'Salud', color: '#E07A5F');
      now = now.add(const Duration(minutes: 1));
      final second = await repo.create(name: 'Carrera', color: '#D4A373');

      expect(await repo.watchAll().first, [
        isA<Object>()
            .having((a) => (a as dynamic).id, 'id', first.id)
            .having((a) => (a as dynamic).position, 'position', 0)
            .having((a) => (a as dynamic).pendingSync, 'pendingSync', true),
        isA<Object>()
            .having((a) => (a as dynamic).id, 'id', second.id)
            .having((a) => (a as dynamic).position, 'position', 1)
            .having((a) => (a as dynamic).pendingSync, 'pendingSync', true),
      ]);

      now = now.add(const Duration(minutes: 2));
      await repo.rename(id: first.id, name: 'Salud física');
      final afterRename = await repo.watchAll().first;
      expect(afterRename.first.name, 'Salud física');
      expect(afterRename.first.updatedAt, now);

      now = now.add(const Duration(minutes: 3));
      await repo.delete(first.id);
      final afterDelete = await repo.watchAll().first;
      expect(afterDelete.map((a) => a.id), [second.id]);

      final deletedRow = await (db.select(
        db.areas,
      )..where((t) => t.id.equals(first.id))).getSingle();
      expect(deletedRow.deletedAt, now.toIso8601String());
      expect(deletedRow.updatedAt, now.toIso8601String());
    },
  );

  test(
    'changeColor updates color, stamps UTC updated_at and enqueues outbox entry',
    () async {
      final created = await repo.create(name: 'Salud', color: '#E07A5F');
      now = now.add(const Duration(minutes: 5));

      await repo.changeColor(id: created.id, color: '#81B29A');

      final updated = (await repo.watchAll().first).single;
      expect(updated.color, '#81B29A');
      expect(updated.updatedAt, now);
      expect(updated.pendingSync, isTrue);

      final outbox = await db.select(db.syncOutbox).get();
      expect(outbox, hasLength(2));
      expect(outbox.last.entity, 'area');
      expect(outbox.last.entityId, created.id);
      expect(outbox.last.createdAt, now.toIso8601String());
    },
  );
}
