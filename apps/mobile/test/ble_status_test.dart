import 'package:beacon_check_in/core/ble/ble_status_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BLE status transitions update the banner telemetry', () {
    final controller = BleStatusController();
    expect(controller.value.phase, BlePhase.idle);

    controller.markScanning();
    expect(controller.value.phase, BlePhase.scanning);
    expect(controller.value.isScanning, isTrue);

    controller.markAdvertisement(
      advertisementCount: 5,
      beaconCount: 2,
      nearestRssi: -55,
    );
    expect(controller.value.advertisementCount, 5);
    expect(controller.value.beaconCount, 2);
    expect(controller.value.nearestRssi, -55);
    expect(controller.value.lastAdvertisementAt, isNotNull);

    controller.setPhase(BlePhase.bluetoothOff, 'Bluetooth is turned off');
    expect(controller.value.canEnableBluetooth, isTrue);
    expect(controller.value.isScanning, isFalse);

    controller.setPhase(BlePhase.permanentlyDenied, 'Permission denied');
    expect(controller.value.needsSettings, isTrue);

    controller.dispose();
  });
}
