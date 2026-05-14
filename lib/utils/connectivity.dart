import 'package:flutter/foundation.dart';

import 'connectivity_stub.dart'
    if (dart.library.html) 'connectivity_web.dart';

/// Conectividade mínima (sem dependências externas).
///
/// - Web: usa `window.navigator.onLine` e eventos `online/offline`.
/// - Mobile/Desktop: assume online (o retry por tempo ainda funciona).
abstract class Connectivity {
  static Connectivity get instance => ConnectivityImpl();

  bool get isOnline;

  Stream<bool> get onOnlineChanged;
}

@visibleForTesting
Connectivity createConnectivity() => Connectivity.instance;
