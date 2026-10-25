import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/models/scan_models.dart';
import '../../../../core/providers.dart';
import '../../../../core/widgets/ble_status_banner.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../application/scanner_controller.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  late final ScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScannerController(api: ref.read(apiClientProvider))
      ..addListener(_refresh);
    _controller.start();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openRegister(DiscoveredBeacon beacon) async {
    final labelController = TextEditingController(
      text: beacon.localName ?? 'Beacon ${beacon.major}:${beacon.minor}',
    );
    var label = labelController.text;
    var readGatt = false;
    var submitting = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            if (label.trim().isEmpty) {
              setSheetState(() => error = 'Label is required.');
              return;
            }
            setSheetState(() {
              submitting = true;
              error = null;
            });
            try {
              final registered = await _controller.register(
                discovered: beacon,
                label: label.trim(),
                readGatt: readGatt,
              );
              if (context.mounted) Navigator.of(context).pop();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text('Registered ${registered.label}')),
                );
              }
            } on ApiException catch (exception) {
              setSheetState(() {
                submitting = false;
                error = exception.message;
              });
            } catch (exception) {
              setSheetState(() {
                submitting = false;
                error = exception.toString();
              });
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Register beacon',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    beacon.identityKey,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 12),
                  if (error != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(error!),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      border: OutlineInputBorder(),
                    ),
                    controller: labelController,
                    onChanged: (value) => label = value,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Read GATT details'),
                    subtitle: Text(
                      beacon.deviceId == null
                          ? 'Device address unavailable on this platform.'
                          : 'Battery, firmware, model and manufacturer (optional).',
                    ),
                    value: readGatt,
                    onChanged: beacon.deviceId == null
                        ? null
                        : (value) => setSheetState(() => readGatt = value),
                  ),
                  ExpansionTile(
                    title: const Text('Captured advertisement'),
                    childrenPadding: const EdgeInsets.only(bottom: 8),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          const JsonEncoder.withIndent('  ')
                              .convert(beacon.toMetadataJson()),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: submitting ? null : submit,
                    child: submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Register beacon'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    labelController.dispose();
  }

  Future<void> _requestRestore(Beacon beacon) async {
    final reasonController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Request restore: ${beacon.label}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    if (submitted != true) return;
    try {
      await _controller.requestRestore(beacon.id, reasonController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restore request submitted for approval.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final beacons = _controller.discovered;
    return MainScaffold(
      title: 'Beacon Scanner',
      selectedIndex: 0,
      actions: [
        IconButton(
          onPressed: _controller.refreshLookup,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh registration status',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BleStatusBanner(
            status: _controller.scanService.status,
            onEnableBluetooth: () => _controller.scanService.enableBluetooth(),
            onRetry: _controller.start,
            onStartScan: _controller.start,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${beacons.length} iBeacon(s) in range',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _controller.scanService.isScanning
                    ? _controller.stop
                    : _controller.start,
                icon: Icon(
                  _controller.scanService.isScanning
                      ? Icons.stop
                      : Icons.play_arrow,
                ),
                label: Text(
                  _controller.scanService.isScanning ? 'Stop' : 'Scan',
                ),
              ),
            ],
          ),
          if (AppConfig.enableDebugScanner)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: _controller.simulateUnregistered,
                icon: const Icon(Icons.science_outlined),
                label: const Text('Add simulated beacon (debug)'),
              ),
            ),
          if (beacons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.bluetooth_searching, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No iBeacons found yet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Move closer to a beacon and keep the scanner open.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ...beacons.map((beacon) {
            final lookup = _controller.statusFor(beacon.identityKey);
            final status = lookup?.status ?? 'unknown';
            final registered = lookup?.beacon;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            registered?.label ??
                                beacon.localName ??
                                beacon.identityKey,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (beacon.localName != null &&
                        beacon.localName != registered?.label) ...[
                      Text(
                        'Local name: ${beacon.localName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    Text(
                      '${beacon.identityKey}\nRSSI ${beacon.medianRssi} dBm · best ${beacon.samples.isEmpty ? beacon.rssi : beacon.samples.reduce((a, b) => a > b ? a : b)} dBm · ${beacon.samples.length} sample(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'unknown')
                          FilledButton(
                            onPressed: () => _openRegister(beacon),
                            child: const Text('Register'),
                          ),
                        if (status == 'registered')
                          const Chip(label: Text('Already registered')),
                        if (status == 'deleted' && registered != null)
                          FilledButton.tonal(
                            onPressed: () => _requestRestore(registered),
                            child: const Text('Request restore'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'registered' => ('Registered', Colors.green),
      'deleted' => ('Deleted', Colors.red),
      _ => ('New', Colors.blue),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      color: WidgetStatePropertyAll(color.withValues(alpha: 0.15)),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      visualDensity: VisualDensity.compact,
    );
  }
}
