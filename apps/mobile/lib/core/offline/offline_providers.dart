import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../providers.dart';
import 'checkin_queue.dart';
import 'connectivity_service.dart';
import 'event_cache.dart';
import 'sync_worker.dart';

final checkinQueueProvider = Provider<CheckinQueue>((ref) => CheckinQueue());

final eventCacheProvider = Provider<EventCache>((ref) => EventCache());

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  final worker = SyncWorker(
    queue: ref.watch(checkinQueueProvider),
    api: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    currentUserId: () => ref.read(authControllerProvider).user?.id,
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(worker.dispose);
  return worker;
});
