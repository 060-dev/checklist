import 'dart:async';

import 'package:morro_do_peo/utils/connectivity.dart';

class ConnectivityImpl implements Connectivity {
  @override
  bool get isOnline => true;

  @override
  Stream<bool> get onOnlineChanged => const Stream<bool>.empty();
}
