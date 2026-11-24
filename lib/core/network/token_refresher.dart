import '../../features/auth/domain/auth.dart';

/// Refreshes the session with at most one request in flight.
///
/// The API rotates refresh tokens and revokes the whole session when an
/// old one is reused, so two parallel refreshes would sign the user out.
/// Concurrent callers share the same pending refresh.
class TokenRefresher {
  TokenRefresher(this._store, this._gateway);

  final TokenStore _store;
  final AuthGateway _gateway;
  Future<AuthTokens?>? _inFlight;

  /// Returns the new tokens, or null when the session is gone.
  ///
  /// Throws [NetworkFailure] when the API cannot be reached; the stored
  /// session is kept so a later retry can still refresh it.
  Future<AuthTokens?> refresh() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<AuthTokens?> _run() async {
    final current = await _store.read();
    if (current == null) return null;
    try {
      final tokens = await _gateway.refresh(current.refreshToken);
      await _store.save(tokens);
      return tokens;
    } on SessionExpired {
      await _store.clear();
      return null;
    }
  }
}
