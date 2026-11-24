/// Access and refresh tokens issued by the LifeForge API.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

/// Whether the device holds a session with the API.
enum AuthStatus { signedIn, signedOut }

/// Base class for authentication failures shown to the user.
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

/// The email or password is wrong.
class InvalidCredentials extends AuthFailure {
  const InvalidCredentials();
}

/// The refresh token is no longer valid; the user must sign in again.
class SessionExpired extends AuthFailure {
  const SessionExpired();
}

/// The API could not be reached.
class NetworkFailure extends AuthFailure {
  const NetworkFailure();
}

/// Persists the session tokens on the device.
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

/// Talks to the API authentication endpoints.
abstract interface class AuthGateway {
  /// Throws [InvalidCredentials] or [NetworkFailure].
  Future<AuthTokens> login({required String email, required String password});

  /// Throws [SessionExpired] or [NetworkFailure].
  Future<AuthTokens> refresh(String refreshToken);

  /// Revokes the session on the server. Never throws.
  Future<void> logout(String refreshToken);
}
