import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/api_models.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../application/events_controller.dart';

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsControllerProvider);
    final worker = ref.watch(syncWorkerProvider);

    return MainScaffold(
      title: 'Events',
      selectedIndex: 0,
      actions: [
        IconButton(
          onPressed: () =>
              ref.read(eventsControllerProvider.notifier).refresh(),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => ref.read(eventsControllerProvider.notifier).refresh(),
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Unable to load events: $error'),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.event_busy, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No active events',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ask an admin to create an event and attach a beacon.',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }
            final now = DateTime.now().toUtc();
            final ongoing = items
                .where(
                  (event) =>
                      !event.isUpcoming && now.isBefore(event.endsAt.toUtc()),
                )
                .toList();
            final upcoming = items.where((event) => event.isUpcoming).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (worker.online.value == false)
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('Offline — showing cached events.'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (ongoing.isNotEmpty) ...[
                  const _SectionTitle('Ongoing'),
                  ...ongoing.map((event) => _EventCard(event: event)),
                ],
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle('Upcoming'),
                  ...upcoming.map((event) => _EventCard(event: event)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});
  final Event event;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEE, d MMM · HH:mm');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/events/${event.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      event.isOngoing ? 'Ongoing' : 'Upcoming',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(event.placeName),
              const SizedBox(height: 4),
              Text(
                '${formatter.format(event.startsAt.toLocal())} → ${formatter.format(event.endsAt.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${event.beacons.length} beacon(s) · ${event.checkinCount} check-in(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
