import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/network/token_refresher.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';

import '../../fakes.dart';

void main() {
  const stored = AuthTokens(accessToken: 'old', refreshToken: 'refresh-old');

  test('concurrent refreshes share one request to the API', () async {
    final store = InMemoryTokenStore(stored);
    final gateway = FakeAuthGateway()..refreshGate = Completer<void>();
    final refresher = TokenRefresher(store, gateway);

    final first = refresher.refresh();
    final second = refresher.refresh();
    gateway.refreshGate!.complete();
    final results = await Future.wait([first, second]);

    expect(gateway.refreshCalls, 1);
    expect(gateway.refreshedWith, ['refresh-old']);
    expect(results[0]!.accessToken, 'access-1-new');
    expect(results[1]!.accessToken, 'access-1-new');
    expect(store.tokens!.refreshToken, 'refresh-1-new');
  });

  test('a later refresh after completion sends the rotated token', () async {
    final store = InMemoryTokenStore(stored);
    final gateway = FakeAuthGateway();
    final refresher = TokenRefresher(store, gateway);

    await refresher.refresh();
    await refresher.refresh();

    expect(gateway.refreshedWith, ['refresh-old', 'refresh-1-new']);
  });

  test('an expired session clears the store and returns null', () async {
    final store = InMemoryTokenStore(stored);
    final gateway = FakeAuthGateway()..refreshFailure = const SessionExpired();

    final result = await TokenRefresher(store, gateway).refresh();

    expect(result, isNull);
    expect(store.tokens, isNull);
  });

  test('a network failure keeps the stored session and rethrows', () async {
    final store = InMemoryTokenStore(stored);
    final gateway = FakeAuthGateway()..refreshFailure = const NetworkFailure();

    await expectLater(
      TokenRefresher(store, gateway).refresh(),
      throwsA(isA<NetworkFailure>()),
    );
    expect(store.tokens, same(stored));
  });

  test(
    'without a stored session it returns null without calling the API',
    () async {
      final gateway = FakeAuthGateway();

      final result = await TokenRefresher(
        InMemoryTokenStore(),
        gateway,
      ).refresh();

      expect(result, isNull);
      expect(gateway.refreshCalls, 0);
    },
  );
}
