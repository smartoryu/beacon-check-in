// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/ble/beacon_scan_service.dart';
import '../../../../core/ble/ble_status_controller.dart';
import '../../../../core/ble/gatt_reader.dart';
import '../../../../core/ble/ibeacon_parser.dart';
import '../../../../core/models/api_models.dart';
import '../../../../core/models/scan_models.dart';

class ScannerController extends ChangeNotifier {
  ScannerController({
    required ApiClient api,
    BeaconScanService? scanService,
    GattReader? gattReader,
  }) : _api = api,
       _scanService = scanService ?? BeaconScanService(),
       _gattReader = gattReader ?? GattReader();

  final ApiClient _api;
  final BeaconScanService _scanService;
  final GattReader _gattReader;

  final Map<String, DiscoveredBeacon> _discovered = {};
  final Map<String, BeaconLookupItem> _lookup = {};
  Timer? _lookupDebounce;
  StreamSubscription? _subscription;
  bool _registeredLookupRunning = false;

  BeaconScanService get scanService => _scanService;
  List<DiscoveredBeacon> get discovered {
    final items = _discovered.values.toList()
      ..sort((a, b) => b.medianRssi.compareTo(a.medianRssi));
    return items;
  }

  BeaconLookupItem? statusFor(String identityKey) => _lookup[identityKey];

  Future<void> start() async {
    await _scanService.init();
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
      _scheduleLookup();
      notifyListeners();
    });

    final phase = await _scanService.start();
    if (phase != BlePhase.scanning) {
      notifyListeners();
      return;
    }
    await _lookupNow();
    notifyListeners();
  }

  Future<void> stop() async {
    await _scanService.stop();
    notifyListeners();
  }

  Future<void> refreshLookup() => _lookupNow();

  void _scheduleLookup() {
    _lookupDebounce?.cancel();
    _lookupDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_lookupNow());
    });
  }

  Future<void> _lookupNow() async {
    if (_registeredLookupRunning || _discovered.isEmpty) return;
    _registeredLookupRunning = true;
    try {
      final items = await _api.lookupBeacons(_discovered.keys.toList());
      _lookup
        ..clear()
        ..addAll(items);
      notifyListeners();
    } catch (_) {
      // Keep the previous statuses on transient errors.
    } finally {
      _registeredLookupRunning = false;
    }
  }

  Future<Beacon> register({
    required DiscoveredBeacon discovered,
    required String label,
    required bool readGatt,
  }) async {
    Map<String, dynamic>? gattInfo;
    if (readGatt &&
        discovered.deviceId != null &&
        discovered.deviceId!.isNotEmpty) {
      gattInfo = await _gattReader.read(discovered.deviceId!);
    }
    final beacon = await _api.registerBeacon(
      proximityUuid: discovered.proximityUuid,
      major: discovered.major,
      minor: discovered.minor,
      label: label,
      localName: discovered.localName,
      platformDeviceId: discovered.deviceId,
      deviceAddressType: discovered.deviceAddressType,
      txPower: discovered.measuredPower,
      metadata: discovered.toMetadataJson(),
      gattInfo: gattInfo,
      rssiSamples: discovered.samples,
    );
    await _lookupNow();
    return beacon;
  }

  Future<void> requestRestore(String beaconId, String reason) async {
    await _api.requestRestore(beaconId, reason);
    await _lookupNow();
  }

  int? _nearestRssi() => _discovered.values
      .map((item) => item.medianRssi)
      .fold<int?>(
        null,
        (best, value) => best == null || value > best ? value : best,
      );

  void simulateUnregistered() {
    final now = DateTime.now().toUtc();
    final minor = 900 + (_discovered.length + 1);
    final packet = IBeaconPacket(
      proximityUuid: '00000000-0000-4000-8000-0000000000aa',
      major: 9,
      minor: minor,
      measuredPower: -59,
    );
    _discovered[packet.identityKey] = DiscoveredBeacon(
      packet: packet,
      rssi: -54,
      firstSeen: now,
      lastSeen: now,
      localName: 'Simulated Beacon $minor',
      deviceId: 'debug-$minor',
      deviceAddressType: 'debug',
      samples: [-54, -58, -56],
    );
    _scheduleLookup();
    notifyListeners();
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _subscription?.cancel();
    _scanService.dispose();
    super.dispose();
  }
}
