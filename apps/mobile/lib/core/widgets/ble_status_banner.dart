import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ble/ble_status_controller.dart';

class BleStatusBanner extends StatelessWidget {
  const BleStatusBanner({
    super.key,
    required this.status,
    this.onEnableBluetooth,
    this.onRetry,
    this.onStartScan,
  });

  final ValueListenable<BleStatus> status;
  final VoidCallback? onEnableBluetooth;
  final VoidCallback? onRetry;
  final VoidCallback? onStartScan;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BleStatus>(
      valueListenable: status,
      builder: (context, value, _) {
        final (color, icon) = switch (value.phase) {
          BlePhase.scanning => (Colors.blue, Icons.bluetooth_searching),
          BlePhase.ready || BlePhase.idle => (Colors.green, Icons.bluetooth),
          BlePhase.bluetoothOff => (
            Colors.amber.shade800,
            Icons.bluetooth_disabled,
          ),
          BlePhase.locationDisabled => (
            Colors.amber.shade800,
            Icons.location_off,
          ),
          BlePhase.permissionDenied ||
          BlePhase.permanentlyDenied => (Colors.red, Icons.lock_outline),
          BlePhase.unsupported => (Colors.red, Icons.bluetooth_disabled),
          BlePhase.error => (Colors.red, Icons.error_outline),
        };

        final telemetry = value.lastAdvertisementAt == null
            ? null
            : '${value.advertisementCount} advertisement(s) · '
                  '${value.beaconCount} iBeacon(s) · '
                  'nearest ${value.nearestRssi ?? '—'} dBm';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.message,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (telemetry != null)
                      Text(
                        telemetry,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (value.error != null)
                      Text(
                        value.error!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              if (value.canEnableBluetooth && onEnableBluetooth != null)
                TextButton(
                  onPressed: onEnableBluetooth,
                  child: const Text('Enable'),
                ),
              if (value.phase == BlePhase.error && onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              if (value.isReady && onStartScan != null)
                TextButton(onPressed: onStartScan, child: const Text('Scan')),
            ],
          ),
        );
      },
    );
  }
}
