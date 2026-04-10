import 'pid_constants.dart';

/// Decodes raw OBD-II PID hex response bytes into engineering values.
class PidDecoder {
  PidDecoder._();

  /// Decode a raw OBD response string for the given PID.
  ///
  /// [pid] is the two-character hex PID (e.g. "0C").
  /// [response] is the raw ELM327 response string (e.g. "41 0C 1A F0").
  /// Returns the decoded value or null if parsing fails.
  static double? decode(String pid, String response) {
    try {
      final bytes = _parseResponseBytes(pid, response);
      if (bytes == null) return null;
      return _apply(pid.toUpperCase(), bytes);
    } catch (_) {
      return null;
    }
  }

  /// Parse the data bytes from an ELM327 response.
  /// Strips the mode+PID echo bytes and returns only the data bytes.
  static List<int>? _parseResponseBytes(String pid, String response) {
    // Remove whitespace and newlines
    final clean = response.replaceAll(RegExp(r'[\s\r\n>]'), '').toUpperCase();

    // Find the response header: "41" + pid (mode 01 response = mode+0x40)
    final pidUpper = pid.toUpperCase();
    final header = '41$pidUpper';
    final idx = clean.indexOf(header);
    if (idx == -1) return null;

    final dataHex = clean.substring(idx + header.length);
    if (dataHex.length < 2) return null;

    final bytes = <int>[];
    for (var i = 0; i + 1 < dataHex.length; i += 2) {
      bytes.add(int.parse(dataHex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static double? _apply(String pid, List<int> b) {
    if (b.isEmpty) return null;
    final a = b[0];
    final bv = b.length > 1 ? b[1] : 0;

    switch (pid) {
      case PidConstants.rpm:            // ((A*256)+B)/4
        return ((a * 256) + bv) / 4.0;
      case PidConstants.speed:          // A
        return a.toDouble();
      case PidConstants.coolantTemp:    // A-40
        return (a - 40).toDouble();
      case PidConstants.intakeAirTemp:  // A-40
        return (a - 40).toDouble();
      case PidConstants.engineLoad:     // A*100/255
        return a * 100.0 / 255.0;
      case PidConstants.throttlePos:    // A*100/255
        return a * 100.0 / 255.0;
      case PidConstants.fuelLevel:      // A*100/255
        return a * 100.0 / 255.0;
      case PidConstants.stftB1:         // (A-128)*100/128
        return (a - 128) * 100.0 / 128.0;
      case PidConstants.ltftB1:         // (A-128)*100/128
        return (a - 128) * 100.0 / 128.0;
      case PidConstants.stftB2:         // (A-128)*100/128
        return (a - 128) * 100.0 / 128.0;
      case PidConstants.ltftB2:         // (A-128)*100/128
        return (a - 128) * 100.0 / 128.0;
      case PidConstants.map:            // A
        return a.toDouble();
      case PidConstants.fuelPressure:   // A*3
        return (a * 3).toDouble();
      case PidConstants.maf:            // ((A*256)+B)/100
        return ((a * 256) + bv) / 100.0;
      case PidConstants.o2B1S1:         // A/200
        return a / 200.0;
      case PidConstants.o2B1S2:         // A/200
        return a / 200.0;
      case PidConstants.engineRunTime:  // (A*256)+B
        return ((a * 256) + bv).toDouble();
      case PidConstants.distanceMilOn:  // (A*256)+B
        return ((a * 256) + bv).toDouble();
      case PidConstants.egrCommanded:   // A*100/255
        return a * 100.0 / 255.0;
      case PidConstants.baroPressure:   // A
        return a.toDouble();
      case PidConstants.oilTemp:        // A-40
        return (a - 40).toDouble();
      default:
        return null;
    }
  }
}
