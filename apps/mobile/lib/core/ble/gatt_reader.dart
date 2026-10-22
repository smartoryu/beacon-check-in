import 'dart:async';
import 'dart:convert';

import 'package:flutter_ble_central/flutter_ble_central.dart';

class GattReader {
  GattReader({FlutterBleCentral? central}) : _central = central ?? FlutterBleCentral();

  final FlutterBleCentral _central;

  static const _names = <String, String>{
    '2a29': 'manufacturer_name',
    '2a24': 'model_number',
    '2a25': 'serial_number',
    '2a27': 'hardware_revision',
    '2a26': 'firmware_revision',
    '2a28': 'software_revision',
    '2a19': 'battery_level',
  };

  Future<Map<String, dynamic>?> read(String address) async {
    try {
      await _central
          .connect(address: address, timeout: 5)
          .timeout(const Duration(seconds: 6));
      final services = await _central
          .discoverServices(address)
          .timeout(const Duration(seconds: 6));
      final result = <String, dynamic>{};
      for (final service in services) {
        final serviceUuid = service.uuid.toLowerCase();
        if (!serviceUuid.contains('180a') && !serviceUuid.contains('180f')) {
          continue;
        }
        for (final characteristic in service.characteristics ?? const <GattCharacteristic>[]) {
          if (!characteristic.properties.read) continue;
          final key = _shortUuid(characteristic.uuid);
          final label = _names[key];
          if (label == null) continue;
          try {
            final value = await _central
                .readCharacteristic(
                  address: address,
                  serviceUuid: service.uuid,
                  characteristicUuid: characteristic.uuid,
                )
                .timeout(const Duration(seconds: 5));
            if (value.isEmpty) continue;
            if (label == 'battery_level') {
              result[label] = value.first;
            } else {
              result[label] = utf8.decode(value, allowMalformed: true).trim();
            }
          } catch (_) {
            // Characteristic is optional; continue with the rest.
          }
        }
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    } finally {
      try {
        await _central.disconnect(address);
      } catch (_) {}
    }
  }

  String _shortUuid(String uuid) {
    final lower = uuid.toLowerCase();
    if (lower.length >= 8) return lower.substring(4, 8);
    return lower;
  }
}
