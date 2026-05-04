import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> onlineStream() {
    return _connectivity.onConnectivityChanged.map(_toOnline);
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return _toOnline(result);
  }

  bool _toOnline(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((item) => item != ConnectivityResult.none);
    }
    return false;
  }
}
