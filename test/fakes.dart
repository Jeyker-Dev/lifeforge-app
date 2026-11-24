import 'dart:async';

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
