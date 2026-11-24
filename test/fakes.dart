import 'dart:async';

import 'package:lifeforge/features/areas/data/areas_remote.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';

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
