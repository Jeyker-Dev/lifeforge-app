import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/providers.dart';
import '../domain/auth.dart';

/// Holds whether the user is signed in and runs login and logout.
class AuthController extends AsyncNotifier<AuthStatus> {
  @override
  Future<AuthStatus> build() async {
    final tokens = await ref.read(tokenStoreProvider).read();
    return tokens == null ? AuthStatus.signedOut : AuthStatus.signedIn;
  }

  /// Throws [InvalidCredentials] or [NetworkFailure] and stays signed out.
  Future<void> login({required String email, required String password}) async {
    final tokens = await ref
        .read(authGatewayProvider)
        .login(email: email.trim(), password: password);
    await ref.read(tokenStoreProvider).save(tokens);
    state = const AsyncData(AuthStatus.signedIn);
  }

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final tokens = await store.read();
    if (tokens != null) {
      await ref.read(authGatewayProvider).logout(tokens.refreshToken);
    }
    await store.clear();
    state = const AsyncData(AuthStatus.signedOut);
  }

  /// Called when the session can no longer be refreshed.
  void markSignedOut() => state = const AsyncData(AuthStatus.signedOut);
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthStatus>(AuthController.new);
