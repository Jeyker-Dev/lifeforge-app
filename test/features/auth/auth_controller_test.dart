import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/network/providers.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';
import 'package:lifeforge/features/auth/presentation/auth_controller.dart';

import '../../fakes.dart';

void main() {
  late InMemoryTokenStore store;
  late FakeAuthGateway gateway;

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        authGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    store = InMemoryTokenStore();
    gateway = FakeAuthGateway();
  });

  test('starts signed out without stored tokens', () async {
    final container = buildContainer();

    expect(
      await container.read(authControllerProvider.future),
      AuthStatus.signedOut,
    );
  });

  test('starts signed in with stored tokens', () async {
    store.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    final container = buildContainer();

    expect(
      await container.read(authControllerProvider.future),
      AuthStatus.signedIn,
    );
  });

  test('login saves the tokens and signs in', () async {
    final container = buildContainer();
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .login(email: ' me@example.com ', password: 'secret');

    expect(store.tokens!.refreshToken, 'refresh-1');
    expect(container.read(authControllerProvider).value, AuthStatus.signedIn);
  });

  test('invalid credentials throw and keep the user signed out', () async {
    gateway.loginFailure = const InvalidCredentials();
    final container = buildContainer();
    await container.read(authControllerProvider.future);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .login(email: 'me@example.com', password: 'wrong'),
      throwsA(isA<InvalidCredentials>()),
    );
    expect(store.tokens, isNull);
    expect(container.read(authControllerProvider).value, AuthStatus.signedOut);
  });

  test('logout revokes the session and clears the tokens', () async {
    store.tokens = const AuthTokens(accessToken: 'a', refreshToken: 'r');
    final container = buildContainer();
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(gateway.loggedOut, ['r']);
    expect(store.tokens, isNull);
    expect(container.read(authControllerProvider).value, AuthStatus.signedOut);
  });
}
