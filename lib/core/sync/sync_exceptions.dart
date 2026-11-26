import 'package:dio/dio.dart';

/// The server could not be reached or returned a 5xx response.
class SyncNetworkException implements Exception {
  const SyncNetworkException();
}

/// The server rejected the request with a 4xx status code.
class SyncClientException implements Exception {
  const SyncClientException(this.statusCode);

  final int statusCode;
}

/// Maps a [DioException] from a sync endpoint to a [SyncClientException] on
/// 4xx responses or a [SyncNetworkException] otherwise.
Never throwMappedDioSyncError(DioException error) {
  final code = error.response?.statusCode;
  if (code != null && code >= 400 && code < 500) {
    throw SyncClientException(code);
  }
  throw const SyncNetworkException();
}
