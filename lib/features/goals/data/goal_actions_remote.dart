import 'package:dio/dio.dart';

import '../../../core/sync/sync_exceptions.dart';

/// Payload sent on `PUT /goal-actions/{id}`.
class GoalActionPushPayload {
  const GoalActionPushPayload({
    required this.id,
    required this.goalId,
    required this.title,
    required this.kind,
    required this.done,
    required this.position,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String goalId;
  final String title;
  final String kind;
  final bool done;
  final int position;
  final String updatedAt;
  final String? deletedAt;

  Map<String, dynamic> toJson() => {
    'goal_id': goalId,
    'title': title,
    'kind': kind,
    'done': done,
    'position': position,
    'updated_at': updatedAt,
    'deleted_at': deletedAt,
  };
}

/// Canonical goal action record returned by the API.
class RemoteGoalAction {
  const RemoteGoalAction({
    required this.id,
    required this.goalId,
    required this.title,
    required this.kind,
    required this.done,
    required this.position,
    required this.updatedAt,
    required this.deletedAt,
    required this.serverUpdatedAt,
  });

  factory RemoteGoalAction.fromJson(Map<String, dynamic> json) =>
      RemoteGoalAction(
        id: json['id'] as String,
        goalId: json['goal_id'] as String,
        title: json['title'] as String,
        kind: json['kind'] as String,
        done: json['done'] as bool,
        position: json['position'] as int,
        updatedAt: json['updated_at'] as String,
        deletedAt: json['deleted_at'] as String?,
        serverUpdatedAt: json['server_updated_at'] as String,
      );

  final String id;
  final String goalId;
  final String title;
  final String kind;
  final bool done;
  final int position;
  final String updatedAt;
  final String? deletedAt;
  final String serverUpdatedAt;
}

/// Response of `GET /goal-actions`.
class GoalActionsPullResponse {
  const GoalActionsPullResponse({
    required this.goalActions,
    required this.cursor,
  });

  factory GoalActionsPullResponse.fromJson(Map<String, dynamic> json) =>
      GoalActionsPullResponse(
        goalActions: (json['goal_actions'] as List<dynamic>)
            .map(
              (item) => RemoteGoalAction.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        cursor: json['cursor'] as String?,
      );

  final List<RemoteGoalAction> goalActions;
  final String? cursor;
}

/// Gateway to the `/goal-actions` endpoints on the LifeForge API.
abstract interface class GoalActionsRemote {
  /// Pushes a local goal action with `PUT /goal-actions/{id}` and returns the
  /// version the server kept.
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<RemoteGoalAction> putGoalAction(GoalActionPushPayload payload);

  /// Pulls goal actions changed since [since] (or all when [since] is null).
  ///
  /// Throws [SyncNetworkException] on connectivity/server errors or
  /// [SyncClientException] on 4xx responses.
  Future<GoalActionsPullResponse> pullGoalActions({String? since});
}

/// [GoalActionsRemote] backed by an authenticated [Dio] client.
class HttpGoalActionsRemote implements GoalActionsRemote {
  HttpGoalActionsRemote(this._dio);

  final Dio _dio;

  @override
  Future<RemoteGoalAction> putGoalAction(GoalActionPushPayload payload) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/goal-actions/${payload.id}',
        data: payload.toJson(),
      );
      return RemoteGoalAction.fromJson(response.data!);
    } on DioException catch (error) {
      throwMappedDioSyncError(error);
    }
  }

  @override
  Future<GoalActionsPullResponse> pullGoalActions({String? since}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/goal-actions',
        queryParameters: since == null ? null : {'since': since},
      );
      return GoalActionsPullResponse.fromJson(response.data!);
    } on DioException catch (error) {
      throwMappedDioSyncError(error);
    }
  }
}
