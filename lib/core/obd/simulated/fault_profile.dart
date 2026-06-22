/// A named fault scenario the virtual ECU can simulate.
///
/// Each profile drives the same sensor-computation formulas in [VirtualEcu]
/// down a different path (e.g. elevated fuel trims at idle only) so the
/// resulting [SensorSummary] data matches a real-world pattern documented in
/// `system_prompt.dart` — letting you verify Gemini reaches the same
/// diagnosis a real test session would produce.
enum FaultProfile {
  healthy,
  vacuumLeak,
  lazyO2Sensor,
  thermostatStuckOpen,
}

extension FaultProfileInfo on FaultProfile {
  String get label {
    switch (this) {
      case FaultProfile.healthy:
        return 'Healthy Baseline';
      case FaultProfile.vacuumLeak:
        return 'Vacuum Leak (P0171)';
      case FaultProfile.lazyO2Sensor:
        return 'Lazy O2 Sensor (P0133)';
      case FaultProfile.thermostatStuckOpen:
        return 'Thermostat Stuck Open (P0128)';
    }
  }

  String get description {
    switch (this) {
      case FaultProfile.healthy:
        return 'No faults. Fuel trims near 0%, normal O2 switching, normal warm-up.';
      case FaultProfile.vacuumLeak:
        return 'STFT/LTFT high (~+16%) at idle, normalising as RPM/throttle rise. '
            'Expected diagnosis: intake vacuum leak.';
      case FaultProfile.lazyO2Sensor:
        return 'Upstream O2 sensor switches very slowly instead of ~1 Hz. '
            'Expected diagnosis: contaminated/lazy upstream O2 sensor.';
      case FaultProfile.thermostatStuckOpen:
        return 'Coolant temp plateaus around 75°C and never reaches normal '
            'operating temperature. Expected diagnosis: thermostat stuck open.';
    }
  }

  /// DTC(s) present in this scenario, or empty for the healthy baseline.
  List<String> get dtcCodes {
    switch (this) {
      case FaultProfile.healthy:
        return const [];
      case FaultProfile.vacuumLeak:
        return const ['P0171'];
      case FaultProfile.lazyO2Sensor:
        return const ['P0133'];
      case FaultProfile.thermostatStuckOpen:
        return const ['P0128'];
    }
  }
}
