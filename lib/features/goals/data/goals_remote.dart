import 'package:dio/dio.dart';

import '../../../core/sync/sync_exceptions.dart';

/// Payload sent on `PUT /goals/{id}`.
class GoalPushPayload {
  const GoalPushPayload({
    required this.id,
    required this.areaId,
    required this.title,
    this.why,
    this.targetDate,
    required this.metricCurrent,
    required this.metricTarget,
    required this.metricUnit,
    required this.weeklyHoursTarget,
    required this.status,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String areaId;
  final String title;
  final String? why;
  final String? targetDate;
  final double metricCurrent;
  final double metricTarget;
  final String metricUnit;
  final double weeklyHoursTarget;
  final String status;
  final String updatedAt;
  final String? deletedAt;

  Map<String, dynamic> toJson() => {
    'area_id': areaId,
    'title': title,
    'why': why,
    'target_date': targetDate,
    'metric_current': metricCurrent,
    'metric_target': metricTarget,
    'metric_unit': metricUnit,
    'weekly_hours_target': weeklyHoursTarget,
    'status': status,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// Canonical goal record returned by the API.
class RemoteGoal {
  const RemoteGoal({
    required this.id,
    required this.areaId,
    required this.title,
    required this.why,
    required this.targetDate,
    required this.metricCurrent,
    required this.metricTarget,
    required this.metricUnit,
    required this.weeklyHoursTarget,
    required this.status,
    required this.updatedAt,
    required this.deletedAt,
    required this.serverUpdatedAt,
  });

  factory RemoteGoal.fromJson(Map<String, dynamic> json) => RemoteGoal(
    id: json['id'] as String,
    areaId: json['area_id'] as String,
    title: json['title'] as String,
    why: json['why'] as String?,
    targetDate: json['target_date'] as String?,
    metricCurrent: (json['metric_current'] as num).toDouble(),
    metricTarget: (json['metric_target'] as num).toDouble(),
    metricUnit: json['metric_unit'] as String,
    weeklyHoursTarget: (json['weekly_hours_target'] as num).toDouble(),
    status: json['status'] as String,
    updatedAt: json['updated_at'] as String,
    deletedAt: json['deleted_at'] as String?,
    serverUpdatedAt: json['server_updated_at'] as String,
  );

  final String id;
  final String areaId;
  final String title;
  final String? why;
  final String? targetDate;
  final double metricCurrent;
  final double metricTarget;
  final String metricUnit;
  final double weeklyHoursTarget;
  final String status;
  final String updatedAt;
  final String? deletedAt;
  final String serverUpdatedAt;
}

/// Response of `GET /goals`.
class GoalsPullResponse {
  const GoalsPullResponse({required this.goals, required this.cursor});

  factory GoalsPullResponse.fromJson(Map<String, dynamic> json) =>
      GoalsPullResponse(
        goals: (json['goals'] as List<dynamic>)
            .map((item) => RemoteGoal.fromJson(item as Map<String, dynamic>))
            .toList(),
        cursor: json['cursor'] as String?,
      );

  final List<RemoteGoal> goals;
  final String? cursor;
}

/// Gateway to the `/goals` endpoints on the LifeForge API.
abstract interface class GoalsRemote {
  /// Pushes a local goal with `PUT /goals/{id}` and returns the version the
  /// server kept.
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<RemoteGoal> putGoal(GoalPushPayload payload);

  /// Pulls goals changed since [since] (or all goals when [since] is null).
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<GoalsPullResponse> pullGoals({String? since});
}

/// [GoalsRemote] backed by an authenticated [Dio] client.
class HttpGoalsRemote implements GoalsRemote {
  HttpGoalsRemote(this._dio);

  final Dio _dio;

  @override
  Future<RemoteGoal> putGoal(GoalPushPayload payload) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/goals/${payload.id}',
        data: payload.toJson(),
      );
      return RemoteGoal.fromJson(response.data!);
    } on DioException catch (error) {
      throwMappedDioSyncError(error);
    }
  }

  @override
  Future<GoalsPullResponse> pullGoals({String? since}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/goals',
        queryParameters: since == null ? null : {'since': since},
      );
      return GoalsPullResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throwMappedDioSyncError(error);
    }
  }
}
