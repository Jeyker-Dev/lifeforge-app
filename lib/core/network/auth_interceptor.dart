import 'package:dio/dio.dart';

import '../../features/auth/domain/auth.dart';
import 'token_refresher.dart';

/// Adds the bearer token and, on a 401, refreshes once and retries.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore store,
    required TokenRefresher refresher,
    required Dio retryClient,
    required void Function() onSessionExpired,
  }) : _store = store,
       _refresher = refresher,
       _retryClient = retryClient,
       _onSessionExpired = onSessionExpired;

  static const _retriedFlag = 'auth_retried';

  final TokenStore _store;
  final TokenRefresher _refresher;
  final Dio _retryClient;
  final void Function() _onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _store.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized || request.extra[_retriedFlag] == true) {
      return handler.next(err);
    }

    final AuthTokens? tokens;
    try {
      tokens = await _freshTokens(request);
    } on NetworkFailure {
      return handler.next(err);
    }
    if (tokens == null) {
      _onSessionExpired();
      return handler.next(err);
    }

    request.extra[_retriedFlag] = true;
    request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    try {
      handler.resolve(await _retryClient.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Reuses tokens that another request already refreshed; refreshes
  /// only when the failed request used the current access token.
  Future<AuthTokens?> _freshTokens(RequestOptions request) async {
    final stored = await _store.read();
    final sentHeader = request.headers['Authorization'];
    if (stored != null && sentHeader != 'Bearer ${stored.accessToken}') {
      return stored;
    }
    return _refresher.refresh();
  }
}
