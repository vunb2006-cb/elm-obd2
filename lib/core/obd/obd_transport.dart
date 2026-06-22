enum Elm327State {
  disconnected,
  connecting,
  initializing,
  connected,
  error,
}

/// Minimal contract [ObdService] depends on to talk to an ELM327-like device.
///
/// Implemented by the real [Elm327Connector] (Bluetooth SPP hardware) and by
/// `SimulatedElm327Connector` (in-app virtual ECU). Everything downstream of
/// [ObdService] — test executor, condition evaluator, live monitor — works
/// identically against either, so simulate mode requires no changes there.
abstract class ObdTransport {
  Stream<Elm327State> get stateStream;
  Elm327State get state;
  bool get isConnected;
  String? get lastConnectedAddress;

  Future<String> sendCommand(String cmd);
  Future<void> disconnect();
  void dispose();
}
