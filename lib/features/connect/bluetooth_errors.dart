/// User-facing messages for Bluetooth / OBD connection failures.
/// Avoids dumping raw [Exception] / [StackTrace] into the UI.
String formatBluetoothAccessError(Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('permission') ||
      s.contains('denied') ||
      s.contains('security')) {
    return 'Bluetooth or location permission is required to list paired '
        'devices. Grant permissions in Settings, then tap Refresh.';
  }
  if (s.contains('bluetooth') && s.contains('off')) {
    return 'Bluetooth is turned off. Enable Bluetooth and try again.';
  }
  return 'Could not read paired Bluetooth devices. '
      'Check that Bluetooth is on and permissions are granted.';
}

String formatElmConnectionError(Object error) {
  final s = error.toString().toLowerCase();
  if (s.contains('timeout') || s.contains('timed out')) {
    return 'Connection timed out. Move closer to the adapter, ensure '
        'the car\'s ignition is on if needed, and try again.';
  }
  if (s.contains('refused') ||
      s.contains('unable to connect') ||
      s.contains('socket')) {
    return 'Could not open a serial link to the adapter. Unpair and pair '
        'the device again in system Bluetooth settings, then retry.';
  }
  if (s.contains('permission')) {
    return 'Bluetooth permission was denied. Grant it in Settings and retry.';
  }
  return 'Could not connect to the adapter. Make sure it is paired, '
        'not connected by another app, and try again.';
}
