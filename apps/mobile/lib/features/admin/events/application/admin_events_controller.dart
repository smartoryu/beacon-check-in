import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/providers.dart';

final adminEventsProvider =
    AsyncNotifierProvider<AdminEventsController, List<Event>>(
      AdminEventsController.new,
    );

class AdminEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() => _load();

  Future<List<Event>> _load() =>
      ref.read(apiClientProvider).listEvents(status: 'all');

  Future<void> refresh() async {
    final previous = state.value;
    state = previous == null ? const AsyncLoading() : AsyncData(previous);
    state = await AsyncValue.guard(_load);
  }
}

final adminEventDetailProvider = FutureProvider.autoDispose.family<Event, String>(
  (ref, eventId) => ref.read(apiClientProvider).getEvent(eventId),
);
