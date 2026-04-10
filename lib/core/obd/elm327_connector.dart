import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

enum Elm327State {
  disconnected,
  connecting,
  initializing,
  connected,
  error,
}

class Elm327Connector {
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSub;

  final _stateController = StreamController<Elm327State>.broadcast();
  Elm327State _state = Elm327State.disconnected;

  // Strictly serial command queue.
  final _queue = Queue<_Cmd>();
  bool _busy = false;
  _Cmd? _active;
  final _buffer = StringBuffer();

  static const _timeout = Duration(milliseconds: 2500);
  static const _initDelay = Duration(milliseconds: 600);

  String? _lastConnectedAddress;

  Stream<Elm327State> get stateStream => _stateController.stream;
  Elm327State get state => _state;
  bool get isConnected => _state == Elm327State.connected;

  /// The Bluetooth address of the device we are currently (or were last) connected to.
  String? get lastConnectedAddress => _lastConnectedAddress;

  /// Returns all bonded Bluetooth devices (UI filters by name).
  Future<List<BluetoothDevice>> getBondedDevices() =>
      FlutterBluetoothSerial.instance.getBondedDevices();

  /// Connects to [address] and runs the ELM327 initialisation sequence.
  ///
  /// Safe to call after the app restarts: cleans up any stale connection first,
  /// then retries once if the first attempt fails (Android's RFCOMM stack needs
  /// ~1 second to release a socket orphaned when the app was killed).
  Future<void> connect(String address) async {
    if (_state == Elm327State.connecting ||
        _state == Elm327State.initializing ||
        _state == Elm327State.connected) {
      return;
    }

    // Tear down any stale socket before opening a fresh one.
    await _forceCleanup();

    _lastConnectedAddress = address;
    _setState(Elm327State.connecting);

    BluetoothConnection? conn;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        conn = await BluetoothConnection.toAddress(address);
        break;
      } catch (e) {
        if (attempt == 1) {
          _setState(Elm327State.error);
          rethrow;
        }
        // First attempt failed — give the BT stack a moment then retry.
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    try {
      _connection = conn;
      _setState(Elm327State.initializing);
      _buffer.clear();
      _queue.clear();
      _busy = false;
      _active = null;

      _inputSub?.cancel();
      _inputSub = _connection!.input!.listen(
        _onBytes,
        onDone: _handleDisconnect,
        onError: (_) => _handleDisconnect(),
        cancelOnError: false,
      );

      await _init();
      _setState(Elm327State.connected);
    } catch (e) {
      _setState(Elm327State.error);
      rethrow;
    }
  }

  /// Forcefully tears down any lingering subscription and socket.
  Future<void> _forceCleanup() async {
    _inputSub?.cancel();
    _inputSub = null;
    _active?.timer?.cancel();
    _active = null;
    _queue.clear();
    _busy = false;
    try {
      await _connection?.close();
    } catch (_) {}
    _connection = null;
  }

  /// Send [cmd] to the ELM327 and return the response (everything before '>').
  Future<String> sendCommand(String cmd) {
    if (_connection == null || !_connection!.isConnected) {
      throw StateError('ELM327 not connected');
    }
    final c = _Cmd(cmd);
    _queue.add(c);
    _pump();
    return c.completer.future;
  }

  void _pump() {
    if (_busy || _queue.isEmpty) return;
    _busy = true;
    _active = _queue.removeFirst();
    _buffer.clear();
    _write('${_active!.cmd}\r');

    _active!.timer = Timer(_timeout, () {
      final a = _active;
      if (a != null && !a.completer.isCompleted) {
        a.completer.completeError(
          TimeoutException('ELM327 timeout: ${a.cmd}', _timeout),
        );
      }
      _active = null;
      _busy = false;
      _pump();
    });
  }

  void _onBytes(Uint8List data) {
    _buffer.write(utf8.decode(data, allowMalformed: true));
    if (!_buffer.toString().contains('>')) return;

    final response = _buffer.toString().replaceAll('>', '').trim();
    _buffer.clear();

    final a = _active;
    if (a != null) {
      a.timer?.cancel();
      if (!a.completer.isCompleted) a.completer.complete(response);
      _active = null;
    }
    _busy = false;
    _pump();
  }

  void _write(String s) {
    _connection?.output.add(Uint8List.fromList(utf8.encode(s)));
  }

  Future<void> _init() async {
    await sendCommand('ATZ').timeout(const Duration(seconds: 5));
    await Future.delayed(_initDelay);
    await sendCommand('ATE0'); // echo off
    await sendCommand('ATL0'); // linefeeds off
    await sendCommand('ATS0'); // spaces off
    await sendCommand('ATH0'); // headers off
    await sendCommand('ATSP0'); // auto protocol
  }

  void _handleDisconnect() {
    _inputSub?.cancel();
    _inputSub = null;
    _active?.timer?.cancel();
    if (_active != null && !_active!.completer.isCompleted) {
      _active!.completer.completeError(StateError('Bluetooth disconnected'));
    }
    _active = null;
    for (final cmd in _queue) {
      if (!cmd.completer.isCompleted) {
        cmd.completer.completeError(StateError('Bluetooth disconnected'));
      }
    }
    _queue.clear();
    _busy = false;
    _connection = null; // ensure stale socket reference is dropped
    _setState(Elm327State.disconnected);
  }

  Future<void> disconnect() async {
    await _forceCleanup();
    _setState(Elm327State.disconnected);
  }

  void _setState(Elm327State s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}

class _Cmd {
  final String cmd;
  final completer = Completer<String>();
  Timer? timer;
  _Cmd(this.cmd);
}
