import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/api_models.dart';

class QueuedCheckin {
  const QueuedCheckin({
    required this.clientCheckinId,
    required this.eventId,
    required this.eventTitle,
    required this.userId,
    required this.recordedAt,
    required this.readings,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.deviceInfo,
    this.reason,
    this.lastError,
    this.serverCheckinId,
    this.attempts = 0,
    this.nextAttemptAt,
  });

  final String clientCheckinId;
  final String eventId;
  final String eventTitle;
  final String userId;
  final DateTime recordedAt;
  final List<CheckinReadingInput> readings;
  final Map<String, dynamic>? deviceInfo;
  final String status; // pending|syncing|synced|rejected|failed
  final String? reason;
  final String? lastError;
  final String? serverCheckinId;
  final int attempts;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == 'pending' || status == 'syncing';
  bool get isSynced => status == 'synced';
  bool get isRejected => status == 'rejected';

  QueuedCheckin copyWith({
    String? status,
    String? reason,
    String? lastError,
    String? serverCheckinId,
    int? attempts,
    DateTime? nextAttemptAt,
    bool clearError = false,
    bool clearNextAttempt = false,
  }) =>
      QueuedCheckin(
        clientCheckinId: clientCheckinId,
        eventId: eventId,
        eventTitle: eventTitle,
        userId: userId,
        recordedAt: recordedAt,
        readings: readings,
        deviceInfo: deviceInfo,
        status: status ?? this.status,
        reason: reason ?? this.reason,
        lastError: clearError ? null : (lastError ?? this.lastError),
        serverCheckinId: serverCheckinId ?? this.serverCheckinId,
        attempts: attempts ?? this.attempts,
        nextAttemptAt:
            clearNextAttempt ? null : (nextAttemptAt ?? this.nextAttemptAt),
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toMap() => {
        'client_checkin_id': clientCheckinId,
        'event_id': eventId,
        'event_title': eventTitle,
        'user_id': userId,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'readings': readings.map((reading) => reading.toJson()).toList(),
        'device_info': deviceInfo,
        'status': status,
        'reason': reason,
        'last_error': lastError,
        'server_checkin_id': serverCheckinId,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory QueuedCheckin.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return QueuedCheckin(
      clientCheckinId: map['client_checkin_id'] as String,
      eventId: map['event_id'] as String,
      eventTitle: (map['event_title'] ?? '') as String,
      userId: (map['user_id'] ?? '') as String,
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      readings: ((map['readings'] as List<dynamic>?) ?? const [])
          .map((item) => CheckinReadingInput.fromJson(
                Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
      deviceInfo: map['device_info'] == null
          ? null
          : Map<String, dynamic>.from(map['device_info'] as Map),
      status: (map['status'] ?? 'pending') as String,
      reason: map['reason'] as String?,
      lastError: map['last_error'] as String?,
      serverCheckinId: map['server_checkin_id'] as String?,
      attempts: (map['attempts'] as num?)?.toInt() ?? 0,
      nextAttemptAt: map['next_attempt_at'] == null
          ? null
          : DateTime.parse(map['next_attempt_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class CheckinQueue {
  CheckinQueue({Box<dynamic>? box})
      : _box = box ?? Hive.box<dynamic>('checkin_queue');

  final Box<dynamic> _box;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  List<QueuedCheckin> all() {
    final items = _box.values
        .map((value) => QueuedCheckin.fromMap(value as Map<dynamic, dynamic>))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  List<QueuedCheckin> forUser(String userId) =>
      all().where((item) => item.userId == userId).toList();

  List<QueuedCheckin> pendingForSync(String userId) {
    final now = DateTime.now().toUtc();
    return all()
        .where((item) =>
            item.userId == userId &&
            item.isPending &&
            (item.nextAttemptAt == null || !item.nextAttemptAt!.isAfter(now)))
        .toList();
  }

  int pendingCountForUser(String userId) =>
      forUser(userId).where((item) => item.isPending).length;

  Future<void> enqueue(QueuedCheckin item) async {
    await _box.put(item.clientCheckinId, item.toMap());
    _changes.add(null);
  }

  Future<void> save(QueuedCheckin item) async {
    await _box.put(item.clientCheckinId, item.toMap());
    _changes.add(null);
  }

  QueuedCheckin? get(String clientCheckinId) {
    final raw = _box.get(clientCheckinId);
    if (raw == null) return null;
    return QueuedCheckin.fromMap(raw as Map<dynamic, dynamic>);
  }

  Future<void> clearForUser(String userId) async {
    final keys = forUser(userId).map((item) => item.clientCheckinId).toList();
    await _box.deleteAll(keys);
    _changes.add(null);
  }

  static DateTime nextAttempt(int attempts) {
    const delays = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 30),
    ];
    final index = attempts.clamp(0, delays.length - 1);
    return DateTime.now().toUtc().add(delays[index]);
  }
}
