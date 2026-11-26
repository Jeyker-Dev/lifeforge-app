import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';

class _V1Database extends GeneratedDatabase {
  _V1Database(super.e);

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement('''
        CREATE TABLE areas (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT NOT NULL,
          position INTEGER NOT NULL,
          updated_at TEXT NOT NULL,
          deleted_at TEXT NULL,
          server_updated_at TEXT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE sync_outbox (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entity TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
      await customStatement('''
        CREATE TABLE sync_cursors (
          entity TEXT NOT NULL PRIMARY KEY,
          cursor TEXT NOT NULL
        )
      ''');
    },
  );
}

void main() {
  test(
    'migrating from schema v1 to v2 preserves areas and creates goals and goal_actions',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lifeforge_migration_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final dbFile = File('${tempDir.path}/lifeforge.sqlite');

      final v1 = _V1Database(NativeDatabase(dbFile));
      await v1.customInsert(
        '''
        INSERT INTO areas (id, name, color, position, updated_at, deleted_at, server_updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString('area-1'),
          Variable.withString('Carrera'),
          Variable.withString('#D4A373'),
          Variable.withInt(0),
          Variable.withString('2026-11-24T12:00:00.000Z'),
          const Variable<String>(null),
          Variable.withString('2026-11-24T12:00:01.000Z'),
        ],
      );
      await v1.customInsert(
        'INSERT INTO sync_cursors (entity, cursor) VALUES (?, ?)',
        variables: [
          Variable.withString('area'),
          Variable.withString('cursor-v1'),
        ],
      );
      await v1.close();

      final v2 = AppDatabase(NativeDatabase(dbFile));
      addTearDown(v2.close);

      final areas = await v2.select(v2.areas).get();
      expect(areas, hasLength(1));
      expect(areas.single.id, 'area-1');
      expect(areas.single.name, 'Carrera');
      expect(areas.single.color, '#D4A373');
      expect(areas.single.position, 0);
      expect(areas.single.serverUpdatedAt, '2026-11-24T12:00:01.000Z');

      final cursors = await v2.select(v2.syncCursors).get();
      expect(cursors.single.entity, 'area');
      expect(cursors.single.cursor, 'cursor-v1');

      await v2
          .into(v2.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'goal-1',
              areaId: 'area-1',
              title: 'Conseguir trabajo',
              metricCurrent: 3,
              metricTarget: 10,
              metricUnit: 'entrevistas',
              weeklyHoursTarget: 8,
              status: 'active',
              updatedAt: '2026-11-25T12:00:00.000Z',
            ),
          );
      await v2
          .into(v2.goalActions)
          .insert(
            GoalActionsCompanion.insert(
              id: 'action-1',
              goalId: 'goal-1',
              title: 'Actualizar CV',
              kind: 'task',
              done: false,
              position: 0,
              updatedAt: '2026-11-25T12:00:00.000Z',
            ),
          );

      expect(await v2.select(v2.goals).get(), hasLength(1));
      expect(await v2.select(v2.goalActions).get(), hasLength(1));
    },
  );
}
