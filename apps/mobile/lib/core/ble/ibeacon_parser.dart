import 'dart:typed_data';

import 'package:flutter_ble_central/flutter_ble_central.dart';

class IBeaconPacket {
  const IBeaconPacket({
    required this.proximityUuid,
    required this.major,
    required this.minor,
    required this.measuredPower,
  });

  final String proximityUuid;
  final int major;
  final int minor;
  final int measuredPower;

  String get identityKey => '$proximityUuid:$major:$minor';
}

class IBeaconParser {
  static const int appleCompanyId = 0x004C;
  static const int _expectedPayloadLength = 23;

  /// Parses the standard iBeacon payload.
  ///
  /// Accepts either the 23-byte iBeacon payload (company ID already stripped,
  /// starting with 02 15) or the full 25-byte manufacturer data including the
  /// Apple company ID (4C 00 02 15 ...).
  static IBeaconPacket? parse(List<int> data) {
    final bytes = Uint8List.fromList(data);
    var offset = 0;
    if (bytes.length == 25 &&
        bytes[0] == 0x4C &&
        bytes[1] == 0x00 &&
        bytes[2] == 0x02 &&
        bytes[3] == 0x15) {
      offset = 2;
    }
    if (bytes.length - offset != _expectedPayloadLength) return null;
    if (bytes[offset] != 0x02 || bytes[offset + 1] != 0x15) return null;

    final uuidBytes = bytes.sublist(offset + 2, offset + 18);
    final major = (bytes[offset + 18] << 8) | bytes[offset + 19];
    final minor = (bytes[offset + 20] << 8) | bytes[offset + 21];
    final powerByte = bytes[offset + 22];
    final measuredPower = powerByte > 127 ? powerByte - 256 : powerByte;

    return IBeaconPacket(
      proximityUuid: _formatUuid(uuidBytes),
      major: major,
      minor: minor,
      measuredPower: measuredPower,
    );
  }

  /// Extracts the iBeacon payload from a scan result.
  static IBeaconPacket? parseScanResult(ScanResult result) {
    final manufacturer = result.scanRecord?.manufacturerSpecificData;
    final appleData = manufacturer?[appleCompanyId];
    if (appleData != null) {
      final parsed = parse(appleData);
      if (parsed != null) return parsed;
    }

    // Fallback: walk the raw AD structures for a 0xFF Apple record.
    final raw = result.scanRecord?.bytes;
    if (raw != null) {
      final parsed = _parseRawAdStructures(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static IBeaconPacket? _parseRawAdStructures(Uint8List bytes) {
    var index = 0;
    while (index < bytes.length) {
      final length = bytes[index];
      if (length == 0 || index + 1 + length > bytes.length) break;
      final type = bytes[index + 1];
      final payload = bytes.sublist(index + 2, index + 1 + length);
      if (type == 0xFF &&
          payload.length >= 4 &&
          payload[0] == 0x4C &&
          payload[1] == 0x00) {
        final parsed = parse(payload);
        if (parsed != null) return parsed;
      }
      index += 1 + length;
    }
    return null;
  }

  static String _formatUuid(Uint8List bytes) {
    final hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
