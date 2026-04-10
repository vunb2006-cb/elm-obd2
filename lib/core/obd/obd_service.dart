import 'dart:async';

import 'elm327_connector.dart';
import 'pid_decoder.dart';
import 'dtc_decoder.dart';
import 'pid_constants.dart';
import 'models/dtc_code.dart';
import 'models/sensor_reading.dart';

class ObdService {
  final Elm327Connector connector;

  /// Populated after [readSupportedPIDs] is called.
  /// Empty means "not yet read — assume all PIDs are supported."
  Set<String> _supportedPids = {};

  /// The set of PID hex codes confirmed supported by the connected ECU.
  Set<String> get supportedPids => Set.unmodifiable(_supportedPids);

  /// Returns true if [pidCode] is supported by the ECU.
  /// Always returns true before [readSupportedPIDs] has been called (safe default).
  bool isPidSupported(String pidCode) {
    if (_supportedPids.isEmpty) return true;
    return _supportedPids.contains(pidCode.toUpperCase());
  }

  ObdService(this.connector);

  // ─── DTCs ──────────────────────────────────────────────────────────────────

  /// Read stored fault codes (mode 03).
  Future<List<DtcCode>> readDTCs() async {
    final response = await connector.sendCommand('03');
    return DtcDecoder.decode(response, isPending: false);
  }

  /// Read pending fault codes (mode 07).
  Future<List<DtcCode>> readPendingDTCs() async {
    final response = await connector.sendCommand('07');
    return DtcDecoder.decode(response, isPending: true);
  }

  /// Read freeze frame data for the first stored DTC.
  /// Returns a map of PID → value for the supported mode-02 PIDs.
  Future<Map<String, double>> readFreezeFrame() async {
    final result = <String, double>{};
    const ffPids = [
      PidConstants.rpm,
      PidConstants.speed,
      PidConstants.coolantTemp,
      PidConstants.engineLoad,
      PidConstants.stftB1,
      PidConstants.ltftB1,
      PidConstants.map,
      PidConstants.throttlePos,
    ];

    for (final pid in ffPids) {
      try {
        // Mode 02: freeze frame, frame 0
        final response = await connector.sendCommand('02${pid}00');
        // Mode 02 response header is "42" + pid
        final decoded = _decodeMode02(pid, response);
        if (decoded != null) result[pid] = decoded;
      } catch (_) {
        // Skip unsupported PIDs
      }
    }
    return result;
  }

  double? _decodeMode02(String pid, String response) {
    // Mode 02 response: "42 <pid> <frame> <data...>"
    // Reuse PidDecoder by faking it as mode 01 response "41 <pid> <data>"
    final clean = response.replaceAll(RegExp(r'[\s\r\n>]'), '').toUpperCase();
    final header = '42${pid.toUpperCase()}';
    final idx = clean.indexOf(header);
    if (idx == -1) return null;
    // Skip 2 chars for frame number
    final dataHex = clean.substring(idx + header.length + 2);
    final faked = '41${pid.toUpperCase()}$dataHex';
    return PidDecoder.decode(pid, faked);
  }

  // ─── Single PID reads ──────────────────────────────────────────────────────

  /// Read a single PID value.
  Future<double?> readPID(String pid) async {
    final response = await connector.sendCommand('01$pid');
    return PidDecoder.decode(pid, response);
  }

  // ─── Polling ───────────────────────────────────────────────────────────────

  /// Poll a single PID repeatedly for [seconds] at approximately [hz] samples/sec.
  /// Returns the list of readings collected.
  Future<List<SensorReading>> pollPID(
    String pid, {
    required int seconds,
    double hz = 1.0,
  }) async {
    final readings = <SensorReading>[];
    final intervalMs = (1000 / hz).round();
    final endTime = DateTime.now().add(Duration(seconds: seconds));

    while (DateTime.now().isBefore(endTime)) {
      final start = DateTime.now();
      try {
        final value = await readPID(pid);
        if (value != null) {
          readings.add(SensorReading(
            pid: pid,
            value: value,
            unit: PidConstants.unitFor(pid),
            timestamp: DateTime.now(),
          ));
        }
      } catch (_) {
        // Skip failed reads silently
      }

      // Wait for remainder of interval
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final remaining = intervalMs - elapsed;
      if (remaining > 0) {
        await Future.delayed(Duration(milliseconds: remaining));
      }
    }

    return readings;
  }

  /// Poll multiple PIDs in round-robin for [seconds].
  Future<Map<String, List<SensorReading>>> pollPIDs(
    List<String> pids, {
    required int seconds,
    double hz = 1.0,
  }) async {
    final readings = <String, List<SensorReading>>{
      for (final p in pids) p: [],
    };
    final intervalMs = (1000 / hz).round();
    final perPidMs = intervalMs ~/ pids.length;
    final endTime = DateTime.now().add(Duration(seconds: seconds));

    while (DateTime.now().isBefore(endTime)) {
      for (final pid in pids) {
        if (DateTime.now().isAfter(endTime)) break;
        final start = DateTime.now();
        try {
          final value = await readPID(pid);
          if (value != null) {
            readings[pid]!.add(SensorReading(
              pid: pid,
              value: value,
              unit: PidConstants.unitFor(pid),
              timestamp: DateTime.now(),
            ));
          }
        } catch (_) {
          // Skip
        }
        final elapsed = DateTime.now().difference(start).inMilliseconds;
        final wait = perPidMs - elapsed;
        if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      }
    }

    return readings;
  }

  // ─── Supported PIDs ────────────────────────────────────────────────────────

  /// Clears the supported-PID cache. Call this when connecting to a new vehicle.
  void resetSupportedPids() => _supportedPids = {};

  /// Read the supported PIDs bitmask for ranges 01-20, 21-40, 41-60.
  /// Caches the result — call [isPidSupported] afterwards to check any PID.
  Future<List<String>> readSupportedPIDs() async {
    final supported = <String>[];
    const ranges = ['0100', '0120', '0140'];

    for (final cmd in ranges) {
      try {
        final response = await connector.sendCommand(cmd);
        final pids = _parseSupportedPIDs(cmd, response);
        supported.addAll(pids);
      } catch (_) {
        break;
      }
    }

    _supportedPids = supported.map((p) => p.toUpperCase()).toSet();
    return supported;
  }

  List<String> _parseSupportedPIDs(String cmd, String response) {
    final pids = <String>[];
    final clean = response.replaceAll(RegExp(r'[\s\r\n>]'), '').toUpperCase();
    // Response is "4100XXXXXXXX" where X = bitmask
    final pidBase = int.parse(cmd.substring(2), radix: 16); // 0x00, 0x20, 0x40
    final header = '41${cmd.substring(2).toUpperCase()}';
    final idx = clean.indexOf(header);
    if (idx == -1) return pids;

    final data = clean.substring(idx + header.length);
    if (data.length < 8) return pids;

    final mask = int.parse(data.substring(0, 8), radix: 16);
    for (var bit = 31; bit >= 0; bit--) {
      if ((mask >> bit) & 1 == 1) {
        final pidNum = pidBase + (32 - bit);
        pids.add(pidNum.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return pids;
  }
}
