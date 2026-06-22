import 'package:hive_flutter/hive_flutter.dart';

/// Persists app-level settings to Hive.
///
/// Currently this is just the Gemini API key — entered in-app via the
/// Settings screen instead of read from a bundled `.env` file, so the key
/// never ships inside the app's asset bundle.
class SettingsRepository {
  static const _boxName = 'settings';
  static const _apiKeyField = 'geminiApiKey';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  String? getApiKey() {
    final value = _box.get(_apiKeyField)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  Future<void> setApiKey(String key) => _box.put(_apiKeyField, key.trim());

  Future<void> clearApiKey() => _box.delete(_apiKeyField);
}
