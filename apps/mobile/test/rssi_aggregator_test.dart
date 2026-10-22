import 'package:beacon_check_in/core/ble/ibeacon_parser.dart';
import 'package:beacon_check_in/core/models/scan_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RSSI aggregation', () {
    test('uses the median of the sample window', () {
      final beacon = DiscoveredBeacon(
        packet: const IBeaconPacket(
          proximityUuid: 'uuid',
          major: 1,
          minor: 1,
          measuredPower: -59,
        ),
        rssi: -60,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        samples: const [-80, -60, -70],
      );
      expect(beacon.medianRssi, -70);
    });

    test('falls back to the last RSSI when no samples exist', () {
      final beacon = DiscoveredBeacon(
        packet: const IBeaconPacket(
          proximityUuid: 'uuid',
          major: 1,
          minor: 1,
          measuredPower: -59,
        ),
        rssi: -61,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
      );
      expect(beacon.medianRssi, -61);
    });
  });
}
