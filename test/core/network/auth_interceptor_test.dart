import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifeforge/core/network/auth_interceptor.dart';
import 'package:lifeforge/core/network/token_refresher.dart';
import 'package:lifeforge/features/auth/domain/auth.dart';

import '../../fakes.dart';

/// Answers 200 only to a valid bearer token and records each request.
class _ApiAdapter implements HttpClientAdapter {
  _ApiAdapter(this.validToken);

  String validToken;
  final List<String?> authHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final header = options.headers['Authorization'] as String?;
    authHeaders.add(header);
    final ok = header == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode(ok ? {'email': 'me@example.com'} : {'detail': 'no'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStore store;
  late FakeAuthGateway gateway;
  late _ApiAdapter adapter;
  late int expiredCalls;

  Dio buildClient() {
    final retry = Dio()..httpClientAdapter = adapter;
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        store: store,
        refresher: TokenRefresher(store, gateway),
        retryClient: retry,
        onSessionExpired: () => expiredCalls++,
      ),
    );
    return dio;
  }

  setUp(() {
    store = InMemoryTokenStore(
      const AuthTokens(accessToken: 'old', refreshToken: 'refresh-old'),
    );
    gateway = FakeAuthGateway();
    expiredCalls = 0;
  });

  test('sends the stored access token as a bearer header', () async {
    adapter = _ApiAdapter('old');

    final response = await buildClient().get<dynamic>('/users/me');

    expect(response.statusCode, 200);
    expect(adapter.authHeaders, ['Bearer old']);
    expect(gateway.refreshCalls, 0);
  });

  test('on 401 it refreshes once and retries with the new token', () async {
    adapter = _ApiAdapter('access-1-new');

    final response = await buildClient().get<dynamic>('/users/me');

    expect(response.statusCode, 200);
    expect(adapter.authHeaders, ['Bearer old', 'Bearer access-1-new']);
    expect(gateway.refreshCalls, 1);
    expect(store.tokens!.accessToken, 'access-1-new');
  });

  test('parallel 401s trigger a single refresh', () async {
    adapter = _ApiAdapter('access-1-new');
    final dio = buildClient();

    final responses = await Future.wait([
      dio.get<dynamic>('/users/me'),
      dio.get<dynamic>('/users/me'),
    ]);

    expect(responses.map((r) => r.statusCode), [200, 200]);
    expect(gateway.refreshCalls, 1);
  });

  test('when the session expired it signs out and returns the 401', () async {
    adapter = _ApiAdapter('never');
    gateway.refreshFailure = const SessionExpired();

    await expectLater(
      buildClient().get<dynamic>('/users/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(expiredCalls, 1);
    expect(store.tokens, isNull);
  });

  test('a retry that still fails is not refreshed again', () async {
    adapter = _ApiAdapter('never');

    await expectLater(
      buildClient().get<dynamic>('/users/me'),
      throwsA(isA<DioException>()),
    );
    expect(gateway.refreshCalls, 1);
    expect(adapter.authHeaders, ['Bearer old', 'Bearer access-1-new']);
  });

  test('a network failure while refreshing keeps the session', () async {
    adapter = _ApiAdapter('never');
    gateway.refreshFailure = const NetworkFailure();

    await expectLater(
      buildClient().get<dynamic>('/users/me'),
      throwsA(isA<DioException>()),
    );
    expect(expiredCalls, 0);
    expect(store.tokens!.refreshToken, 'refresh-old');
  });
}
