import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'package:morro_do_peo/utils/connectivity.dart';

class ConnectivityImpl implements Connectivity {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _listening = false;

  ConnectivityImpl() {
    _ensureListening();
  }

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    web.window.addEventListener('online', (web.Event _) {
      _controller.add(true);
    }.toJS);
    web.window.addEventListener('offline', (web.Event _) {
      _controller.add(false);
    }.toJS);
  }

  @override
  bool get isOnline => web.window.navigator.onLine;

  @override
  Stream<bool> get onOnlineChanged {
    _ensureListening();
    return _controller.stream;
  }
}
