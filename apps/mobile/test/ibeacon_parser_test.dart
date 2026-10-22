import 'dart:typed_data';

import 'package:beacon_check_in/core/ble/ibeacon_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List packet({
  String uuid = 'f7826da64fa24e988024bc5b71e0893e',
  int major = 1,
  int minor = 2,
  int power = 0xC5, // -59
}) {
  final uuidBytes = <int>[];
  for (var i = 0; i < uuid.length; i += 2) {
    uuidBytes.add(int.parse(uuid.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList([
    0x02,
    0x15,
    ...uuidBytes,
    (major >> 8) & 0xFF,
    major & 0xFF,
    (minor >> 8) & 0xFF,
    minor & 0xFF,
    power,
  ]);
}

void main() {
  group('IBeaconParser', () {
    test('parses the standard 23-byte iBeacon payload', () {
      final result = IBeaconParser.parse(packet());
      expect(result, isNotNull);
      expect(result!.proximityUuid, 'f7826da6-4fa2-4e98-8024-bc5b71e0893e');
      expect(result.major, 1);
      expect(result.minor, 2);
      expect(result.measuredPower, -59);
      expect(result.identityKey, 'f7826da6-4fa2-4e98-8024-bc5b71e0893e:1:2');
    });

    test('parses full manufacturer data including the Apple company ID', () {
      final full = Uint8List.fromList([0x4C, 0x00, ...packet()]);
      final result = IBeaconParser.parse(full);
      expect(result, isNotNull);
      expect(result!.major, 1);
      expect(result.minor, 2);
    });

    test('rejects malformed and non-iBeacon payloads', () {
      expect(IBeaconParser.parse([0x02, 0x15, 1, 2, 3]), isNull);
      expect(IBeaconParser.parse(Uint8List.fromList(List.filled(23, 0))), isNull);
      expect(
        IBeaconParser.parse(Uint8List.fromList([0x4C, 0x00, 0x03, 0x15, ...List.filled(19, 0)])),
        isNull,
      );
    });

    test('handles signed measured power', () {
      final result = IBeaconParser.parse(packet(power: 0x3C));
      expect(result!.measuredPower, 60);
    });
  });
}
