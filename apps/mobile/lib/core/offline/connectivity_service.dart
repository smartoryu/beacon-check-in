import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _online(results);
  }

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_online).distinct();

  bool _online(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
