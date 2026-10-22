import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../auth/token_storage.dart';
import 'checkin_queue.dart';
import 'connectivity_service.dart';

class SyncWorker {
  SyncWorker({
    required this.queue,
    required this.api,
    required this.tokenStorage,
    required this.currentUserId,
    ConnectivityService? connectivity,
  }) : _connectivity = connectivity ?? ConnectivityService();

  final CheckinQueue queue;
  final ApiClient api;
  final TokenStorage tokenStorage;
  final String? Function() currentUserId;
  final ConnectivityService _connectivity;

  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _timer;
  bool _started = false;
  bool _syncing = false;

  final ValueNotifier<bool> syncing = ValueNotifier(false);
  final ValueNotifier<bool> online = ValueNotifier(true);
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    online.value = await _connectivity.isOnline();
    _connectivitySubscription = _connectivity.onlineChanges.listen((isOnline) {
      online.value = isOnline;
      if (isOnline) unawaited(syncNow());
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (online.value) unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    if (_syncing) return;
    final userId = currentUserId();
    if (userId == null) return;
    if (!await _connectivity.isOnline()) {
      online.value = false;
      return;
    }

    final pending = queue.pendingForSync(userId);
    if (pending.isEmpty) return;

    _syncing = true;
    syncing.value = true;
    try {
      for (final item in pending) {
        if (item.status == 'syncing') continue;
        await queue.save(item.copyWith(status: 'syncing', clearError: true));
        try {
          final response = await api.submitCheckin(
            eventId: item.eventId,
            clientCheckinId: item.clientCheckinId,
            recordedAt: item.recordedAt,
            readings: item.readings,
            deviceInfo: item.deviceInfo,
          );
          if (response.checkin.isAccepted) {
            await queue.save(
              item.copyWith(
                status: 'synced',
                serverCheckinId: response.checkin.id,
                clearError: true,
                clearNextAttempt: true,
              ),
            );
          } else {
            await queue.save(
              item.copyWith(
                status: 'rejected',
                reason: response.reason ?? response.checkin.rejectReason,
                serverCheckinId: response.checkin.id,
                clearError: true,
                clearNextAttempt: true,
              ),
            );
          }
        } on ApiException catch (error) {
          if (error.isAuth) {
            lastError.value = 'Sign in again to sync queued check-ins.';
            await queue.save(item.copyWith(status: 'pending', lastError: error.message));
            break;
          }
          if (error.isRetryable) {
            final attempts = item.attempts + 1;
            await queue.save(
              item.copyWith(
                status: 'pending',
                attempts: attempts,
                lastError: error.message,
                nextAttemptAt: CheckinQueue.nextAttempt(attempts),
              ),
            );
            lastError.value = error.message;
            break;
          }
          await queue.save(
            item.copyWith(
              status: 'rejected',
              reason: error.reason ?? error.message,
              lastError: error.message,
              clearNextAttempt: true,
            ),
          );
        } catch (error) {
          final attempts = item.attempts + 1;
          await queue.save(
            item.copyWith(
              status: 'pending',
              attempts: attempts,
              lastError: error.toString(),
              nextAttemptAt: CheckinQueue.nextAttempt(attempts),
            ),
          );
          lastError.value = error.toString();
          break;
        }
      }
    } finally {
      _syncing = false;
      syncing.value = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySubscription?.cancel();
    syncing.dispose();
    online.dispose();
    lastError.dispose();
  }
}
