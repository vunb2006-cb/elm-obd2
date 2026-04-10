class SensorReading {
  final String pid;
  final double value;
  final String unit;
  final DateTime timestamp;

  const SensorReading({
    required this.pid,
    required this.value,
    required this.unit,
    required this.timestamp,
  });

  @override
  String toString() => '$pid: $value $unit @ ${timestamp.toIso8601String()}';
}
