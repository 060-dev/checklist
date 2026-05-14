import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart' as cp;
import 'package:flutter/foundation.dart';

/// Conectividade para Android usando connectivity_plus.
class Connectivity {
  static final Connectivity _instance = Connectivity._internal();
  factory Connectivity() => _instance;
  Connectivity._internal();

  static Connectivity get instance => _instance;

  final cp.Connectivity _connectivity = cp.Connectivity();
  bool _isOnline = true;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<cp.ConnectivityResult> results) {
    // No Android, se qualquer interface estiver conectada (wifi, mobile, ethernet), consideramos online.
    final hasConnection = results.any((result) => result != cp.ConnectivityResult.none);
    if (_isOnline != hasConnection) {
      _isOnline = hasConnection;
      _controller.add(_isOnline);
      debugPrint('Connectivity changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  bool get isOnline => _isOnline;

  Stream<bool> get onOnlineChanged => _controller.stream;
}
