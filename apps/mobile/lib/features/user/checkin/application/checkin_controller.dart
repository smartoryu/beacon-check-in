// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/ble/beacon_scan_service.dart';
import '../../../../core/ble/ble_status_controller.dart';
import '../../../../core/ble/ibeacon_parser.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/models/scan_models.dart';
import '../../../../core/offline/checkin_queue.dart';
import '../../../../core/offline/sync_worker.dart';

class CheckinScanState {
  const CheckinScanState({
    this.scanning = false,
    this.recording = false,
    this.secondsLeft = 8,
    this.discovered = const [],
    this.error,
    this.recorded,
  });

  final bool scanning;
  final bool recording;
  final int secondsLeft;
  final List<DiscoveredBeacon> discovered;
  final String? error;
  final QueuedCheckin? recorded;

  CheckinScanState copyWith({
    bool? scanning,
    bool? recording,
    int? secondsLeft,
    List<DiscoveredBeacon>? discovered,
    String? error,
    QueuedCheckin? recorded,
    bool clearError = false,
  }) => CheckinScanState(
    scanning: scanning ?? this.scanning,
    recording: recording ?? this.recording,
    secondsLeft: secondsLeft ?? this.secondsLeft,
    discovered: discovered ?? this.discovered,
    error: clearError ? null : (error ?? this.error),
    recorded: recorded ?? this.recorded,
  );
}

class CheckinController extends ChangeNotifier {
  CheckinController({
    required this.event,
    required this.userId,
    required ApiClient api,
    required CheckinQueue queue,
    required SyncWorker syncWorker,
    BeaconScanService? scanService,
  }) : _api = api,
       _queue = queue,
       _syncWorker = syncWorker,
       _scanService = scanService ?? BeaconScanService();

  final Event event;
  final String userId;
  final ApiClient _api;
  final CheckinQueue _queue;
  final SyncWorker _syncWorker;
  final BeaconScanService _scanService;

  final Map<String, DiscoveredBeacon> _discovered = {};
  final Map<String, DiscoveredBeacon> _simulated = {};
  StreamSubscription? _subscription;
  Timer? _countdown;
  int _seconds = 8;

  CheckinScanState _state = const CheckinScanState();
  CheckinScanState get state => _state;

  BeaconScanService get scanService => _scanService;

