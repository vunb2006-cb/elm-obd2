import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// The saved Gemini API key, or null if none has been set yet.
///
/// Invalidate this after [SettingsRepository.setApiKey]/[clearApiKey] so
/// anything reading it (e.g. `GeminiAgent.initialize`) sees the new value.
final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  await repo.init();
  return repo.getApiKey();
});
