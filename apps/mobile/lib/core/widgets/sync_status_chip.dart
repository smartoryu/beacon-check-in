import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../offline/offline_providers.dart';

class SyncStatusChip extends ConsumerWidget {
  const SyncStatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final queue = ref.watch(checkinQueueProvider);
    final worker = ref.watch(syncWorkerProvider);
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<void>(
      stream: queue.changes,
      builder: (context, _) {
        final pending = queue.pendingCountForUser(user.id);
        return ValueListenableBuilder<bool>(
          valueListenable: worker.syncing,
          builder: (context, syncing, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: worker.online,
              builder: (context, online, _) {
                final (icon, label, color) = syncing
                    ? (Icons.sync, 'Syncing…', Colors.blue)
                    : !online
                        ? (
                            Icons.cloud_off,
                            pending > 0 ? 'Offline — $pending queued' : 'Offline',
                            Colors.amber.shade800,
                          )
                        : pending > 0
                            ? (
                                Icons.cloud_queue,
                                '$pending queued',
                                Colors.orange.shade800,
                              )
                            : (Icons.cloud_done, 'Synced', Colors.green);
                return ActionChip(
                  avatar: Icon(icon, size: 16, color: color),
                  label: Text(
                    label,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                  onPressed: online ? worker.syncNow : null,
                  visualDensity: VisualDensity.compact,
                );
              },
            );
          },
        );
      },
    );
  }
}
