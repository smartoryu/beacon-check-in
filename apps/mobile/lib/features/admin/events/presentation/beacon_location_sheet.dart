import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ble_central/flutter_ble_central.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../../../core/ble/beacon_scan_service.dart';
import '../../../../core/ble/ble_status_controller.dart';
import '../../../../core/ble/ibeacon_parser.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/providers.dart';

class ConfirmBeaconLocationSheet extends ConsumerStatefulWidget {
  const ConfirmBeaconLocationSheet({
    super.key,
    required this.eventId,
    required this.beacon,
  });

  final String eventId;
  final EventBeacon beacon;

  @override
  ConsumerState<ConfirmBeaconLocationSheet> createState() =>
      _ConfirmBeaconLocationSheetState();
}

class _ConfirmBeaconLocationSheetState
    extends ConsumerState<ConfirmBeaconLocationSheet> {
  late final BeaconScanService _scanService;
  StreamSubscription<ScanResult>? _scanSubscription;
  Position? _position;
  bool _scanning = false;
  bool _beaconSeen = false;
  bool _gpsLoading = true;
  bool _submitting = false;
  int? _rssi;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanService = BeaconScanService();
    unawaited(_startScan());
    unawaited(_loadGps());
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanService.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _beaconSeen = false;
      _rssi = null;
      _error = null;
    });
    try {
      await _scanService.init();
      _scanSubscription ??= _scanService.results.listen((result) {
        final packet = IBeaconParser.parseScanResult(result);
        if (packet?.identityKey != widget.beacon.identityKey) return;
        if (!mounted) return;
        setState(() {
          _beaconSeen = true;
          _scanning = false;
          _rssi = result.rssi;
        });
        unawaited(_scanService.stop());
      });
      final phase = await _scanService.start();
      if (!mounted) return;
      setState(() {
        _scanning = phase == BlePhase.scanning;
        if (phase != BlePhase.scanning) {
          _error = _scanService.status.value.message;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadGps() async {
    setState(() {
      _gpsLoading = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _error = 'Location services are off. Turn on GPS and try again.';
        });
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _gpsLoading = false;
          _error =
              'Location permission is required to confirm a beacon location.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _gpsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _gpsLoading = false;
        _error = 'Unable to read GPS: $error';
      });
    }
  }

  Future<void> _confirm() async {
    final position = _position;
    if (position == null || !_beaconSeen) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .confirmBeaconLocation(
            eventId: widget.eventId,
            beaconId: widget.beacon.beaconId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracyM: position.accuracy,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    final ready = _beaconSeen && position != null && !_submitting;
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
              widget.beacon.hasConfirmedLocation
                  ? 'Update beacon location'
                  : 'Confirm beacon location',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(widget.beacon.label),
            Text(
              widget.beacon.identityKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 16),
            _StatusRow(
              icon: _beaconSeen
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_searching,
              color: _beaconSeen ? Colors.green : Colors.orange,
              title: _beaconSeen
                  ? 'Beacon detected${_rssi == null ? '' : ' · $_rssi dBm'}'
                  : _scanning
                  ? 'Scanning for this beacon…'
                  : 'Beacon not detected',
              subtitle: _beaconSeen
                  ? 'Keep the phone near the beacon while confirming.'
                  : 'Move close to the beacon and keep the scanner open.',
            ),
            const SizedBox(height: 8),
            _StatusRow(
              icon: position == null
                  ? Icons.location_searching
                  : Icons.my_location,
              color: position == null ? Colors.orange : Colors.green,
              title: _gpsLoading
                  ? 'Getting GPS location…'
                  : position == null
                  ? 'GPS location unavailable'
                  : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              subtitle: position == null
                  ? 'Location permission and GPS services are required.'
                  : 'Accuracy ±${position.accuracy.toStringAsFixed(0)} m',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!_beaconSeen && !_scanning)
              OutlinedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan again'),
              ),
            if (position == null && !_gpsLoading)
              OutlinedButton.icon(
                onPressed: _loadGps,
                icon: const Icon(Icons.location_on),
                label: const Text('Retry GPS'),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: ready ? _confirm : null,
              icon: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pin_drop),
              label: Text(_submitting ? 'Saving…' : 'Confirm location'),
            ),
            const SizedBox(height: 8),
            Text(
              'Only confirm while standing near the selected beacon. GPS can be inaccurate indoors; the reported accuracy is stored for reference.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class BeaconLocationHistorySheet extends ConsumerStatefulWidget {
  const BeaconLocationHistorySheet({
    super.key,
    required this.eventId,
    required this.beacon,
  });

  final String eventId;
  final EventBeacon beacon;

  @override
  ConsumerState<BeaconLocationHistorySheet> createState() =>
      _BeaconLocationHistorySheetState();
}

class _BeaconLocationHistorySheetState
    extends ConsumerState<BeaconLocationHistorySheet> {
  late Future<List<EventBeaconLocationHistory>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<EventBeaconLocationHistory>> _load() => ref
      .read(apiClientProvider)
      .beaconLocationHistory(
        eventId: widget.eventId,
        beaconId: widget.beacon.beaconId,
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Location history',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('${widget.beacon.label} · ${widget.beacon.identityKey}'),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<EventBeaconLocationHistory>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load history: ${snapshot.error}'),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No location changes recorded yet.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.pin_drop_outlined),
                          title: Text(
                            '${item.latitude.toStringAsFixed(6)}, ${item.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                          subtitle: Text(
                            '${DateFormat('d MMM yyyy · HH:mm:ss').format(item.createdAt.toLocal())}'
                            '${item.accuracyM == null ? '' : ' · ±${item.accuracyM!.toStringAsFixed(0)} m'}'
                            '\n${item.recordedByName ?? 'Unknown admin'} · ${item.source}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
