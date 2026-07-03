// Test IDs are snake_case strings shared with the Gemini agent — not Dart identifiers.
// ignore_for_file: constant_identifier_names

import '../obd/pid_constants.dart';

class TestDefinition {
  final String id;
  final String name;
  final String conditionDescription;
  final String conditionExpression;
  final int durationSeconds;
  final List<String> pids; // PID symbolic names (e.g. "rpm", "coolant_temp")
  final double sampleRateHz;
  final String purpose;

  const TestDefinition({
    required this.id,
    required this.name,
    required this.conditionDescription,
    required this.conditionExpression,
    required this.durationSeconds,
    required this.pids,
    required this.sampleRateHz,
    required this.purpose,
  });

  /// Resolve symbolic PID names to OBD hex codes.
  List<String> get pidCodes =>
      pids.map((n) => PidConstants.codeForName(n) ?? n).toList();
}

class TestLibrary {
  TestLibrary._();

  static const cold_start_monitor = TestDefinition(
    id: 'cold_start_monitor',
    name: 'Cold Start Monitor',
    conditionDescription: 'Engine cold — coolant temp below 35°C',
    conditionExpression: 'coolant_temp < 35',
    durationSeconds: 180,
    pids: ['coolant_temp', 'rpm', 'stft_b1', 'o2_b1s1', 'iat', 'engine_load'],
    sampleRateHz: 1.0,
    purpose:
        'Observe warm-up enrichment, O2 sensor light-off, thermostat behavior',
  );

  static const warm_idle_baseline = TestDefinition(
    id: 'warm_idle_baseline',
    name: 'Warm Idle Baseline',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 60,
    pids: [
      'rpm',
      'stft_b1',
      'ltft_b1',
      'o2_b1s1',
      'o2_b1s2',
      'map',
      'maf',
      'throttle',
      'engine_load'
    ],
    sampleRateHz: 1.0,
    purpose:
        'Core fuel trim reading at idle — vacuum leak detection, O2 switching rate',
  );

  static const fuel_trim_2000rpm = TestDefinition(
    id: 'fuel_trim_2000rpm',
    name: 'Fuel Trim at 2000 RPM',
    conditionDescription:
        'Engine warm (>85°C), RPM held between 1800–2200',
    conditionExpression:
        'coolant_temp > 85 && rpm > 1800 && rpm < 2200',
    durationSeconds: 45,
    pids: ['rpm', 'stft_b1', 'ltft_b1', 'maf', 'map', 'throttle'],
    sampleRateHz: 1.0,
    purpose:
        'Compare trims at idle vs 2000 RPM — vacuum leak shows at idle only',
  );

  static const fuel_trim_rpm_sweep = TestDefinition(
    id: 'fuel_trim_rpm_sweep',
    name: 'Fuel Trim RPM Sweep',
    conditionDescription:
        'Engine warm (>85°C), vehicle stationary, in neutral',
    conditionExpression: 'coolant_temp > 85',
    durationSeconds: 90,
    pids: ['rpm', 'stft_b1', 'ltft_b1', 'maf', 'map'],
    sampleRateHz: 1.0,
    purpose:
        'Full picture of how trims change with airflow (1000→3000 RPM sweep)',
  );

  static const o2_switching_analysis = TestDefinition(
    id: 'o2_switching_analysis',
    name: 'O2 Switching Analysis',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 30,
    pids: ['o2_b1s1', 'stft_b1', 'rpm'],
    sampleRateHz: 5.0,
    purpose:
        'Measure O2 sensor switching frequency — healthy ≈ 0.8–1.2 Hz',
  );

  static const cat_efficiency_test = TestDefinition(
    id: 'cat_efficiency_test',
    name: 'Catalytic Converter Efficiency',
    conditionDescription:
        'Engine warm (>85°C), RPM held between 2300–2700',
    conditionExpression:
        'coolant_temp > 85 && rpm > 2300 && rpm < 2700',
    durationSeconds: 45,
    pids: ['o2_b1s1', 'o2_b1s2', 'rpm', 'stft_b1'],
    sampleRateHz: 2.0,
    purpose:
        'Compare upstream vs downstream O2 — downstream should be stable if cat is working',
  );

  static const egr_response_test = TestDefinition(
    id: 'egr_response_test',
    name: 'EGR Response Test',
    conditionDescription:
        'Engine warm (>85°C), RPM held between 1800–2200',
    conditionExpression:
        'coolant_temp > 85 && rpm > 1800 && rpm < 2200',
    durationSeconds: 30,
    pids: ['rpm', 'map', 'egr_commanded', 'engine_load'],
    sampleRateHz: 1.0,
    purpose: 'Check EGR behavior and MAP response at cruise RPM',
  );

