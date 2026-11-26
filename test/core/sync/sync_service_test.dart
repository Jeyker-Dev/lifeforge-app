import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/db/app_database.dart';
import 'package:lifeforge/core/sync/sync_service.dart';
import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/areas/data/drift_area_repository.dart';
import 'package:lifeforge/features/goals/data/drift_goal_action_repository.dart';
import 'package:lifeforge/features/goals/data/drift_goal_repository.dart';
import 'package:lifeforge/features/goals/data/goal_actions_remote.dart';
import 'package:lifeforge/features/goals/data/goals_remote.dart';
import 'package:lifeforge/features/goals/domain/goal_action.dart';

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

  group('multi-entity sync (areas, goals, goal_actions)', () {
    late DriftGoalRepository goalRepo;
    late DriftGoalActionRepository actionRepo;
    late FakeGoalsRemote goalsRemote;
    late FakeGoalActionsRemote actionsRemote;
    late SyncService fullSync;
    int goalSeq = 0;
    int actionSeq = 0;

    setUp(() {
      goalSeq = 0;
      actionSeq = 0;
      goalRepo = DriftGoalRepository(
        db,
        clock: () => now,
        idGenerator: () => 'goal-${++goalSeq}',
      );
      actionRepo = DriftGoalActionRepository(
        db,
        clock: () => now,
        idGenerator: () => 'action-${++actionSeq}',
      );
      goalsRemote = FakeGoalsRemote();
      actionsRemote = FakeGoalActionsRemote();
      fullSync = SyncService(
        db,
        remote,
        goalsRemote: goalsRemote,
        goalActionsRemote: actionsRemote,
      );
    });

    test(
      'area sync behavior is unchanged when all remotes are wired',
      () async {
        final area = await repo.create(name: 'Salud', color: '#E07A5F');
        remote.nextCursor = 'area-cursor-1';

        await fullSync.syncAll();

        expect(remote.pushed.map((p) => p.id), [area.id]);
        expect(goalsRemote.pushed, isEmpty);
        expect(actionsRemote.pushed, isEmpty);
        final synced = (await repo.watchAll().first).single;
        expect(synced.pendingSync, isFalse);
        expect(synced.serverUpdatedAt, DateTime.utc(2026, 11, 24, 12, 5));
      },
    );

    test(
      'pushes in order areas, then goals, then goal_actions even when created out of order',
      () async {
        final log = <String>[];
        remote.onPut = (p) {
          log.add('area:${p.id}');
          return RemoteArea(
            id: p.id,
            name: p.name,
            color: p.color,
            position: p.position,
            updatedAt: p.updatedAt,
            deletedAt: p.deletedAt,
            serverUpdatedAt: '2026-11-24T12:05:00.000Z',
          );
        };
        goalsRemote.onPut = (p) {
          log.add('goal:${p.id}');
          return RemoteGoal(
            id: p.id,
            areaId: p.areaId,
            title: p.title,
            why: p.why,
            targetDate: p.targetDate,
            metricCurrent: p.metricCurrent,
            metricTarget: p.metricTarget,
            metricUnit: p.metricUnit,
            weeklyHoursTarget: p.weeklyHoursTarget,
            status: p.status,
            updatedAt: p.updatedAt,
            deletedAt: p.deletedAt,
            serverUpdatedAt: '2026-11-24T12:05:00.000Z',
          );
        };
        actionsRemote.onPut = (p) {
          log.add('action:${p.id}');
          return RemoteGoalAction(
            id: p.id,
            goalId: p.goalId,
            title: p.title,
            kind: p.kind,
            done: p.done,
            position: p.position,
            updatedAt: p.updatedAt,
            deletedAt: p.deletedAt,
            serverUpdatedAt: '2026-11-24T12:05:00.000Z',
          );
        };

        // Enqueue action, then goal, then area to prove SyncService orders by entity type.
        final action = await actionRepo.upsert(
          goalId: 'goal-1',
          title: 'Actualizar CV',
          kind: GoalActionKind.task,
        );
        final goal = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Conseguir trabajo',
          metricCurrent: 0,
          metricTarget: 5,
          metricUnit: 'entrevistas',
          weeklyHoursTarget: 6,
        );
        final area = await repo.create(name: 'Carrera', color: '#D4A373');

        await fullSync.syncAll();

        expect(log, [
          'area:${area.id}',
          'goal:${goal.id}',
          'action:${action.id}',
        ]);
      },
    );

    test(
      'pull applies newer updatedAt, ignores older, and keeps local row on a tie',
      () async {
        final goalNewer = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Local old',
          metricCurrent: 1,
          metricTarget: 10,
          metricUnit: 'pasos',
          weeklyHoursTarget: 5,
        );
        final goalOlder = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Local newer',
          metricCurrent: 2,
          metricTarget: 10,
          metricUnit: 'pasos',
          weeklyHoursTarget: 5,
        );
        final goalTie = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Local tie',
          metricCurrent: 3,
          metricTarget: 10,
          metricUnit: 'pasos',
          weeklyHoursTarget: 5,
        );
        final actionNewer = await actionRepo.upsert(
          goalId: goalNewer.id,
          title: 'Action local old',
          kind: GoalActionKind.task,
        );
        final actionTie = await actionRepo.upsert(
          goalId: goalTie.id,
          title: 'Action local tie',
          kind: GoalActionKind.milestone,
        );

        // Push initial rows so outbox is empty before pull.
        await fullSync.syncAll();

        final tNewer = now.add(const Duration(minutes: 10)).toIso8601String();
        final tOlder = now
            .subtract(const Duration(minutes: 10))
            .toIso8601String();
        final tTie = now.toIso8601String();

        goalsRemote.pullResponseGoals = [
          RemoteGoal(
            id: goalNewer.id,
            areaId: 'area-1',
            title: 'Server newer',
            why: null,
            targetDate: null,
            metricCurrent: 5,
            metricTarget: 10,
            metricUnit: 'pasos',
            weeklyHoursTarget: 5,
            status: 'active',
            updatedAt: tNewer,
            deletedAt: null,
            serverUpdatedAt: '2026-11-24T13:00:00.000Z',
          ),
          RemoteGoal(
            id: goalOlder.id,
            areaId: 'area-1',
            title: 'Server older',
            why: null,
            targetDate: null,
            metricCurrent: 99,
            metricTarget: 10,
            metricUnit: 'pasos',
            weeklyHoursTarget: 5,
            status: 'active',
            updatedAt: tOlder,
            deletedAt: null,
            serverUpdatedAt: '2026-11-24T13:00:01.000Z',
          ),
          RemoteGoal(
            id: goalTie.id,
            areaId: 'area-1',
            title: 'Server tie',
            why: null,
            targetDate: null,
            metricCurrent: 88,
            metricTarget: 10,
            metricUnit: 'pasos',
            weeklyHoursTarget: 5,
            status: 'active',
            updatedAt: tTie,
            deletedAt: null,
            serverUpdatedAt: '2026-11-24T13:00:02.000Z',
          ),
        ];

        actionsRemote.pullResponseActions = [
          RemoteGoalAction(
            id: actionNewer.id,
            goalId: goalNewer.id,
            title: 'Action server newer',
            kind: 'task',
            done: true,
            position: 0,
            updatedAt: tNewer,
            deletedAt: null,
            serverUpdatedAt: '2026-11-24T13:00:00.000Z',
          ),
          RemoteGoalAction(
            id: actionTie.id,
            goalId: goalTie.id,
            title: 'Action server tie',
            kind: 'milestone',
            done: true,
            position: 0,
            updatedAt: tTie,
            deletedAt: null,
            serverUpdatedAt: '2026-11-24T13:00:01.000Z',
          ),
        ];

        await fullSync.syncAll();

        final goals = await goalRepo.watchByArea('area-1').first;
        final byId = {for (final g in goals) g.id: g};
        expect(byId[goalNewer.id]!.title, 'Server newer');
        expect(byId[goalOlder.id]!.title, 'Local newer');
        expect(byId[goalTie.id]!.title, 'Local tie');

        final aNewerList = await actionRepo.watchByGoal(goalNewer.id).first;
        expect(aNewerList.single.title, 'Action server newer');
        expect(aNewerList.single.done, isTrue);

        final aTieList = await actionRepo.watchByGoal(goalTie.id).first;
        expect(aTieList.single.title, 'Action local tie');
        expect(aTieList.single.done, isFalse);
      },
    );

    test(
      'soft deletes for goals and actions arrive from pull and hide them from watches',
      () async {
        final goal = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Meta',
          metricCurrent: 0,
          metricTarget: 1,
          metricUnit: 'u',
          weeklyHoursTarget: 1,
        );
        final action = await actionRepo.upsert(
          goalId: goal.id,
          title: 'Acción',
          kind: GoalActionKind.task,
        );
        await fullSync.syncAll();

        final deleteAt = now.add(const Duration(minutes: 5)).toIso8601String();
        goalsRemote.pullResponseGoals = [
          RemoteGoal(
            id: goal.id,
            areaId: 'area-1',
            title: 'Meta',
            why: null,
            targetDate: null,
            metricCurrent: 0,
            metricTarget: 1,
            metricUnit: 'u',
            weeklyHoursTarget: 1,
            status: 'active',
            updatedAt: deleteAt,
            deletedAt: deleteAt,
            serverUpdatedAt: '2026-11-24T13:00:00.000Z',
          ),
        ];
        actionsRemote.pullResponseActions = [
          RemoteGoalAction(
            id: action.id,
            goalId: goal.id,
            title: 'Acción',
            kind: 'task',
            done: false,
            position: 0,
            updatedAt: deleteAt,
            deletedAt: deleteAt,
            serverUpdatedAt: '2026-11-24T13:00:00.000Z',
          ),
        ];

        await fullSync.syncAll();

        expect(await goalRepo.watchByArea('area-1').first, isEmpty);
        expect(await actionRepo.watchByGoal(goal.id).first, isEmpty);
      },
    );

    test('separate cursors are stored and reused per entity', () async {
      remote.nextCursor = 'area-c1';
      goalsRemote.nextCursor = 'goal-c1';
      actionsRemote.nextCursor = 'action-c1';
      await fullSync.syncAll();

      remote.nextCursor = 'area-c2';
      goalsRemote.nextCursor = 'goal-c2';
      actionsRemote.nextCursor = 'action-c2';
      await fullSync.syncAll();

      expect(remote.pulledSince, [null, 'area-c1']);
      expect(goalsRemote.pulledSince, [null, 'goal-c1']);
      expect(actionsRemote.pulledSince, [null, 'action-c1']);
    });

    test('single-flight holds for concurrent syncAll() calls', () async {
      await repo.create(name: 'Salud', color: '#E07A5F');
      await goalRepo.upsert(
        areaId: 'area-1',
        title: 'Meta',
        metricCurrent: 0,
        metricTarget: 1,
        metricUnit: 'u',
        weeklyHoursTarget: 1,
      );
      await actionRepo.upsert(
        goalId: 'goal-1',
        title: 'Paso',
        kind: GoalActionKind.task,
      );
      remote.putGate = Completer<void>();

      final first = fullSync.syncAll();
      final second = fullSync.syncAll();
      remote.putGate!.complete();
      await Future.wait([first, second]);

      expect(remote.pushed, hasLength(1));
      expect(goalsRemote.pushed, hasLength(1));
      expect(actionsRemote.pushed, hasLength(1));
      expect(remote.pulledSince, hasLength(1));
      expect(goalsRemote.pulledSince, hasLength(1));
      expect(actionsRemote.pulledSince, hasLength(1));
    });

    test(
      'a 422 on push drops only that entry and keeps syncing the rest',
      () async {
        final badGoal = await goalRepo.upsert(
          areaId: 'missing-area',
          title: 'Inválida',
          metricCurrent: 0,
          metricTarget: 1,
          metricUnit: 'u',
          weeklyHoursTarget: 1,
        );
        final validGoal = await goalRepo.upsert(
          areaId: 'area-1',
          title: 'Válida',
          metricCurrent: 0,
          metricTarget: 1,
          metricUnit: 'u',
          weeklyHoursTarget: 1,
        );
        goalsRemote.onPut = (payload) {
          if (payload.id == badGoal.id) {
            throw const SyncClientException(422);
          }
          return RemoteGoal(
            id: payload.id,
            areaId: payload.areaId,
            title: payload.title,
            why: payload.why,
            targetDate: payload.targetDate,
            metricCurrent: payload.metricCurrent,
            metricTarget: payload.metricTarget,
            metricUnit: payload.metricUnit,
            weeklyHoursTarget: payload.weeklyHoursTarget,
            status: payload.status,
            updatedAt: payload.updatedAt,
            deletedAt: payload.deletedAt,
            serverUpdatedAt: '2026-11-24T12:05:00.000Z',
          );
        };

        await fullSync.syncAll();

        expect(await db.select(db.syncOutbox).get(), isEmpty);
        final badLocal =
            (await goalRepo.watchByArea('missing-area').first).single;
        expect(badLocal.pendingSync, isFalse);
        expect(badLocal.serverUpdatedAt, isNull);

        final validLocal = (await goalRepo.watchByArea('area-1').first).single;
        expect(validLocal.id, validGoal.id);
        expect(validLocal.pendingSync, isFalse);
        expect(validLocal.serverUpdatedAt, DateTime.utc(2026, 11, 24, 12, 5));
      },
    );
  });

  group('default life areas seeding (A3)', () {
    late SyncService syncWithRepo;

    setUp(() {
      syncWithRepo = SyncService(db, remote, areaRepository: repo);
    });

    test(
      'creates the 5 default areas in order after an empty successful pull',
      () async {
        await syncWithRepo.syncAll();

        final areas = await repo.watchAll().first;
        expect(areas.map((a) => (a.name, a.color, a.position)).toList(), [
          ('Salud', '#E07A5F', 0),
          ('Carrera', '#D4A373', 1),
          ('Finanzas', '#81B29A', 2),
          ('Relaciones', '#D98C9B', 3),
          ('Ocio', '#A88BD9', 4),
        ]);
        expect(areas.every((a) => !a.pendingSync), isTrue);
        expect(remote.pushed, hasLength(5));
        expect(remote.serverAreas, hasLength(5));
      },
    );

    test('does not create defaults when local areas already exist', () async {
      await repo.create(name: 'Personalizada', color: '#E07A5F');

      await syncWithRepo.syncAll();

      final areas = await repo.watchAll().first;
      expect(areas.map((a) => a.name), ['Personalizada']);
    });

    test('does not create defaults when remote pull returns areas', () async {
      remote.pullResponseAreas = [
        const RemoteArea(
          id: 'remote-1',
          name: 'Proyecto',
          color: '#D4A373',
          position: 0,
          updatedAt: '2026-11-24T12:00:00.000Z',
          deletedAt: null,
          serverUpdatedAt: '2026-11-24T12:00:01.000Z',
        ),
      ];

      await syncWithRepo.syncAll();

      final areas = await repo.watchAll().first;
      expect(areas.map((a) => a.name), ['Proyecto']);
    });

    test(
      'does not create defaults when the pull fails with network or client error',
      () async {
        remote.pullError = const SyncNetworkException();
        await syncWithRepo.syncAll();
        expect(await db.select(db.areas).get(), isEmpty);

        remote.pullError = const SyncClientException(401);
        await syncWithRepo.syncAll();
        expect(await db.select(db.areas).get(), isEmpty);
      },
    );

    test(
      'does not create defaults when the only remote areas are soft-deleted',
      () async {
        remote.pullResponseAreas = [
          const RemoteArea(
            id: 'deleted-1',
            name: 'Salud',
            color: '#E07A5F',
            position: 0,
            updatedAt: '2026-11-24T12:00:00.000Z',
            deletedAt: '2026-11-24T12:00:00.000Z',
            serverUpdatedAt: '2026-11-24T12:00:01.000Z',
          ),
        ];

        await syncWithRepo.syncAll();

        expect(await repo.watchAll().first, isEmpty);
        final allRows = await db.select(db.areas).get();
        expect(allRows, hasLength(1));
        expect(allRows.single.id, 'deleted-1');
      },
    );

    test('running sync twice does not duplicate default areas', () async {
      await syncWithRepo.syncAll();
      await syncWithRepo.syncAll();

      final areas = await repo.watchAll().first;
      expect(areas, hasLength(5));
      expect(remote.pushed, hasLength(5));
    });
  });
}
