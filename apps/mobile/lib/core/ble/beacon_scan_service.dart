import 'dart:async';

import 'package:flutter_ble_central/flutter_ble_central.dart';

import 'ble_status_controller.dart';

class BeaconScanService {
  BeaconScanService({
    FlutterBleCentral? central,
    BleStatusController? status,
  })  : _central = central ?? FlutterBleCentral(),
        status = status ?? BleStatusController();

  final FlutterBleCentral _central;
  final BleStatusController status;
  final StreamController<ScanResult> _results =
      StreamController<ScanResult>.broadcast();

  StreamSubscription<ScanResult>? _scanSubscription;
  StreamSubscription<CentralState>? _stateSubscription;
  bool _scanning = false;

  Stream<ScanResult> get results => _results.stream;
  bool get isScanning => _scanning;

  Future<void> init() async {
    _stateSubscription ??= _central.onCentralStateChanged.listen((state) {
      switch (state) {
        case CentralState.poweredOff:
          _scanning = false;
          status.setPhase(BlePhase.bluetoothOff, 'Bluetooth is turned off');
          break;
        case CentralState.unauthorized:
          _scanning = false;
          status.setPhase(BlePhase.permissionDenied, 'Bluetooth permission denied');
          break;
        case CentralState.unsupported:
          _scanning = false;
          status.setPhase(BlePhase.unsupported, 'Bluetooth is not supported');
          break;
        case CentralState.idle:
          if (!_scanning) status.markIdle();
          break;
        case CentralState.unknown:
          if (!_scanning) status.setPhase(BlePhase.error, 'Bluetooth state unknown');
          break;
        default:
          break;
      }
    });
  }

  Future<BlePhase> ensureReady() async {
    try {
      if (!await _central.isSupported) {
        status.setPhase(BlePhase.unsupported, 'Bluetooth is not supported');
        return BlePhase.unsupported;
      }
      var permission = await _central.hasPermission();
      if (permission != CentralBluetoothState.granted &&
          permission != CentralBluetoothState.ready) {
        permission = await _central.requestPermission();
      }
      switch (permission) {
        case CentralBluetoothState.granted:
        case CentralBluetoothState.ready:
          status.markIdle();
          return BlePhase.ready;
        case CentralBluetoothState.turnedOff:
          status.setPhase(BlePhase.bluetoothOff, 'Bluetooth is turned off');
          return BlePhase.bluetoothOff;
        case CentralBluetoothState.permanentlyDenied:
          status.setPhase(
            BlePhase.permanentlyDenied,
            'Bluetooth permission permanently denied — open app settings',
          );
          return BlePhase.permanentlyDenied;
        case CentralBluetoothState.denied:
        case CentralBluetoothState.restricted:
        case CentralBluetoothState.limited:
          status.setPhase(BlePhase.permissionDenied, 'Bluetooth permission denied');
          return BlePhase.permissionDenied;
        case CentralBluetoothState.unsupported:
          status.setPhase(BlePhase.unsupported, 'Bluetooth is not supported');
          return BlePhase.unsupported;
        default:
          status.setPhase(BlePhase.error, 'Bluetooth setup failed');
          return BlePhase.error;
      }
    } catch (error) {
      status.setPhase(BlePhase.error, 'Bluetooth setup failed', error: error.toString());
      return BlePhase.error;
    }
  }

  Future<bool> enableBluetooth() async {
    try {
      final enabled = await _central.enableBluetooth();
      if (enabled) status.markIdle();
      return enabled;
    } catch (_) {
      return false;
    }
  }

  Future<BlePhase> start() async {
    final readiness = await ensureReady();
    if (readiness != BlePhase.ready) return readiness;

    try {
      _scanSubscription ??= _central.onScanResult.listen(
        (result) => _results.add(result),
        onError: (Object error) {
          status.setPhase(BlePhase.error, 'Scan error', error: error.toString());
        },
      );
      final state = await _central.start(
        scanSettings: ScanSettings(
          useLightweightScanResult: false,
          legacyMode: false,
          scanMode: ScanMode.scanModeLowLatency,
          callbackType: CallbackType.allMatches,
          matchMode: MatchMode.aggressive,
          reportDelay: 0,
        ),
      );
      _scanning = state == CentralBluetoothState.granted ||
          state == CentralBluetoothState.ready;
      if (_scanning) {
        status.markScanning();
        return BlePhase.scanning;
      }
      return await ensureReady();
    } catch (error) {
      _scanning = false;
      status.setPhase(BlePhase.error, 'Unable to start scan', error: error.toString());
      return BlePhase.error;
    }
  }

  Future<void> stop() async {
    try {
      await _central.stop();
    } catch (_) {
      // Ignore stop failures.
    }
    _scanning = false;
    status.markIdle();
  }

  Future<void> dispose() async {
    await stop();
    await _scanSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _results.close();
    status.dispose();
  }
}
