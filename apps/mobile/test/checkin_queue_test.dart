import 'dart:io';

import 'package:beacon_check_in/core/models/api_models.dart';
import 'package:beacon_check_in/core/offline/checkin_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('beacon_queue_test');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  QueuedCheckin item({
    required String id,
    required String userId,
    String status = 'pending',
    DateTime? nextAttemptAt,
  }) {
    final now = DateTime.now().toUtc();
    return QueuedCheckin(
      clientCheckinId: id,
      eventId: 'event-1',
      eventTitle: 'Demo event',
      userId: userId,
      recordedAt: now,
      readings: const [
        CheckinReadingInput(
          identityKey: 'uuid:1:1',
          rssiSamples: [-60, -62],
          txPower: -59,
        ),
      ],
      status: status,
      createdAt: now,
      updatedAt: now,
      nextAttemptAt: nextAttemptAt,
    );
  }

  test('persists queued check-ins and filters by user', () async {
    final box = await Hive.openBox<dynamic>('queue_persist');
    final queue = CheckinQueue(box: box);

    await queue.enqueue(item(id: 'a', userId: 'user-1'));
    await queue.enqueue(item(id: 'b', userId: 'user-2'));

    expect(queue.all().length, 2);
    expect(queue.forUser('user-1').single.clientCheckinId, 'a');
    expect(queue.pendingCountForUser('user-1'), 1);
    await box.close();
  });

  test('only returns pending items whose backoff has elapsed', () async {
    final box = await Hive.openBox<dynamic>('queue_backoff');
    final queue = CheckinQueue(box: box);
    final future = DateTime.now().toUtc().add(const Duration(minutes: 5));

    await queue.enqueue(item(id: 'ready', userId: 'user-1'));
    await queue.enqueue(
      item(id: 'waiting', userId: 'user-1', nextAttemptAt: future),
    );
    await queue.enqueue(item(id: 'done', userId: 'user-1', status: 'synced'));

    final pending = queue.pendingForSync('user-1');
    expect(pending.map((entry) => entry.clientCheckinId), ['ready']);
    await box.close();
  });

  test('round-trips the queue record through Hive', () async {
    final box = await Hive.openBox<dynamic>('queue_roundtrip');
    final queue = CheckinQueue(box: box);
    final original = item(id: 'roundtrip', userId: 'user-1');

    await queue.enqueue(original);
    final loaded = queue.get('roundtrip');

    expect(loaded, isNotNull);
    expect(loaded!.eventTitle, 'Demo event');
    expect(loaded.readings.single.rssiSamples, [-60, -62]);
    expect(loaded.readings.single.txPower, -59);
    await box.close();
  });

  test('backoff grows with attempts', () {
    final first = CheckinQueue.nextAttempt(0);
    final last = CheckinQueue.nextAttempt(10);
    expect(first.isAfter(DateTime.now().toUtc()), isTrue);
    expect(last.difference(DateTime.now().toUtc()).inMinutes, greaterThan(20));
  });
}
