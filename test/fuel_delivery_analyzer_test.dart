import 'package:elm_obd2/core/diagnosis/fuel_delivery_analyzer.dart';
import 'package:elm_obd2/core/obd/models/sensor_reading.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = DateTime(2025, 1, 1, 12);

  SensorReading r(String pid, int sec, double value) => SensorReading(
        pid: pid,
        value: value,
        unit: '',
        timestamp: base.add(Duration(seconds: sec)),
      );

  group('FuelDeliveryAnalyzer', () {
    test('returns null for unrelated tests', () {
      final metrics = FuelDeliveryAnalyzer.compute('warm_idle_baseline', {});
      expect(metrics, isNull);
    });

    test('detects pressure drop and trim worsening under load', () {
      final readings = <String, List<SensorReading>>{
        'rpm': [
          r('rpm', 1, 800),
          r('rpm', 2, 820),
          r('rpm', 3, 790),
          r('rpm', 25, 2100),
          r('rpm', 26, 2050),
          r('rpm', 27, 2150),
        ],
        'fuel_pressure': [
          r('fuel_pressure', 1, 310),
          r('fuel_pressure', 2, 305),
          r('fuel_pressure', 3, 308),
          r('fuel_pressure', 25, 260),
          r('fuel_pressure', 26, 255),
          r('fuel_pressure', 27, 258),
        ],
        'stft_b1': [
          r('stft_b1', 1, 2),
          r('stft_b1', 2, 3),
          r('stft_b1', 3, 1),
          r('stft_b1', 25, 12),
          r('stft_b1', 26, 14),
          r('stft_b1', 27, 13),
        ],
        'ltft_b1': [
          r('ltft_b1', 1, 4),
          r('ltft_b1', 2, 5),
          r('ltft_b1', 3, 3),
          r('ltft_b1', 25, 10),
          r('ltft_b1', 26, 11),
          r('ltft_b1', 27, 12),
        ],
      };

      final metrics = FuelDeliveryAnalyzer.compute(
        'fuel_pressure_load_test',
        readings,
      );

      expect(metrics, isNotNull);
      expect(metrics!.hasIdleLoadComparison, isTrue);
      expect(metrics.fuelPressureDropUnderLoadKpa, greaterThan(20));
      expect(metrics.trimDeltaIdleVsLoadStft, greaterThan(5));

      final events = FuelDeliveryAnalyzer.notableEvents(metrics);
      expect(
        events.any((e) => e.description.contains('Fuel pressure dropped')),
        isTrue,
      );
      expect(
        events.any((e) => e.description.contains('STFT worsened')),
        isTrue,
      );
    });

    test('flags incomplete test when load phase missing', () {
      final readings = <String, List<SensorReading>>{
        'rpm': [
          r('rpm', 1, 800),
          r('rpm', 2, 820),
          r('rpm', 3, 790),
        ],
        'stft_b1': [
          r('stft_b1', 1, 2),
          r('stft_b1', 2, 3),
          r('stft_b1', 3, 1),
        ],
      };

      final metrics = FuelDeliveryAnalyzer.compute(
        'fuel_pressure_load_test',
        readings,
      );

      expect(metrics!.hasIdleLoadComparison, isFalse);
      final events = FuelDeliveryAnalyzer.notableEvents(metrics);
      expect(events.first.description, contains('Load test incomplete'));
    });
  });
}
