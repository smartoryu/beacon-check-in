import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_controller.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/offline/checkin_queue.dart';
import '../../../../core/offline/event_cache.dart';
import '../../../../core/offline/offline_providers.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/sync_status_chip.dart';

final serverHistoryProvider =
    FutureProvider.autoDispose<List<Checkin>>((ref) async {
  return ref.read(apiClientProvider).myCheckins();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final server = ref.watch(serverHistoryProvider);
    final queue = ref.watch(checkinQueueProvider);
    final cache = ref.watch(eventCacheProvider);
    final worker = ref.watch(syncWorkerProvider);

    if (user == null) {
      return const MainScaffold(
        title: 'History',
        selectedIndex: 1,
        body: Center(child: Text('Sign in to see your check-ins.')),
      );
    }

    return MainScaffold(
      title: 'History',
      selectedIndex: 1,
      actions: [
        IconButton(
          onPressed: () => worker.syncNow(),
          icon: const Icon(Icons.sync),
          tooltip: 'Sync now',
        ),
      ],
      body: StreamBuilder<void>(
        stream: queue.changes,
        builder: (context, _) {
          final local = queue.forUser(user.id);
          return server.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 40),
                const SyncStatusChip(),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Server history unavailable (offline?). Showing local records.\n\n$error',
                    ),
                  ),
                ),
                ...local.map((item) => _LocalCard(item: item, cache: cache)),
              ],
            ),
            data: (remote) {
              final byClientId = {
                for (final item in remote) item.clientCheckinId: item,
              };
              final seen = <String>{};
              final cards = <Widget>[];
              for (final item in local) {
                seen.add(item.clientCheckinId);
                cards.add(
                  _LocalCard(
                    item: item,
                    cache: cache,
                    server: byClientId[item.clientCheckinId],
                  ),
                );
              }
              for (final item in remote) {
                if (!seen.contains(item.clientCheckinId)) {
                  cards.add(
                    _RemoteCard(
                      item: item,
                      eventTitle: cache.find(item.eventId)?.title ?? item.eventId,
                    ),
                  );
                }
              }
              if (cards.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    SizedBox(height: 120),
                    Icon(Icons.history, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No check-ins yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Open an ongoing event and record your first check-in.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: cards,
              );
            },
          );
        },
      ),
    );
  }
}

class _LocalCard extends StatelessWidget {
  const _LocalCard({required this.item, required this.cache, this.server});

  final QueuedCheckin item;
  final EventCache cache;
  final Checkin? server;

  @override
  Widget build(BuildContext context) {
    final title = item.eventTitle.isNotEmpty
        ? item.eventTitle
        : cache.find(item.eventId)?.title ?? item.eventId;
    final status = server?.status ?? item.status;
    final reason = server?.rejectReason ?? item.reason ?? item.lastError;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Recorded ${DateFormat('d MMM yyyy · HH:mm').format(item.recordedAt.toLocal())}',
            ),
            Text('${item.readings.length} beacon reading(s)'),
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                reason,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (item.status == 'pending' && item.nextAttemptAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Next sync attempt after ${DateFormat('HH:mm:ss').format(item.nextAttemptAt!.toLocal())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RemoteCard extends StatelessWidget {
  const _RemoteCard({required this.item, required this.eventTitle});
  final Checkin item;
  final String eventTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(eventTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Recorded ${DateFormat('d MMM yyyy · HH:mm').format(item.recordedAt.toLocal())}\n'
          '${item.usedBeaconCount} beacon(s)',
        ),
        isThreeLine: true,
        trailing: _StatusChip(status: item.status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'accepted' || 'synced' => ('Synced', Colors.green),
      'pending' => ('Queued', Colors.orange),
      'syncing' => ('Syncing', Colors.blue),
      'rejected' => ('Rejected', Colors.red),
      'failed' => ('Failed', Colors.red),
      _ => (status, Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      color: WidgetStatePropertyAll(color.withValues(alpha: 0.15)),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
