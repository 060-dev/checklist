import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart' as plugin;

/// Thin wrapper around `connectivity_plus` exposing a single online/offline
/// signal the offline queue can react to.
class Connectivity {
  static final Connectivity instance = Connectivity._();
  Connectivity._();

  final plugin.Connectivity _plugin = plugin.Connectivity();
  StreamSubscription<List<plugin.ConnectivityResult>>? _sub;
  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();

  bool _isOnline = false;

  Future<void> init() async {
    try {
      _isOnline = _isOnlineResult(await _plugin.checkConnectivity());
    } catch (_) {
      _isOnline = false;
    }

    _sub?.cancel();
    _sub = _plugin.onConnectivityChanged.listen((results) {
      final online = _isOnlineResult(results);
      if (online == _isOnline) return;
      _isOnline = online;
      _onlineController.add(online);
    });
  }

  bool _isOnlineResult(List<plugin.ConnectivityResult> results) => results.any((r) => r != plugin.ConnectivityResult.none);

  bool get isOnline => _isOnline;

  Stream<bool> get onOnlineChanged => _onlineController.stream;

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _onlineController.close();
  }
}
