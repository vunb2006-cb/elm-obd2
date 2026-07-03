import '../obd/models/sensor_reading.dart';
import 'models/sensor_summary.dart';

/// Computes idle-vs-load fuel delivery metrics and related notable events.
class FuelDeliveryAnalyzer {
  FuelDeliveryAnalyzer._();

  static const idleRpmMax = 1100.0;
  static const loadRpmMin = 1800.0;
  static const minPhaseSamples = 3;
  static const pressureDropThresholdKpa = 20.0;
  static const trimWorseningThresholdPct = 5.0;

  static DerivedMetrics? compute(
    String testId,
    Map<String, List<SensorReading>> allReadings,
  ) {
    if (testId != 'fuel_pressure_load_test') return null;
    return _analyzeIdleVsLoad(allReadings);
  }

  static List<NotableEvent> notableEvents(DerivedMetrics? metrics) {
    if (metrics == null || !metrics.hasIdleLoadComparison) {
      return [
        const NotableEvent(
          secondsIntoTest: 0,
          description:
              'Load test incomplete: need warm idle (~20s) then hold 2000–2500 RPM '
              'for the remainder of the test.',
        ),
      ];
    }

    final events = <NotableEvent>[];
    final drop = metrics.fuelPressureDropUnderLoadKpa;
    if (drop != null && drop >= pressureDropThresholdKpa) {
      events.add(NotableEvent(
        secondsIntoTest: 0,
        description:
            'Fuel pressure dropped ${drop.toStringAsFixed(1)} kPa under load '
            '(idle ${metrics.fuelPressureIdleKpa!.toStringAsFixed(0)} → '
            'load ${metrics.fuelPressureLoadKpa!.toStringAsFixed(0)} kPa) — '
            'suggests weak fuel pump or failing pressure regulator',
      ));
    }

    final stftDelta = metrics.trimDeltaIdleVsLoadStft;
    if (stftDelta != null && stftDelta >= trimWorseningThresholdPct) {
      events.add(NotableEvent(
        secondsIntoTest: 0,
        description:
            'STFT worsened ${stftDelta.toStringAsFixed(1)}% under load '
            '(idle ${metrics.stftIdlePct!.toStringAsFixed(1)}% → '
            'load ${metrics.stftLoadPct!.toStringAsFixed(1)}%) — '
            'fuel delivery may not meet demand',
      ));
    }

    final ltftDelta = metrics.trimDeltaIdleVsLoadLtft;
    if (ltftDelta != null && ltftDelta >= trimWorseningThresholdPct) {
      events.add(NotableEvent(
        secondsIntoTest: 0,
        description:
            'LTFT worsened ${ltftDelta.toStringAsFixed(1)}% under load '
            '(idle ${metrics.ltftIdlePct!.toStringAsFixed(1)}% → '
            'load ${metrics.ltftLoadPct!.toStringAsFixed(1)}%)',
      ));
    }

    if (metrics.fuelPressureIdleKpa != null &&
        metrics.fuelPressureIdleKpa! < 250 &&
        (drop == null || drop < pressureDropThresholdKpa)) {
      events.add(NotableEvent(
        secondsIntoTest: 0,
        description:
            'Fuel pressure steadily low at idle '
            '(${metrics.fuelPressureIdleKpa!.toStringAsFixed(0)} kPa) — '
            'clogged fuel filter or weak pump possible',
      ));
    }

    return events;
  }

  static DerivedMetrics _analyzeIdleVsLoad(
    Map<String, List<SensorReading>> allReadings,
  ) {
    final rpm = allReadings['rpm'] ?? [];
    final pressure = allReadings['fuel_pressure'] ?? [];
    final stft = allReadings['stft_b1'] ?? [];
    final ltft = allReadings['ltft_b1'] ?? [];

    final idlePressure = <double>[];
    final loadPressure = <double>[];
    final idleStft = <double>[];
    final loadStft = <double>[];
    final idleLtft = <double>[];
    final loadLtft = <double>[];

    for (final r in rpm) {
      final isIdle = r.value < idleRpmMax;
      final isLoad = r.value > loadRpmMin;
      if (!isIdle && !isLoad) continue;

      void bucket(List<double> idle, List<double> load, List<SensorReading> src) {
        final v = _valueNear(src, r.timestamp);
        if (v == null) return;
        if (isIdle) {
          idle.add(v);
        } else {
          load.add(v);
        }
      }

      bucket(idlePressure, loadPressure, pressure);
      bucket(idleStft, loadStft, stft);
      bucket(idleLtft, loadLtft, ltft);
    }

    final idlePressureAvg = _avg(idlePressure);
    final loadPressureAvg = _avg(loadPressure);
    final idleStftAvg = _avg(idleStft);
    final loadStftAvg = _avg(loadStft);
    final idleLtftAvg = _avg(idleLtft);
    final loadLtftAvg = _avg(loadLtft);

    double? pressureDrop;
    if (idlePressureAvg != null && loadPressureAvg != null) {
      pressureDrop = idlePressureAvg - loadPressureAvg;
    }

    return DerivedMetrics(
      fuelPressureIdleKpa: idlePressureAvg,
      fuelPressureLoadKpa: loadPressureAvg,
      fuelPressureDropUnderLoadKpa: pressureDrop,
      stftIdlePct: idleStftAvg,
      stftLoadPct: loadStftAvg,
      trimDeltaIdleVsLoadStft: idleStftAvg != null && loadStftAvg != null
          ? loadStftAvg - idleStftAvg
          : null,
      ltftIdlePct: idleLtftAvg,
      ltftLoadPct: loadLtftAvg,
      trimDeltaIdleVsLoadLtft: idleLtftAvg != null && loadLtftAvg != null
          ? loadLtftAvg - idleLtftAvg
          : null,
      idleSampleCount: idleStft.isNotEmpty ? idleStft.length : idlePressure.length,
      loadSampleCount: loadStft.isNotEmpty ? loadStft.length : loadPressure.length,
    );
  }

  static double? _valueNear(List<SensorReading> readings, DateTime at) {
    if (readings.isEmpty) return null;
    SensorReading best = readings.first;
    var bestMs = best.timestamp.difference(at).inMilliseconds.abs();
    for (final r in readings) {
      final ms = r.timestamp.difference(at).inMilliseconds.abs();
      if (ms < bestMs) {
        best = r;
        bestMs = ms;
      }
    }
    if (bestMs > 3000) return null;
    return best.value;
  }

  static double? _avg(List<double> values) {
    if (values.length < minPhaseSamples) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}
