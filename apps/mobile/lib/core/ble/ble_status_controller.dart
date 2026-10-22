import 'package:flutter/foundation.dart';

enum BlePhase {
  idle,
  ready,
  scanning,
  permissionDenied,
  permanentlyDenied,
  bluetoothOff,
  unsupported,
  error,
}

class BleStatus {
  const BleStatus({
    required this.phase,
    required this.message,
    this.lastAdvertisementAt,
    this.beaconCount = 0,
    this.nearestRssi,
    this.error,
  });

  final BlePhase phase;
  final String message;
  final DateTime? lastAdvertisementAt;
  final int beaconCount;
  final int? nearestRssi;
  final String? error;

  bool get isScanning => phase == BlePhase.scanning;
  bool get isReady => phase == BlePhase.ready || phase == BlePhase.idle;
  bool get needsSettings => phase == BlePhase.permanentlyDenied;
  bool get canEnableBluetooth => phase == BlePhase.bluetoothOff;

  BleStatus copyWith({
    BlePhase? phase,
    String? message,
    DateTime? lastAdvertisementAt,
    int? beaconCount,
    int? nearestRssi,
    String? error,
  }) =>
      BleStatus(
        phase: phase ?? this.phase,
        message: message ?? this.message,
        lastAdvertisementAt: lastAdvertisementAt ?? this.lastAdvertisementAt,
        beaconCount: beaconCount ?? this.beaconCount,
        nearestRssi: nearestRssi ?? this.nearestRssi,
        error: error ?? this.error,
      );
}

class BleStatusController extends ValueNotifier<BleStatus> {
  BleStatusController()
      : super(const BleStatus(
          phase: BlePhase.idle,
          message: 'Bluetooth ready',
        ));

  void setPhase(BlePhase phase, String message, {String? error}) {
    value = BleStatus(phase: phase, message: message, error: error);
  }

  void markScanning() {
    value = value.copyWith(
      phase: BlePhase.scanning,
      message: 'Scanning for iBeacons…',
    );
  }

  void markAdvertisement({required int beaconCount, int? nearestRssi}) {
    value = value.copyWith(
      phase: BlePhase.scanning,
      message: 'Scanning for iBeacons…',
      lastAdvertisementAt: DateTime.now().toUtc(),
      beaconCount: beaconCount,
      nearestRssi: nearestRssi,
    );
  }

  void markIdle() {
    value = value.copyWith(
      phase: BlePhase.ready,
      message: 'Bluetooth ready',
    );
  }
}
