import 'sensor_reading.dart';

class TestResult {
  final String testId;
  final DateTime startTime;
  final DateTime endTime;
  final List<SensorReading> readings;
  final bool completed;

  const TestResult({
    required this.testId,
    required this.startTime,
    required this.endTime,
    required this.readings,
    this.completed = true,
  });

  int get durationSeconds => endTime.difference(startTime).inSeconds;
}
