import 'dart:async';

import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';
import 'package:lifeforge/features/goals/data/goal_actions_remote.dart';
import 'package:lifeforge/features/goals/data/goals_remote.dart';

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this.tokens]);

  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens tokens) async => this.tokens = tokens;

  @override
  Future<void> clear() async => tokens = null;
}

class FakeAuthGateway implements AuthGateway {
  AuthFailure? loginFailure;
  AuthFailure? refreshFailure;
  Completer<void>? refreshGate;
  int loginCalls = 0;
  int refreshCalls = 0;
  final List<String> loggedOut = [];
  final List<String> refreshedWith = [];

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    loginCalls++;
    if (loginFailure != null) throw loginFailure!;
    return const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshCalls++;
    refreshedWith.add(refreshToken);
    await refreshGate?.future;
    if (refreshFailure != null) throw refreshFailure!;
    return AuthTokens(
      accessToken: 'access-$refreshCalls-new',
      refreshToken: 'refresh-$refreshCalls-new',
    );
  }

  @override
  Future<void> logout(String refreshToken) async => loggedOut.add(refreshToken);
}

class FakeAreasRemote implements AreasRemote {
  Exception? putError;
  Exception? pullError;
  Completer<void>? putGate;
  final List<AreaPushPayload> pushed = [];
  final List<String?> pulledSince = [];
  final Map<String, RemoteArea> serverAreas = {};
  List<RemoteArea> pullResponseAreas = [];
  String? nextCursor;
  RemoteArea Function(AreaPushPayload payload)? onPut;

  @override
  Future<RemoteArea> putArea(AreaPushPayload payload) async {
    pushed.add(payload);
    await putGate?.future;
    if (putError != null) throw putError!;
    if (onPut != null) return onPut!(payload);
    final saved = RemoteArea(
      id: payload.id,
      name: payload.name,
      color: payload.color,
      position: payload.position,
      updatedAt: payload.updatedAt,
      deletedAt: payload.deletedAt,
      serverUpdatedAt: '2026-11-24T12:05:00.000Z',
    );
    serverAreas[payload.id] = saved;
    return saved;
  }

  @override
  Future<AreasPullResponse> pullAreas({String? since}) async {
    pulledSince.add(since);
    if (pullError != null) throw pullError!;
    return AreasPullResponse(areas: pullResponseAreas, cursor: nextCursor);
  }
}

class FakeGoalsRemote implements GoalsRemote {
  Exception? putError;
  Exception? pullError;
  Completer<void>? putGate;
  final List<GoalPushPayload> pushed = [];
  final List<String?> pulledSince = [];
  final Map<String, RemoteGoal> serverGoals = {};
  List<RemoteGoal> pullResponseGoals = [];
  String? nextCursor;
  RemoteGoal Function(GoalPushPayload payload)? onPut;

  @override
  Future<RemoteGoal> putGoal(GoalPushPayload payload) async {
    pushed.add(payload);
    await putGate?.future;
    if (putError != null) throw putError!;
    if (onPut != null) return onPut!(payload);
    final saved = RemoteGoal(
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
    serverGoals[payload.id] = saved;
    return saved;
  }

  @override
  Future<GoalsPullResponse> pullGoals({String? since}) async {
    pulledSince.add(since);
    if (pullError != null) throw pullError!;
    return GoalsPullResponse(goals: pullResponseGoals, cursor: nextCursor);
  }
}

class FakeGoalActionsRemote implements GoalActionsRemote {
  Exception? putError;
  Exception? pullError;
  Completer<void>? putGate;
  final List<GoalActionPushPayload> pushed = [];
  final List<String?> pulledSince = [];
  final Map<String, RemoteGoalAction> serverActions = {};
  List<RemoteGoalAction> pullResponseActions = [];
  String? nextCursor;
  RemoteGoalAction Function(GoalActionPushPayload payload)? onPut;

  @override
  Future<RemoteGoalAction> putGoalAction(GoalActionPushPayload payload) async {
    pushed.add(payload);
    await putGate?.future;
    if (putError != null) throw putError!;
    if (onPut != null) return onPut!(payload);
    final saved = RemoteGoalAction(
      id: payload.id,
      goalId: payload.goalId,
      title: payload.title,
      kind: payload.kind,
      done: payload.done,
      position: payload.position,
      updatedAt: payload.updatedAt,
      deletedAt: payload.deletedAt,
      serverUpdatedAt: '2026-11-24T12:05:00.000Z',
    );
    serverActions[payload.id] = saved;
    return saved;
  }

  @override
  Future<GoalActionsPullResponse> pullGoalActions({String? since}) async {
    pulledSince.add(since);
    if (pullError != null) throw pullError!;
    return GoalActionsPullResponse(
      goalActions: pullResponseActions,
      cursor: nextCursor,
    );
  }
}