  static const misfire_idle_monitor = TestDefinition(
    id: 'misfire_idle_monitor',
    name: 'Misfire Idle Monitor',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 60,
    pids: [
      'rpm',
      'engine_load',
      'stft_b1',
      'ltft_b1',
      'map',
      'o2_b1s1'
    ],
    sampleRateHz: 2.0,
    purpose: 'Capture RPM instability events — near-stall events logged as notable events',
  );

  static const cold_start_temp_curve = TestDefinition(
    id: 'cold_start_temp_curve',
    name: 'Cold Start Temperature Curve',
    conditionDescription: 'Engine very cold — coolant temp below 30°C',
    conditionExpression: 'coolant_temp < 30',
    durationSeconds: 300,
    pids: ['coolant_temp', 'rpm', 'stft_b1'],
    sampleRateHz: 0.5,
    purpose:
        'Plot coolant temp rise — thermostat stuck open shows as plateau below 80°C',
  );

  // ─── New tests ───────────────────────────────────────────────────────────────

  static const fuel_pressure_idle = TestDefinition(
    id: 'fuel_pressure_idle',
    name: 'Fuel Pressure at Idle',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 60,
    pids: ['fuel_pressure', 'rpm', 'stft_b1', 'engine_load', 'map'],
    sampleRateHz: 1.0,
    purpose:
        'Monitor fuel pressure stability at warm idle. Healthy port injection holds 270–380 kPa. '
        'Drops >20 kPa indicate a weak fuel pump or failing pressure regulator. '
        'Steady low pressure points to a clogged fuel filter.',
  );

  static const fuel_pressure_load_test = TestDefinition(
    id: 'fuel_pressure_load_test',
    name: 'Fuel Pressure Under Load',
    conditionDescription:
        'Engine warm (>85°C), vehicle stationary, in neutral',
    conditionExpression: 'coolant_temp > 85',
    durationSeconds: 60,
    pids: [
      'fuel_pressure',
      'rpm',
      'stft_b1',
      'ltft_b1',
      'maf',
      'map',
      'engine_load',
    ],
    sampleRateHz: 2.0,
    purpose:
        'Two-phase test: idle ~20s then hold 2000–2500 RPM for the rest. '
        'Compares idle vs load fuel pressure and fuel trims. '
        'Pressure drop >20 kPa under load suggests weak pump or failing regulator. '
        'STFT/LTFT worsening >5% under load with stable MAF suggests fuel delivery cannot meet demand. '
        'Use when trims are lean at all RPMs or worse under acceleration/cruise.',
  );

  static const maf_map_correlation = TestDefinition(
    id: 'maf_map_correlation',
    name: 'MAF vs MAP Correlation',
    conditionDescription:
        'Engine warm (>85°C); step RPM from idle up to 2500 RPM in stages',
    conditionExpression: 'coolant_temp > 85',
    durationSeconds: 60,
    pids: ['maf', 'map', 'rpm', 'iat', 'engine_load', 'baro_pressure'],
    sampleRateHz: 1.0,
    purpose:
        'Cross-check MAF airflow against MAP across the RPM range. A dirty or failing MAF reads '
        'low g/s for a given MAP value. Large divergence between expected and actual MAF '
        'indicates MAF contamination, air metering fault, or intake restriction.',
  );

  static const throttle_snap_test = TestDefinition(
    id: 'throttle_snap_test',
    name: 'Throttle Snap (Transient Response)',
    conditionDescription:
        'Engine warm (>85°C) at idle — snap throttle to ~3000 RPM then release',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 30,
    pids: ['throttle', 'rpm', 'maf', 'stft_b1', 'map', 'engine_load'],
    sampleRateHz: 5.0,
    purpose:
        'Quick throttle blip captures MAF peak response, accelerator enrichment (momentary STFT dip), '
        'and return-to-idle rate. Lean spike on snap = weak injector or MAF lag. '
        'Slow RPM return = sticky IAC or idle air passage restriction.',
  );

  static const cruise_load_fuel_trim = TestDefinition(
    id: 'cruise_load_fuel_trim',
    name: 'Cruise Load Fuel Trim (Road Test)',
    conditionDescription:
        'Engine warm (>85°C), steady speed 60–80 km/h on flat road',
    conditionExpression:
        'coolant_temp > 85 && speed > 50 && speed < 100',
    durationSeconds: 60,
    pids: [
      'speed',
      'rpm',
      'stft_b1',
      'ltft_b1',
      'maf',
      'throttle',
      'engine_load',
      'map'
    ],
    sampleRateHz: 1.0,
    purpose:
        'Observe fuel trims under steady cruise load. Trims worse under load than at idle '
        'indicate MAF under-reading, low fuel pressure, or injector capacity issues rather '
        'than a vacuum leak (which usually normalises off-idle).',
  );

