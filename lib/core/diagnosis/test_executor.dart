import 'dart:async';
import 'dart:math';

import '../obd/obd_service.dart';
import '../obd/pid_constants.dart';
import '../obd/models/sensor_reading.dart';
import 'test_library.dart';
import 'models/sensor_summary.dart';

typedef ProgressCallback = void Function(
    int elapsed, Map<String, double> current);

class TestExecutor {
  final ObdService _obd;
  bool _cancelled = false;

  TestExecutor(this._obd);

  /// Execute a named test by ID and return a [SensorSummary].
  ///
  /// PIDs that are not supported by the connected ECU are skipped automatically
  /// (no timeout wait) and reported in [SensorSummary.skippedPids] so Gemini
  /// knows exactly what data was unavailable on this vehicle.
  ///
  /// [onProgress] is called roughly every second with elapsed time and
  /// latest PID values so the UI can update in real time.
  Future<SensorSummary> execute(
    String testId, {
    ProgressCallback? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final def = TestLibrary.byId(testId);
    if (def == null) throw ArgumentError('Unknown test id: $testId');

    _cancelled = false;

    // Split test PIDs into supported vs unsupported up-front so we never
    // waste time waiting for a timeout on a PID this ECU doesn't have.
    final supportedPidNames = <String>[];
    final skippedPidNames = <String>[];
    for (final pidName in def.pids) {
      final code = PidConstants.codeForName(pidName) ?? pidName;
      if (_obd.isPidSupported(code)) {
        supportedPidNames.add(pidName);
      } else {
        skippedPidNames.add(pidName);
      }
    }

    final allReadings = <String, List<SensorReading>>{
      for (final p in supportedPidNames) p: [],
    };

    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(seconds: def.durationSeconds));
    final intervalMs = (1000 / def.sampleRateHz).round();
    final activePids = supportedPidNames;
    final perPidMs =
        activePids.isNotEmpty ? intervalMs ~/ activePids.length : intervalMs;

    while (DateTime.now().isBefore(endTime)) {
      if (_cancelled || (shouldCancel?.call() ?? false)) break;

      final latestValues = <String, double>{};

      for (final pidName in activePids) {
        if (_cancelled || (shouldCancel?.call() ?? false)) break;

        final code = PidConstants.codeForName(pidName) ?? pidName;
        final start = DateTime.now();

        try {
          final value = await _obd.readPID(code);
          if (value != null) {
            final reading = SensorReading(
              pid: pidName,
              value: value,
              unit: PidConstants.unitFor(code),
              timestamp: DateTime.now(),
            );
            allReadings[pidName]!.add(reading);
            latestValues[pidName] = value;
          }
        } catch (_) {}

        final elapsed = DateTime.now().difference(start).inMilliseconds;
        final wait = perPidMs - elapsed;
        if (wait > 0) await Future.delayed(Duration(milliseconds: wait));
      }

      final elapsedSecs = DateTime.now().difference(startTime).inSeconds;
      onProgress?.call(elapsedSecs, latestValues);
    }

    final actualDuration = DateTime.now().difference(startTime).inSeconds;
    return _buildSummary(
        testId, actualDuration, allReadings, startTime, skippedPidNames);
  }

  void cancel() => _cancelled = true;

  SensorSummary _buildSummary(
    String testId,
    int durationSeconds,
    Map<String, List<SensorReading>> allReadings,
    DateTime startTime,
    List<String> skippedPids,
  ) {
    final pidSummaries = <String, PidSummary>{};
    int totalSamples = 0;

    for (final entry in allReadings.entries) {
      if (entry.value.isEmpty) continue;
      pidSummaries[entry.key] = PidSummary.fromReadings(entry.key, entry.value);
      totalSamples += entry.value.length;
    }

    final events = _detectNotableEvents(allReadings, startTime);

    return SensorSummary(
      testId: testId,
      durationSeconds: durationSeconds,
      sampleCount: totalSamples,
      pidSummaries: pidSummaries,
      notableEvents: events,
      skippedPids: skippedPids,
    );
  }

  List<NotableEvent> _detectNotableEvents(
    Map<String, List<SensorReading>> allReadings,
    DateTime startTime,
  ) {
    final events = <NotableEvent>[];

    // RPM dip > 200 in under 2 seconds → near-stall
    final rpmReadings = allReadings['rpm'] ?? [];
    for (var i = 1; i < rpmReadings.length; i++) {
      final prev = rpmReadings[i - 1];
      final curr = rpmReadings[i];
      final dt = curr.timestamp.difference(prev.timestamp).inMilliseconds;
      if (dt < 2000 && (prev.value - curr.value) > 200) {
        events.add(NotableEvent(
          secondsIntoTest:
              curr.timestamp.difference(startTime).inSeconds,
          description:
              'RPM dipped from ${prev.value.toStringAsFixed(0)} to '
              '${curr.value.toStringAsFixed(0)} (near-stall event)',
        ));
      }
    }

    // STFT spike > 20%
    final stftReadings = allReadings['stft_b1'] ?? [];
    for (final r in stftReadings) {
      if (r.value.abs() > 20) {
        events.add(NotableEvent(
          secondsIntoTest:
              r.timestamp.difference(startTime).inSeconds,
          description:
              'Fuel trim spike: STFT = ${r.value.toStringAsFixed(1)}%',
        ));
      }
    }

    // O2 sensor stuck (same voltage ± 0.02V for > 5 seconds)
    final o2Readings = allReadings['o2_b1s1'] ?? [];
    if (o2Readings.length >= 5) {
      for (var i = 4; i < o2Readings.length; i++) {
        final window = o2Readings.sublist(i - 4, i + 1);
        final vals = window.map((r) => r.value).toList();
        final spread = vals.reduce(max) - vals.reduce(min);
        final spanSecs = window.last.timestamp
            .difference(window.first.timestamp)
            .inSeconds;
        if (spread < 0.02 && spanSecs >= 5) {
          events.add(NotableEvent(
            secondsIntoTest: window.last.timestamp
                .difference(startTime)
                .inSeconds,
            description:
                'O2 sensor non-responsive: stuck at '
                '${vals.last.toStringAsFixed(3)}V for ${spanSecs}s',
          ));
          break; // Report once per test
        }
      }
    }

    return events;
  }
}
