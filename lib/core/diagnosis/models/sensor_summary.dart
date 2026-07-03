import 'dart:math';

import '../../obd/models/sensor_reading.dart';
import '../../obd/pid_constants.dart';

class PidSummary {
  final String pid;
  final double avg;
  final double min;
  final double max;
  final double stdDev;
  final String stability; // "stable" | "variable" | "erratic"

  const PidSummary({
    required this.pid,
    required this.avg,
    required this.min,
    required this.max,
    required this.stdDev,
    required this.stability,
  });

  factory PidSummary.fromReadings(String pid, List<SensorReading> readings) {
    if (readings.isEmpty) {
      return PidSummary(
          pid: pid, avg: 0, min: 0, max: 0, stdDev: 0, stability: 'stable');
    }
    final values = readings.map((r) => r.value).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final variance =
        values.map((v) => pow(v - avg, 2)).reduce((a, b) => a + b) /
            values.length;
    final stdDev = sqrt(variance);

    final cv = avg.abs() > 0.001 ? stdDev / avg.abs() : 0.0;
    final stability = cv < 0.05
        ? 'stable'
        : cv < 0.20
            ? 'variable'
            : 'erratic';

    return PidSummary(
      pid: pid,
      avg: avg,
      min: min,
      max: max,
      stdDev: stdDev,
      stability: stability,
    );
  }

  String toText() {
    final name = PidConstants.nameFor(pid);
    final unit = PidConstants.unitFor(pid);
    return '$name — avg: ${avg.toStringAsFixed(2)}$unit, '
        'min: ${min.toStringAsFixed(2)}, '
        'max: ${max.toStringAsFixed(2)}, '
        'stdDev: ${stdDev.toStringAsFixed(2)}, '
        'stability: $stability';
  }
}

class NotableEvent {
  final int secondsIntoTest;
  final String description;

  const NotableEvent({
    required this.secondsIntoTest,
    required this.description,
  });
}

/// Structured idle-vs-load comparison for fuel delivery diagnosis.
class DerivedMetrics {
  final double? fuelPressureIdleKpa;
  final double? fuelPressureLoadKpa;
  /// Positive = pressure fell from idle to load (weak pump / volume loss).
  final double? fuelPressureDropUnderLoadKpa;
  final double? stftIdlePct;
  final double? stftLoadPct;
  /// Positive = trims leaner under load than at idle.
  final double? trimDeltaIdleVsLoadStft;
  final double? ltftIdlePct;
  final double? ltftLoadPct;
  final double? trimDeltaIdleVsLoadLtft;
  final int idleSampleCount;
  final int loadSampleCount;

  const DerivedMetrics({
    this.fuelPressureIdleKpa,
    this.fuelPressureLoadKpa,
    this.fuelPressureDropUnderLoadKpa,
    this.stftIdlePct,
    this.stftLoadPct,
    this.trimDeltaIdleVsLoadStft,
    this.ltftIdlePct,
    this.ltftLoadPct,
    this.trimDeltaIdleVsLoadLtft,
    this.idleSampleCount = 0,
    this.loadSampleCount = 0,
  });

  bool get hasIdleLoadComparison => idleSampleCount >= 3 && loadSampleCount >= 3;

  List<String> toPromptLines() {
    if (!hasIdleLoadComparison) {
      return [
        'Insufficient idle vs load samples — user should idle ~20s then hold 2000–2500 RPM.',
      ];
    }

    final lines = <String>[
      'Idle phase samples: $idleSampleCount | Load phase samples: $loadSampleCount',
    ];

    if (fuelPressureIdleKpa != null && fuelPressureLoadKpa != null) {
      lines.add(
        'Fuel pressure idle avg: ${fuelPressureIdleKpa!.toStringAsFixed(1)} kPa → '
        'load avg: ${fuelPressureLoadKpa!.toStringAsFixed(1)} kPa',
      );
      if (fuelPressureDropUnderLoadKpa != null) {
        lines.add(
          'Pressure drop under load: ${fuelPressureDropUnderLoadKpa!.toStringAsFixed(1)} kPa '
          '(>20 kPa suggests weak pump or regulator; steady low idle suggests clogged filter)',
        );
      }
    } else {
      lines.add(
        'Fuel pressure PID unavailable — infer delivery from trim delta below.',
      );
    }

    if (stftIdlePct != null && stftLoadPct != null) {
      lines.add(
        'STFT idle avg: ${stftIdlePct!.toStringAsFixed(1)}% → '
        'load avg: ${stftLoadPct!.toStringAsFixed(1)}% '
        '(Δ ${trimDeltaIdleVsLoadStft!.toStringAsFixed(1)}%)',
      );
    }
    if (ltftIdlePct != null && ltftLoadPct != null) {
      lines.add(
        'LTFT idle avg: ${ltftIdlePct!.toStringAsFixed(1)}% → '
        'load avg: ${ltftLoadPct!.toStringAsFixed(1)}% '
        '(Δ ${trimDeltaIdleVsLoadLtft!.toStringAsFixed(1)}%)',
      );
    }

    return lines;
  }
}

class SensorSummary {
  final String testId;
  final int durationSeconds;
  final int sampleCount;
  final Map<String, PidSummary> pidSummaries;
  final List<NotableEvent> notableEvents;

  /// PIDs requested by the test that are not supported by this vehicle's ECU.
  /// These were not polled at all — their absence is not a data gap, it is a
  /// hardware limitation. Gemini must not interpret missing data as a zero reading.
  final List<String> skippedPids;

  /// Test-specific computed metrics (e.g. idle-vs-load fuel delivery comparison).
  final DerivedMetrics? derivedMetrics;

  const SensorSummary({
    required this.testId,
    required this.durationSeconds,
    required this.sampleCount,
    required this.pidSummaries,
    required this.notableEvents,
    this.skippedPids = const [],
    this.derivedMetrics,
  });

  /// Serialize to a clean text block for the Gemini prompt.
  String toPromptText() {
    final sb = StringBuffer();
    sb.writeln('=== TEST RESULT: $testId ===');
    sb.writeln('Duration: ${durationSeconds}s | Samples: $sampleCount');

    sb.writeln('');
    sb.writeln('--- PID SUMMARIES ---');
    for (final s in pidSummaries.values) {
      sb.writeln(s.toText());
    }

    if (skippedPids.isNotEmpty) {
      sb.writeln('');
      sb.writeln('--- PIDs NOT SUPPORTED BY THIS VEHICLE ---');
      sb.writeln(
          'The following sensors are not available on this ECU and were not measured. '
          'Do not treat their absence as a zero value or anomaly:');
      for (final pid in skippedPids) {
        final name = PidConstants.nameFor(
            PidConstants.codeForName(pid) ?? pid);
        sb.writeln('  • $pid ($name)');
      }
    }

    if (derivedMetrics != null) {
      sb.writeln('');
      sb.writeln('--- DERIVED METRICS ---');
      for (final line in derivedMetrics!.toPromptLines()) {
        sb.writeln(line);
      }
    }

    if (notableEvents.isNotEmpty) {
      sb.writeln('');
      sb.writeln('--- NOTABLE EVENTS ---');
      for (final e in notableEvents) {
        sb.writeln('[${e.secondsIntoTest}s] ${e.description}');
      }
    }
    return sb.toString();
  }
}
