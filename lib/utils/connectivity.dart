/// Permanent offline stub — isOnline is always false.
/// The app accumulates submissions locally and never flushes to the network.
class Connectivity {
  static final Connectivity instance = Connectivity._();
  Connectivity._();

  Future<void> init() async {}

  bool get isOnline => false;

  Stream<bool> get onOnlineChanged => const Stream.empty();
}
