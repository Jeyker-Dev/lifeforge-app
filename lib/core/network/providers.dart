import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/http_auth_gateway.dart';
import '../../features/auth/data/secure_token_store.dart';
import '../../features/auth/domain/auth.dart';
import '../../features/auth/presentation/auth_controller.dart';
import 'auth_interceptor.dart';
import 'token_refresher.dart';

/// API base URL, set with `--dart-define=API_BASE_URL=...`.
///
/// Defaults to the host machine as seen from the Android emulator.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: apiBaseUrl,
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 15),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => HttpAuthGateway(Dio(_baseOptions())),
);

final tokenRefresherProvider = Provider<TokenRefresher>(
  (ref) => TokenRefresher(
    ref.watch(tokenStoreProvider),
    ref.watch(authGatewayProvider),
  ),
);

/// HTTP client for authenticated API calls.
final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(_baseOptions());
  dio.interceptors.add(
    AuthInterceptor(
      store: ref.watch(tokenStoreProvider),
      refresher: ref.watch(tokenRefresherProvider),
      retryClient: Dio(_baseOptions()),
      onSessionExpired: () =>
          ref.read(authControllerProvider.notifier).markSignedOut(),
    ),
  );
  return dio;
});
