import 'models/dtc_code.dart';

/// Decodes raw OBD-II mode 03 (stored) and mode 07 (pending) DTC responses.
class DtcDecoder {
  DtcDecoder._();

  /// Parse a mode 03 or mode 07 response into a list of DTC codes.
  ///
  /// [response] is the raw ELM327 multi-line response string.
  /// [isPending] should be true for mode 07 responses.
  static List<DtcCode> decode(String response, {bool isPending = false}) {
    final dtcs = <DtcCode>[];

    // Clean up response: remove ELM prompt, extra whitespace
    final lines = response
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.replaceAll(RegExp(r'[\s>]'), '').toUpperCase())
        .where((l) => l.isNotEmpty && l != 'NODATA' && l != 'SEARCHING')
        .toList();

    for (final line in lines) {
      // Mode 03 response header is "43", mode 07 is "47"
      final headerByte = isPending ? '47' : '43';
      String data = line;
      if (data.startsWith(headerByte)) {
        data = data.substring(2);
      }

      // Each DTC is 2 bytes (4 hex chars)
      for (var i = 0; i + 3 < data.length; i += 4) {
        final hexPair = data.substring(i, i + 4);
        if (hexPair == '0000') continue;

        final code = _hexToDtcCode(hexPair);
        if (code != null) {
          dtcs.add(DtcCode(
            code: code,
            rawHex: hexPair,
            description: _knownDescriptions[code],
            isPending: isPending,
          ));
        }
      }
    }

    return dtcs;
  }

  static String? _hexToDtcCode(String hex) {
    if (hex.length != 4) return null;

    final byte1 = int.tryParse(hex.substring(0, 2), radix: 16);
    final byte2 = int.tryParse(hex.substring(2, 4), radix: 16);
    if (byte1 == null || byte2 == null) return null;

    // First two bits of byte1 determine system
    final systemBits = (byte1 & 0xC0) >> 6;
    final system = const ['P', 'C', 'B', 'U'][systemBits];

    // Next two bits are the first digit
    final firstDigit = (byte1 & 0x30) >> 4;
    final secondDigit = byte1 & 0x0F;
    final thirdDigit = (byte2 & 0xF0) >> 4;
    final fourthDigit = byte2 & 0x0F;

    return '$system$firstDigit${secondDigit.toRadixString(16).toUpperCase()}'
        '${thirdDigit.toRadixString(16).toUpperCase()}'
        '${fourthDigit.toRadixString(16).toUpperCase()}';
  }

  /// Common DTC descriptions for quick reference in the UI.
  static const Map<String, String> _knownDescriptions = {
    'P0100': 'Mass Air Flow Sensor Circuit Malfunction',
    'P0101': 'Mass Air Flow Sensor Range/Performance',
    'P0102': 'Mass Air Flow Sensor Circuit Low Input',
    'P0103': 'Mass Air Flow Sensor Circuit High Input',
    'P0110': 'Intake Air Temperature Sensor Circuit',
    'P0115': 'Engine Coolant Temperature Sensor Circuit',
    'P0116': 'Engine Coolant Temperature Range/Performance',
    'P0117': 'Engine Coolant Temperature Sensor Low Input',
    'P0118': 'Engine Coolant Temperature Sensor High Input',
    'P0130': 'O2 Sensor Circuit (Bank 1, Sensor 1)',
    'P0131': 'O2 Sensor Circuit Low Voltage (Bank 1, Sensor 1)',
    'P0132': 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 1)',
    'P0133': 'O2 Sensor Circuit Slow Response (Bank 1, Sensor 1)',
    'P0134': 'O2 Sensor Circuit No Activity (Bank 1, Sensor 1)',
    'P0136': 'O2 Sensor Circuit (Bank 1, Sensor 2)',
    'P0138': 'O2 Sensor Circuit High Voltage (Bank 1, Sensor 2)',
    'P0171': 'System Too Lean (Bank 1)',
    'P0172': 'System Too Rich (Bank 1)',
    'P0174': 'System Too Lean (Bank 2)',
    'P0175': 'System Too Rich (Bank 2)',
    'P0300': 'Random/Multiple Cylinder Misfire Detected',
    'P0301': 'Cylinder 1 Misfire Detected',
    'P0302': 'Cylinder 2 Misfire Detected',
    'P0303': 'Cylinder 3 Misfire Detected',
    'P0304': 'Cylinder 4 Misfire Detected',
    'P0400': 'Exhaust Gas Recirculation Flow Malfunction',
    'P0401': 'EGR Flow Insufficient',
    'P0402': 'EGR Flow Excessive',
    'P0420': 'Catalyst System Efficiency Below Threshold (Bank 1)',
    'P0421': 'Warm Up Catalyst Efficiency Below Threshold (Bank 1)',
    'P0430': 'Catalyst System Efficiency Below Threshold (Bank 2)',
    'P0440': 'Evaporative Emission Control System Malfunction',
    'P0441': 'Evaporative Emission Control System Incorrect Purge Flow',
    'P0442': 'Evaporative Emission Control System Leak Detected (small)',
    'P0455': 'Evaporative Emission Control System Leak Detected (large)',
    'P0500': 'Vehicle Speed Sensor Malfunction',
    'P0505': 'Idle Air Control System Malfunction',
    'P0600': 'Serial Communication Link Malfunction',
  };
}
