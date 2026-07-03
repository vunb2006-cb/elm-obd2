import 'dart:async';
import 'dart:math';

import '../pid_constants.dart';
import 'fault_profile.dart';

/// A self-contained, time-evolving virtual engine.
///
/// Ticks every 100ms and computes plausible values for every PID in
/// [PidConstants] from a small set of driver-controlled inputs (throttle,
/// target speed, warm-up speed) plus the active [FaultProfile]. Everything
/// downstream (PidDecoder's inverse encoding, ObdService, TestExecutor,
/// ConditionEvaluator) is none the wiser — it just reads PID values exactly
/// as it would from real hardware.
class VirtualEcu {
  FaultProfile fault;

  VirtualEcu({this.fault = FaultProfile.healthy});

  final _rand = Random();
  Timer? _ticker;
  final DateTime _startTime = DateTime.now();

  // Driver-controlled inputs.
  double _throttlePct = 0; // 0-100, set via control panel
  double _targetSpeedKph = 0; // 0+, set via control panel
  bool _warmupFastForward = false;

  // Evolving state.
  double _rpm = 800;
  double _speed = 0;
  double _coolant = 20;
  double _oilTemp = 20;

  // Snapshot of all PID values, recomputed every tick.
  Map<String, double> _values = {};

  double get elapsedSeconds =>
      DateTime.now().difference(_startTime).inMilliseconds / 1000.0;

  void start() {
    _ticker ??= Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    _tick();
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ─── Driver controls ──────────────────────────────────────────────────────

  void setThrottle(double pct) => _throttlePct = pct.clamp(0, 100);

  void setTargetSpeed(double kph) => _targetSpeedKph = kph.clamp(0, 180);

  void setWarmupFastForward(bool on) => _warmupFastForward = on;

  void setFault(FaultProfile profile) => fault = profile;

  /// Briefly snaps the throttle open then closed — simulates a real driver
  /// blipping the gas pedal, for tests like `throttle_snap_test`.
  Future<void> snapThrottle() async {
    final prev = _throttlePct;
    setThrottle(85);
    await Future.delayed(const Duration(milliseconds: 900));
    setThrottle(prev);
  }

  double get throttlePct => _throttlePct;
  double get targetSpeedKph => _targetSpeedKph;
  bool get warmupFastForward => _warmupFastForward;
  double get rpm => _rpm;
  double get speedKph => _speed;
  double get coolantTemp => _coolant;

  // ─── Simulation tick ──────────────────────────────────────────────────────

  void _tick() {
    const dt = 0.1; // seconds per tick

    // RPM follows throttle with inertia: idle ~800, full throttle ~5000.
    final targetRpm = 800 + _throttlePct * 42;
    _rpm += (targetRpm - _rpm) * min(1.0, dt * 2.2);
    _rpm += (_rand.nextDouble() - 0.5) * 8; // idle noise

    // Speed follows the driver-set target with simple inertia.
    _speed += (_targetSpeedKph - _speed) * min(1.0, dt * 0.8);

    // Coolant warms toward a fault-dependent ceiling.
    final ceiling = fault == FaultProfile.thermostatStuckOpen ? 75.0 : 90.0;
    final tau = _warmupFastForward ? 8.0 : 40.0;
    _coolant += (ceiling - _coolant) * min(1.0, dt / tau);

    // Oil temp lags coolant.
    _oilTemp += (_coolant - 5 - _oilTemp) * min(1.0, dt / 90.0);

    _values = _computeAllPids();
  }

  Map<String, double> _computeAllPids() {
    final t = elapsedSeconds;
    final throttle = _throttlePct;
    final rpm = _rpm;
    final coolant = _coolant;

    final engineLoad =
        (15 + throttle * 0.5 + (rpm - 800) / 4200 * 30).clamp(0.0, 100.0);

    const baro = 99.0;
    final idleVacuum = 35.0 - throttle * 0.3;
    final leakLoss = fault == FaultProfile.vacuumLeak
        ? max(0.0, 1 - throttle / 30) * 20
        : 0.0;
    final map = (baro - idleVacuum + leakLoss).clamp(20.0, baro);

    final maf = (rpm / 1000) * (engineLoad / 100) * 9.0 + _noise(0.3);

    final stft = _fuelTrim(throttle, rpm: rpm, isShortTerm: true);
    final ltft = _fuelTrim(throttle, rpm: rpm, isShortTerm: false);

    final o2b1s1 = _upstreamO2(t);
    final o2b1s2 = 0.5 + 0.05 * sin(2 * pi * t * 0.1);

    final egr = ((rpm - 1500) / 3000 * 30).clamp(0.0, 30.0);
    final iat = 25 + engineLoad * 0.05;

    return {
      PidConstants.rpm: rpm,
      PidConstants.speed: _speed,
      PidConstants.coolantTemp: coolant,
      PidConstants.intakeAirTemp: iat,
      PidConstants.engineLoad: engineLoad,
      PidConstants.throttlePos: throttle,
      PidConstants.fuelLevel: 60.0,
      PidConstants.stftB1: stft,
      PidConstants.ltftB1: ltft,
      PidConstants.stftB2: stft * 0.9,
      PidConstants.ltftB2: ltft * 0.9,
      PidConstants.map: map,
      PidConstants.fuelPressure: _fuelPressure(rpm, throttle, engineLoad),
      PidConstants.maf: maf,
      PidConstants.o2B1S1: o2b1s1,
      PidConstants.o2B1S2: o2b1s2,
      PidConstants.engineRunTime: t,
      PidConstants.distanceMilOn: 0.0,
      PidConstants.egrCommanded: egr,
      PidConstants.baroPressure: baro + _noise(0.3),
      PidConstants.oilTemp: _oilTemp,
    };
  }

  double _fuelPressure(double rpm, double throttle, double engineLoad) {
    const base = 310.0;
    if (fault == FaultProfile.weakFuelPump) {
      final demand = ((rpm - 800) / 3500).clamp(0.0, 1.0) +
          throttle / 120 +
          engineLoad / 250;
      final sag = demand * 95;
      return (base - sag + _noise(3)).clamp(175.0, 320.0);
    }
    return base + _noise(4);
  }

  double _fuelTrim(double throttle, {required double rpm, required bool isShortTerm}) {
    if (fault == FaultProfile.weakFuelPump) {
      final loadFactor = ((rpm - 900) / 2800).clamp(0.0, 1.0) + throttle / 80;
      final magnitude = isShortTerm ? 20.0 : 16.0;
      return _noise(1.5) + loadFactor * magnitude;
    }
    if (fault != FaultProfile.vacuumLeak) return _noise(2);
    final leakSeverity = max(0.0, 1 - throttle / 30);
    final magnitude = isShortTerm ? 16.0 : 14.0;
    return _noise(1.5) + leakSeverity * magnitude;
  }

  double _upstreamO2(double t) {
    if (fault == FaultProfile.lazyO2Sensor) {
      // Slow, low-amplitude — effectively non-responsive vs. a healthy
      // ~0.8-1.2Hz switching sensor.
      return (0.45 + 0.03 * sin(2 * pi * t * 0.05)).clamp(0.0, 1.0);
    }
    return (0.5 + 0.35 * sin(2 * pi * t * 1.0) + _noise(0.02)).clamp(0.0, 1.0);
  }

  double _noise(double amplitude) => (_rand.nextDouble() - 0.5) * 2 * amplitude;

  /// Current value for [pidCode] (e.g. "0C"), or null if unknown.
  double? valueFor(String pidCode) => _values[pidCode.toUpperCase()];
}
