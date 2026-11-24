import 'package:dio/dio.dart';

/// Payload sent on `PUT /areas/{id}`.
class AreaPushPayload {
  const AreaPushPayload({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final String color;
  final int position;
  final String updatedAt;
  final String? deletedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'color': color,
    'position': position,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// Canonical area record returned by the API.
class RemoteArea {
  const RemoteArea({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.updatedAt,
    required this.deletedAt,
    required this.serverUpdatedAt,
  });

  factory RemoteArea.fromJson(Map<String, dynamic> json) => RemoteArea(
    id: json['id'] as String,
    name: json['name'] as String,
    color: json['color'] as String,
    position: json['position'] as int,
    updatedAt: json['updated_at'] as String,
    deletedAt: json['deleted_at'] as String?,
    serverUpdatedAt: json['server_updated_at'] as String,
  );

  final String id;
  final String name;
  final String color;
  final int position;
  final String updatedAt;
  final String? deletedAt;
  final String serverUpdatedAt;
}

/// Response of `GET /areas`.
class AreasPullResponse {
  const AreasPullResponse({required this.areas, required this.cursor});

  factory AreasPullResponse.fromJson(Map<String, dynamic> json) =>
      AreasPullResponse(
        areas: (json['areas'] as List<dynamic>)
            .map((item) => RemoteArea.fromJson(item as Map<String, dynamic>))
            .toList(),
        cursor: json['cursor'] as String?,
      );

  final List<RemoteArea> areas;
  final String? cursor;
}

/// The server could not be reached or returned a 5xx response.
class SyncNetworkException implements Exception {
  const SyncNetworkException();
}

/// The server rejected the request with a 4xx status code.
class SyncClientException implements Exception {
  const SyncClientException(this.statusCode);

  final int statusCode;
}

/// Gateway to the `/areas` endpoints on the LifeForge API.
abstract interface class AreasRemote {
  /// Pushes a local area with `PUT /areas/{id}` and returns the version the
  /// server kept.
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<RemoteArea> putArea(AreaPushPayload payload);

  /// Pulls areas changed since [since] (or all areas when [since] is null).
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<AreasPullResponse> pullAreas({String? since});
}

/// [AreasRemote] backed by an authenticated [Dio] client.
class HttpAreasRemote implements AreasRemote {
  HttpAreasRemote(this._dio);

  final Dio _dio;

  @override
  Future<RemoteArea> putArea(AreaPushPayload payload) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/areas/${payload.id}',
        data: payload.toJson(),
      );
      return RemoteArea.fromJson(response.data!);
    } on DioException catch (error) {
      _throwMapped(error);
    }
  }

  @override
  Future<AreasPullResponse> pullAreas({String? since}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/areas',
        queryParameters: since == null ? null : {'since': since},
      );
      return AreasPullResponse.fromJson(response.data!);
    } on DioException catch (error) {
      _throwMapped(error);
    }
  }

  Never _throwMapped(DioException error) {
    final code = error.response?.statusCode;
    if (code != null && code >= 400 && code < 500) {
      throw SyncClientException(code);
    }
    throw const SyncNetworkException();
  }
}
