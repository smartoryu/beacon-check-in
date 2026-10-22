import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/api_models.dart';

class CachedEvents {
  const CachedEvents({required this.events, required this.cachedAt});

  final List<Event> events;
  final DateTime? cachedAt;

  bool get isEmpty => cachedAt == null;
}

class EventCache {
  EventCache({Box<dynamic>? box}) : _box = box ?? Hive.box<dynamic>('event_cache');

  final Box<dynamic> _box;

  Future<void> saveActive(List<Event> events) async {
    await _box.put('active', {
      'cached_at': DateTime.now().toUtc().toIso8601String(),
      'events': events.map((event) => event.toJson()).toList(),
    });
  }

  CachedEvents readActive() {
    final raw = _box.get('active');
    if (raw == null) return const CachedEvents(events: [], cachedAt: null);
    final map = Map<String, dynamic>.from(raw as Map);
    final cachedAt = DateTime.tryParse((map['cached_at'] ?? '') as String);
    final events = ((map['events'] as List<dynamic>?) ?? const [])
        .map((item) => Event.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    return CachedEvents(events: events, cachedAt: cachedAt);
  }

  Event? find(String eventId) {
    for (final event in readActive().events) {
      if (event.id == eventId) return event;
    }
    return null;
  }

  Future<void> clear() async {
    await _box.delete('active');
  }
}
