import 'package:dio/dio.dart';

import '../domain/auth.dart';

/// [AuthGateway] over the API `/auth` endpoints.
///
/// Uses a [Dio] without the auth interceptor so that refreshing never
/// triggers another refresh.
class HttpAuthGateway implements AuthGateway {
  HttpAuthGateway(this._dio);

  final Dio _dio;

  @override
  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/token',
        data: {'username': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _toTokens(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) throw const InvalidCredentials();
      throw const NetworkFailure();
    }
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return _toTokens(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) throw const SessionExpired();
      throw const NetworkFailure();
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<void>(
        '/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException {
      // Local sign-out must succeed even when the server is unreachable.
    }
  }

  AuthTokens _toTokens(Map<String, dynamic> json) => AuthTokens(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );
}