  Future<void> start() async {
    await _scanService.init();
    await _scanService.stop();
    _discovered.clear();
    _simulated.clear();
    _seconds = 8;
    _state = const CheckinScanState(scanning: true);
    notifyListeners();

    _subscription ??= _scanService.results.listen((result) {
      final packet = IBeaconParser.parseScanResult(result);
      if (packet == null) {
        _scanService.status.markAdvertisement(
          advertisementCount: _scanService.advertisementCount,
          beaconCount: _discovered.length,
          nearestRssi: _nearestRssi(),
        );
        return;
      }
      if (!event.beacons.any(
        (beacon) => beacon.identityKey == packet.identityKey,
      )) {
        _scanService.status.markAdvertisement(
          advertisementCount: _scanService.advertisementCount,
          beaconCount: _discovered.length,
          nearestRssi: _nearestRssi(),
        );
        return;
      }
      final now = DateTime.now().toUtc();
      final existing = _discovered[packet.identityKey];
      final beacon = existing == null
          ? DiscoveredBeacon(
              packet: packet,
              rssi: result.rssi ?? 0,
              firstSeen: now,
              lastSeen: now,
              localName: result.scanRecord?.deviceName,
              deviceId: result.device?.address,
              deviceAddressType: result.device?.type?.toString(),
              txPower: result.txPower,
              rawManufacturerData: result
                  .scanRecord
                  ?.manufacturerSpecificData?[IBeaconParser.appleCompanyId],
              rawBytes: result.scanRecord?.bytes,
              serviceUuids: result.scanRecord?.serviceUuids
                  ?.whereType<String>()
                  .toList(),
              connectable: result.connectable,
              samples: result.rssi == null ? const [] : [result.rssi!],
            )
          : existing.merge(result);
      _discovered[packet.identityKey] = beacon;
      _scanService.status.markAdvertisement(
        advertisementCount: _scanService.advertisementCount,
        beaconCount: _discovered.length,
        nearestRssi: _nearestRssi(),
      );
      _publish();
    });

    final phase = await _scanService.start();
    if (phase != BlePhase.scanning) {
      _state = _state.copyWith(
        scanning: false,
        error: _scanService.status.value.message,
      );
      notifyListeners();
      return;
    }

    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      _seconds--;
      if (_seconds <= 0) {
        timer.cancel();
        unawaited(_finishScan());
      } else {
        _state = _state.copyWith(secondsLeft: _seconds);
        notifyListeners();
      }
    });
  }

  Future<void> _finishScan() async {
    await _scanService.stop();
    _state = _state.copyWith(scanning: false, secondsLeft: 0);
    _publish();
    if (_state.discovered.isNotEmpty) {
      // One-action flow: the user starts the check-in once, and the app records
      // the result automatically after the scan window closes.
      try {
        await record();
      } catch (error) {
        _state = _state.copyWith(recording: false, error: error.toString());
        notifyListeners();
      }
    }
  }

  Future<void> retry() => start();

  void simulate() {
    final now = DateTime.now().toUtc();
    for (var index = 0; index < event.beacons.length; index++) {
      final beacon = event.beacons[index];
      final rssi = [-52, -58, -65][index % 3];
      _simulated[beacon.identityKey] = DiscoveredBeacon(
        packet: IBeaconPacket(
          proximityUuid: beacon.identityKey.split(':').first,
          major: int.tryParse(beacon.identityKey.split(':')[1]) ?? 1,
          minor: int.tryParse(beacon.identityKey.split(':')[2]) ?? 1,
          measuredPower: beacon.effectiveTxPower ?? -59,
        ),
        rssi: rssi,
        firstSeen: now,
        lastSeen: now,
        localName: 'Simulated ${beacon.label}',
        samples: [rssi, rssi - 2, rssi + 1],
      );
    }
    _publish();
    if (_simulated.isNotEmpty) {
      unawaited(record());
    }
  }

  void _publish() {
    final all = {..._discovered, ..._simulated}.values.toList()
      ..sort((a, b) => b.medianRssi.compareTo(a.medianRssi));
    _state = _state.copyWith(discovered: all);
    notifyListeners();
  }

  int? _nearestRssi() => _discovered.values
      .map((item) => item.medianRssi)
      .fold<int?>(
        null,
        (best, value) => best == null || value > best ? value : best,
      );

  Future<QueuedCheckin> record() async {
    _state = _state.copyWith(recording: true, clearError: true);
    notifyListeners();
    try {
      return await _record();
    } catch (error) {
      _state = _state.copyWith(recording: false, error: error.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<QueuedCheckin> _record() async {
    final all = {..._discovered, ..._simulated};
    final readings = <CheckinReadingInput>[];
    for (final beacon in event.beacons) {
      final discovered = all[beacon.identityKey];
      if (discovered == null) continue;
      final samples = discovered.samples.isEmpty
          ? [discovered.medianRssi]
          : discovered.samples;
      readings.add(
        CheckinReadingInput(
          identityKey: beacon.identityKey,
          rssiSamples: samples,
          txPower: discovered.measuredPower,
          platformDeviceId: discovered.deviceId,
        ),
      );
    }
    if (readings.isEmpty) {
      throw StateError('No event beacons found. Move closer and scan again.');
    }

    final now = DateTime.now().toUtc();
    final item = QueuedCheckin(
      clientCheckinId: _api.newClientCheckinId(),
      eventId: event.id,
      eventTitle: event.title,
      userId: userId,
      recordedAt: now,
      readings: readings,
      deviceInfo: {
        'platform': Platform.operatingSystem,
        'os_version': Platform.operatingSystemVersion,
        'app': 'beacon-check-in-mobile',
        'simulated': _simulated.isNotEmpty,
      },
      status: 'pending',
      createdAt: now,
      updatedAt: now,
    );
    await _queue.enqueue(item);
    _state = _state.copyWith(recorded: item, recording: false);
    notifyListeners();
    unawaited(_syncWorker.syncNow());
    return item;
  }

  Future<void> openSettingsHint() async {
    // Permission changes are handled by the OS settings screen; the banner
    // tells the user where to go. This hook exists for the UI action.
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _subscription?.cancel();
    _scanService.dispose();
    super.dispose();
  }
}
