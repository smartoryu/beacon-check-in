import 'dart:io';

class AppConfig {
  static const String _defineBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const bool debugScannerEnabled = bool.fromEnvironment(
    'ENABLE_DEBUG_SCANNER',
    defaultValue: false,
  );

  static String get apiBaseUrl {
    if (_defineBaseUrl.isNotEmpty) return _defineBaseUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:8080/api/v1';
    return 'http://localhost:8080/api/v1';
  }

  static bool get enableDebugScanner =>
      debugScannerEnabled || const bool.fromEnvironment('dart.vm.product') == false;
}
