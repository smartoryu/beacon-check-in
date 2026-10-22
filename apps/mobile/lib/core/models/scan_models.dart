import 'package:flutter_ble_central/flutter_ble_central.dart';

import '../ble/ibeacon_parser.dart';

class DiscoveredBeacon {
  DiscoveredBeacon({
    required this.packet,
    required this.rssi,
    required this.firstSeen,
    required this.lastSeen,
    this.localName,
    this.deviceId,
    this.deviceAddressType,
    this.txPower,
    this.rawManufacturerData,
    this.rawBytes,
    this.serviceData,
    this.serviceUuids,
    this.connectable,
    this.samples = const [],
  });

  final IBeaconPacket packet;
  final int rssi;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final String? localName;
  final String? deviceId;
  final String? deviceAddressType;
  final int? txPower;
  final List<int>? rawManufacturerData;
  final List<int>? rawBytes;
  final Map<String, List<int>>? serviceData;
  final List<String>? serviceUuids;
  final bool? connectable;
  final List<int> samples;

  String get identityKey => packet.identityKey;
  int get major => packet.major;
  int get minor => packet.minor;
  String get proximityUuid => packet.proximityUuid;
  int get measuredPower => packet.measuredPower;

  int get medianRssi {
    if (samples.isEmpty) return rssi;
    final sorted = [...samples]..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  DiscoveredBeacon merge(ScanResult result) {
    final now = DateTime.now().toUtc();
    final samples = [...this.samples, if (result.rssi != null) result.rssi!];
    if (samples.length > 20) samples.removeRange(0, samples.length - 20);
    return DiscoveredBeacon(
      packet: packet,
      rssi: result.rssi ?? rssi,
      firstSeen: firstSeen,
      lastSeen: now,
      localName: result.scanRecord?.deviceName ?? result.device?.name ?? localName,
      deviceId: result.device?.address ?? deviceId,
      deviceAddressType: deviceAddressType,
      txPower: result.txPower ?? txPower,
      rawManufacturerData:
          result.scanRecord?.manufacturerSpecificData?[IBeaconParser.appleCompanyId] ??
              rawManufacturerData,
      rawBytes: result.scanRecord?.bytes ?? rawBytes,
      serviceData: _serviceData(result),
      serviceUuids: result.scanRecord?.serviceUuids?.whereType<String>().toList() ??
          serviceUuids,
      connectable: result.connectable ?? connectable,
      samples: samples,
    );
  }

  Map<String, dynamic> toMetadataJson() => {
        'raw_advertisement_hex': rawManufacturerData
            ?.map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join(),
        'raw_scan_record_hex': rawBytes
            ?.map((value) => value.toRadixString(16).padLeft(2, '0'))
            .join(),
        'manufacturer_data': rawManufacturerData,
        'service_data': serviceData,
        'service_uuids': serviceUuids,
        'connectable': connectable,
        'generic_tx_power': txPower,
        'iBeacon_measured_power': measuredPower,
        'rssi_samples': samples,
        'rssi_median': medianRssi,
        'best_rssi': samples.isEmpty
            ? rssi
            : samples.reduce((value, element) => value > element ? value : element),
      };

  static Map<String, List<int>>? _serviceData(ScanResult result) {
    final data = result.scanRecord?.serviceData;
    if (data == null) return null;
    return data.map((key, value) => MapEntry(key, value.toList()));
  }
}
