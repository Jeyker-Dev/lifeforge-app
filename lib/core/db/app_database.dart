import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Local cache of life areas.
@DataClassName('AreaRow')
class Areas extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  IntColumn get position => integer()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local cache of life goals belonging to areas.
@DataClassName('GoalRow')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get areaId => text()();
  TextColumn get title => text()();
  TextColumn get why => text().nullable()();
  TextColumn get targetDate => text().nullable()();
  RealColumn get metricCurrent => real()();
  RealColumn get metricTarget => real()();
  TextColumn get metricUnit => text()();
  RealColumn get weeklyHoursTarget => real()();
  TextColumn get status => text()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local cache of tasks and milestones inside a goal's action plan.
@DataClassName('GoalActionRow')
class GoalActions extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  TextColumn get title => text()();
  TextColumn get kind => text()();
  BoolColumn get done => boolean()();
  IntColumn get position => integer()();
  TextColumn get updatedAt => text()();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get serverUpdatedAt => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Queue of entities that have local changes waiting to be pushed to the API.
@DataClassName('SyncOutboxRow')
class SyncOutbox extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get createdAt => text()();
}

/// Last pull cursor per entity returned by the API.
@DataClassName('SyncCursorRow')
class SyncCursors extends Table {
  TextColumn get entity => text()();
  TextColumn get cursor => text()();

  @override
  Set<Column<Object>> get primaryKey => {entity};
}

@DriftDatabase(tables: [Areas, Goals, GoalActions, SyncOutbox, SyncCursors])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(_wrapExecutor(executor ?? _openConnection()));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(goals);
        await m.createTable(goalActions);
      }
    },
  );

  /// Records a pending sync operation for [entity] and [entityId].
  Future<void> enqueueOutbox({
    required String entity,
    required String entityId,
    required String createdAt,
  }) async {
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        entity: entity,
        entityId: entityId,
        createdAt: createdAt,
      ),
    );
  }

  static QueryExecutor _wrapExecutor(QueryExecutor executor) {
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        executor is! DatabaseConnection) {
      return DatabaseConnection(executor, closeStreamsSynchronously: true);
    }
    return executor;
  }

  static QueryExecutor _openConnection() {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      return NativeDatabase.memory();
    }
    return driftDatabase(name: 'lifeforge');
  }
}
