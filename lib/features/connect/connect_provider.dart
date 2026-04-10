import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/obd/elm327_connector.dart';
import '../../core/obd/obd_service.dart';

// ─── Singleton connector & service ────────────────────────────────────────────

final elm327Provider = Provider<Elm327Connector>((ref) {
  final connector = Elm327Connector();
  ref.onDispose(connector.dispose);
  return connector;
});

final obdServiceProvider = Provider<ObdService>((ref) {
  return ObdService(ref.watch(elm327Provider));
});

// ─── Connection state ─────────────────────────────────────────────────────────

final connectionStateProvider = StreamProvider<Elm327State>((ref) {
  return ref.watch(elm327Provider).stateStream;
});

/// The Bluetooth address of the currently (or most recently) connected device.
final lastConnectedAddressProvider = Provider<String?>((ref) {
  return ref.watch(elm327Provider).lastConnectedAddress;
});

// ─── Bonded devices ───────────────────────────────────────────────────────────

final bondedDevicesProvider = FutureProvider<List<BluetoothDevice>>((ref) {
  return ref.watch(elm327Provider).getBondedDevices();
});

// ─── Connect notifier ─────────────────────────────────────────────────────────

class ConnectNotifier extends StateNotifier<AsyncValue<void>> {
  final Elm327Connector _connector;

  ConnectNotifier(this._connector) : super(const AsyncValue.data(null));

  Future<void> connect(String address) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _connector.connect(address));
  }

  Future<void> disconnect() async {
    await _connector.disconnect();
    state = const AsyncValue.data(null);
  }
}

final connectNotifierProvider =
    StateNotifierProvider<ConnectNotifier, AsyncValue<void>>((ref) {
  return ConnectNotifier(ref.watch(elm327Provider));
});
