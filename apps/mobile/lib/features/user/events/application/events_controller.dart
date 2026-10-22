import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/providers.dart';

final eventsControllerProvider =
    AsyncNotifierProvider<EventsController, List<Event>>(EventsController.new);

class EventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final cache = ref.read(eventCacheProvider);
    final cached = cache.readActive().events;
    try {
      final events = await ref.read(apiClientProvider).activeEvents();
      await cache.saveActive(events);
      return events;
    } catch (error) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final eventDetailProvider = FutureProvider.family<Event, String>((ref, id) async {
  final cache = ref.read(eventCacheProvider);
  try {
    final event = await ref.read(apiClientProvider).getEvent(id);
    return event;
  } catch (error) {
    final cached = cache.find(id);
    if (cached != null) return cached;
    rethrow;
  }
});
