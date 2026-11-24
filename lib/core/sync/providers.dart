import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/areas/data/areas_remote.dart';
import '../../features/areas/data/drift_area_repository.dart';
import '../../features/areas/domain/area.dart';
import '../../features/areas/domain/area_repository.dart';
import '../../features/auth/domain/auth.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../db/database_provider.dart';
import '../network/providers.dart';
import 'sync_service.dart';

final areasRemoteProvider = Provider<AreasRemote>(
  (ref) => HttpAreasRemote(ref.watch(apiClientProvider)),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => SyncService(
    ref.watch(appDatabaseProvider),
    ref.watch(areasRemoteProvider),
  ),
);

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(syncServiceProvider);
  return DriftAreaRepository(db, onWrite: () => unawaited(sync.syncAreas()));
});

final areasStreamProvider = StreamProvider<List<Area>>(
  (ref) => ref.watch(areaRepositoryProvider).watchAll(),
);

/// Emits connectivity transitions from [Connectivity.onConnectivityChanged].
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>(
  (ref) => Connectivity().onConnectivityChanged,
);

/// Triggers [SyncService.syncAreas] when signed in at startup and whenever
/// connectivity returns.
final syncTriggerProvider = Provider<void>((ref) {
  final auth = ref.watch(authControllerProvider).value;
  if (auth != AuthStatus.signedIn) return;

  final sync = ref.watch(syncServiceProvider);
  unawaited(sync.syncAreas());

  ref.listen<AsyncValue<List<ConnectivityResult>>>(connectivityStreamProvider, (
    previous,
    next,
  ) {
    final results = next.value;
    if (results == null) return;
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (isOnline) {
      unawaited(sync.syncAreas());
    }
  });
});
