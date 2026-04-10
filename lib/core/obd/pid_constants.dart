/// SAE J1979 PID codes used in this app.
class PidConstants {
  PidConstants._();

  static const String rpm = '0C';
  static const String speed = '0D';
  static const String coolantTemp = '05';
  static const String intakeAirTemp = '0F';
  static const String engineLoad = '04';
  static const String throttlePos = '11';
  static const String fuelLevel = '2F';
  static const String stftB1 = '06';
  static const String ltftB1 = '07';
  static const String stftB2 = '08';
  static const String ltftB2 = '09';
  static const String map = '0B';
  static const String fuelPressure = '0A';
  static const String maf = '10';
  static const String o2B1S1 = '14';
  static const String o2B1S2 = '15';
  static const String engineRunTime = '1F';
  static const String distanceMilOn = '21';
  static const String egrCommanded = '2C';
  static const String baroPressure = '33';
  static const String oilTemp = '5C';

  /// Human-readable names for each PID.
  static const Map<String, String> names = {
    rpm: 'RPM',
    speed: 'Speed',
    coolantTemp: 'Coolant Temp',
    intakeAirTemp: 'Intake Air Temp',
    engineLoad: 'Engine Load',
    throttlePos: 'Throttle Position',
    fuelLevel: 'Fuel Level',
    stftB1: 'Short-Term Fuel Trim B1',
    ltftB1: 'Long-Term Fuel Trim B1',
    stftB2: 'Short-Term Fuel Trim B2',
    ltftB2: 'Long-Term Fuel Trim B2',
    map: 'Intake Manifold Pressure',
    fuelPressure: 'Fuel Pressure',
    maf: 'MAF',
    o2B1S1: 'O2 Sensor B1S1',
    o2B1S2: 'O2 Sensor B1S2',
    engineRunTime: 'Engine Run Time',
    distanceMilOn: 'Distance with MIL On',
    egrCommanded: 'EGR Commanded',
    baroPressure: 'Barometric Pressure',
    oilTemp: 'Oil Temp',
  };

  /// Units for each PID.
  static const Map<String, String> units = {
    rpm: 'RPM',
    speed: 'km/h',
    coolantTemp: '°C',
    intakeAirTemp: '°C',
    engineLoad: '%',
    throttlePos: '%',
    fuelLevel: '%',
    stftB1: '%',
    ltftB1: '%',
    stftB2: '%',
    ltftB2: '%',
    map: 'kPa',
    fuelPressure: 'kPa',
    maf: 'g/s',
    o2B1S1: 'V',
    o2B1S2: 'V',
    engineRunTime: 's',
    distanceMilOn: 'km',
    egrCommanded: '%',
    baroPressure: 'kPa',
    oilTemp: '°C',
  };

  /// Map from symbolic name (used in test conditions) to PID code.
  static const Map<String, String> nameToCode = {
    'rpm': rpm,
    'speed': speed,
    'coolant_temp': coolantTemp,
    'iat': intakeAirTemp,
    'engine_load': engineLoad,
    'throttle': throttlePos,
    'fuel_level': fuelLevel,
    'stft_b1': stftB1,
    'ltft_b1': ltftB1,
    'stft_b2': stftB2,
    'ltft_b2': ltftB2,
    'map': map,
    'fuel_pressure': fuelPressure,
    'maf': maf,
    'o2_b1s1': o2B1S1,
    'o2_b1s2': o2B1S2,
    'engine_run_time': engineRunTime,
    'distance_mil_on': distanceMilOn,
    'egr_commanded': egrCommanded,
    'baro_pressure': baroPressure,
    'oil_temp': oilTemp,
  };

  static String? codeForName(String name) => nameToCode[name];
  static String nameFor(String code) => names[code] ?? code;
  static String unitFor(String code) => units[code] ?? '';
}
