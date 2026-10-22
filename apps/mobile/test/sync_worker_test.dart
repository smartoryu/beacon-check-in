import 'dart:async';
import 'dart:io';

import 'package:beacon_check_in/core/api/api_client.dart';
import 'package:beacon_check_in/core/api/api_exception.dart';
import 'package:beacon_check_in/core/auth/token_storage.dart';
import 'package:beacon_check_in/core/models/api_models.dart';
import 'package:beacon_check_in/core/offline/checkin_queue.dart';
import 'package:beacon_check_in/core/offline/connectivity_service.dart';
import 'package:beacon_check_in/core/offline/sync_worker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

class _FakeTokenStorage extends TokenStorage {
  @override
  Future<String?> readAccessToken() async => 'token';
  @override
  Future<String?> readRefreshToken() async => 'refresh';
  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}
  @override
  Future<void> clear() async {}
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(this.behavior) : super(tokenStorage: _FakeTokenStorage());

  final String behavior; // accepted | retryable | rejected

  @override
  Future<SubmitCheckinResponse> submitCheckin({
    required String eventId,
    required String clientCheckinId,
    required DateTime recordedAt,
    required List<CheckinReadingInput> readings,
    Map<String, dynamic>? deviceInfo,
  }) async {
    if (behavior == 'retryable') {
      throw ApiException(0, 'offline');
    }
    if (behavior == 'rejected') {
      throw ApiException(400, 'not enough beacons', reason: 'not_enough_beacons');
    }
    return SubmitCheckinResponse(
      checkin: Checkin(
        id: 'server-1',
        clientCheckinId: clientCheckinId,
        eventId: eventId,
        userId: 'user-1',
        status: 'accepted',
        recordedAt: recordedAt,
        receivedAt: DateTime.now().toUtc(),
        usedBeaconCount: readings.length,
      ),
      duplicate: false,
    );
  }
}

class _FakeConnectivity extends ConnectivityService {
  @override
  Future<bool> isOnline() async => true;
  @override
  Stream<bool> get onlineChanges => Stream<bool>.value(true);
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('beacon_sync_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  QueuedCheckin item() {
    final now = DateTime.now().toUtc();
    return QueuedCheckin(
      clientCheckinId: 'client-1',
      eventId: 'event-1',
      eventTitle: 'Demo',
      userId: 'user-1',
      recordedAt: now,
      readings: const [
        CheckinReadingInput(
          identityKey: 'uuid:1:1',
          rssiSamples: [-60],
          txPower: -59,
        ),
      ],
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
  }

  test('marks accepted check-ins as synced', () async {
    final box = await Hive.openBox<dynamic>('sync_accepted');
    final queue = CheckinQueue(box: box);
    await queue.enqueue(item());
    final worker = SyncWorker(
      queue: queue,
      api: _FakeApiClient('accepted'),
      tokenStorage: _FakeTokenStorage(),
      currentUserId: () => 'user-1',
      connectivity: _FakeConnectivity(),
    );

    await worker.syncNow();
    expect(queue.get('client-1')!.status, 'synced');
    expect(queue.get('client-1')!.serverCheckinId, 'server-1');
    await worker.dispose();
    await box.close();
  });

  test('keeps retryable failures pending with backoff', () async {
    final box = await Hive.openBox<dynamic>('sync_retry');
    final queue = CheckinQueue(box: box);
    await queue.enqueue(item());
    final worker = SyncWorker(
      queue: queue,
      api: _FakeApiClient('retryable'),
      tokenStorage: _FakeTokenStorage(),
      currentUserId: () => 'user-1',
      connectivity: _FakeConnectivity(),
    );

    await worker.syncNow();
    final queued = queue.get('client-1')!;
    expect(queued.status, 'pending');
    expect(queued.attempts, 1);
    expect(queued.nextAttemptAt, isNotNull);
    await worker.dispose();
    await box.close();
  });

  test('marks business rejections and keeps the reason', () async {
    final box = await Hive.openBox<dynamic>('sync_rejected');
    final queue = CheckinQueue(box: box);
    await queue.enqueue(item());
    final worker = SyncWorker(
      queue: queue,
      api: _FakeApiClient('rejected'),
      tokenStorage: _FakeTokenStorage(),
      currentUserId: () => 'user-1',
      connectivity: _FakeConnectivity(),
    );

    await worker.syncNow();
    final queued = queue.get('client-1')!;
    expect(queued.status, 'rejected');
    expect(queued.reason, 'not_enough_beacons');
    await worker.dispose();
    await box.close();
  });
}
