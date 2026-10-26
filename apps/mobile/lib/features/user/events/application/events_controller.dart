import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/providers.dart';

final eventsControllerProvider =
    AsyncNotifierProvider<EventsController, List<Event>>(EventsController.new);

class EventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() => _load(allowCache: true);

  Future<List<Event>> _load({required bool allowCache}) async {
    final cache = ref.read(eventCacheProvider);
    final cached = cache.readActive().events;
    try {
      final events = await ref.read(apiClientProvider).activeEvents();
      await cache.saveActive(events);
      return events;
    } catch (error) {
      if (allowCache && cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      // Keep the current list visible while the explicit refresh runs.
      state = AsyncData(previous);
    }
    state = await AsyncValue.guard(() => _load(allowCache: false));
  }
}

final eventDetailProvider =
    AsyncNotifierProvider.family<EventDetailController, Event, String>(
      EventDetailController.new,
    );

class EventDetailController extends AsyncNotifier<Event> {
  EventDetailController(this.eventId);

  final String eventId;

  @override
  Future<Event> build() => _load(allowCache: true);

  Future<Event> _load({required bool allowCache}) async {
    final cache = ref.read(eventCacheProvider);
    try {
      return await ref.read(apiClientProvider).getEvent(eventId);
    } catch (error) {
      if (allowCache) {
        final cached = cache.find(eventId);
        if (cached != null) return cached;
      }
      rethrow;
    }
  }

  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) {
      state = const AsyncLoading();
    } else {
      state = AsyncData(previous);
    }
    state = await AsyncValue.guard(() => _load(allowCache: false));
  }
}