  static const decel_fuel_cutoff = TestDefinition(
    id: 'decel_fuel_cutoff',
    name: 'Deceleration Fuel Cut-Off (DFCO)',
    conditionDescription:
        'Engine warm (>85°C), driving at 60+ km/h — then fully release throttle',
    conditionExpression:
        'coolant_temp > 85 && speed > 50 && throttle < 2',
    durationSeconds: 20,
    pids: ['throttle', 'rpm', 'speed', 'stft_b1', 'map', 'engine_load'],
    sampleRateHz: 2.0,
    purpose:
        'During deceleration fuel cut-off, ECU stops fueling — STFT/fuel system should '
        'indicate open-loop or strongly negative correction. Absence of DFCO or STFT staying '
        'positive during decel suggests injector leak-down, large vacuum leak, or ECU issue.',
  );

  static const bank_fuel_trim_comparison = TestDefinition(
    id: 'bank_fuel_trim_comparison',
    name: 'Bank 1 vs Bank 2 Fuel Trim Comparison',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 60,
    pids: ['stft_b1', 'ltft_b1', 'stft_b2', 'ltft_b2', 'rpm', 'engine_load'],
    sampleRateHz: 1.0,
    purpose:
        'Compare Bank 1 vs Bank 2 fuel trims at warm idle. Divergence >5% between banks '
        'indicates a bank-specific fault: injector imbalance, lazy O2 sensor on one bank, '
        'or an intake manifold vacuum leak isolated to that bank. Critical test for V6/V8 engines '
        'with P0171/P0174 (both banks lean) or P0172/P0175 (both banks rich).',
  );

  static const map_baro_sanity = TestDefinition(
    id: 'map_baro_sanity',
    name: 'MAP vs Barometric Pressure Sanity Check',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 30,
    pids: ['map', 'baro_pressure', 'rpm', 'throttle', 'engine_load'],
    sampleRateHz: 1.0,
    purpose:
        'At warm idle, MAP should be 25–45 kPa below barometric pressure (engine vacuum). '
        'MAP close to BARO at idle = major vacuum leak, throttle plate not closing, or '
        'failed MAP sensor. Establishes the intake vacuum reference for interpreting other tests.',
  );

  static const oil_temp_warmup_correlation = TestDefinition(
    id: 'oil_temp_warmup_correlation',
    name: 'Oil Temp vs Coolant Warmup Correlation',
    conditionDescription: 'Engine partially warm — coolant temp above 60°C',
    conditionExpression: 'coolant_temp > 60',
    durationSeconds: 120,
    pids: ['oil_temp', 'coolant_temp', 'rpm', 'engine_load'],
    sampleRateHz: 0.5,
    purpose:
        'After warm-up, oil temperature should stabilise at 95–110°C, lagging coolant by '
        '5–10 minutes. Oil persistently below 85°C after full warm-up = failed oil thermostat. '
        'Coolant and oil diverging sharply after warm-up = possible oil cooler fault or '
        'early signs of head gasket compromise.',
  );

  static const extended_idle_stability = TestDefinition(
    id: 'extended_idle_stability',
    name: 'Extended Idle Stability Monitor',
    conditionDescription: 'Engine warm (>85°C), idling below 1000 RPM',
    conditionExpression: 'coolant_temp > 85 && rpm < 1000',
    durationSeconds: 300,
    pids: [
      'rpm',
      'stft_b1',
      'ltft_b1',
      'o2_b1s1',
      'map',
      'engine_load',
      'coolant_temp'
    ],
    sampleRateHz: 1.0,
    purpose:
        'Five-minute extended idle to catch intermittent events invisible in shorter tests. '
        'Targets hunting idle, lean spikes, periodic rich episodes, and slow LTFT drift. '
        'Run when warm_idle_baseline and misfire_idle_monitor are inconclusive.',
  );

  static const List<TestDefinition> all = [
    cold_start_monitor,
    warm_idle_baseline,
    fuel_trim_2000rpm,
    fuel_trim_rpm_sweep,
    o2_switching_analysis,
    cat_efficiency_test,
    egr_response_test,
    misfire_idle_monitor,
    cold_start_temp_curve,
    fuel_pressure_idle,
    fuel_pressure_load_test,
    maf_map_correlation,
    throttle_snap_test,
    cruise_load_fuel_trim,
    decel_fuel_cutoff,
    bank_fuel_trim_comparison,
    map_baro_sanity,
    oil_temp_warmup_correlation,
    extended_idle_stability,
  ];

  static TestDefinition? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
