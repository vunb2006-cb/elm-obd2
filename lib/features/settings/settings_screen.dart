import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await ref.read(geminiApiKeyProvider.future);
    if (mounted) {
      setState(() {
        if (key != null) _controller.text = key;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      await _clear();
      return;
    }
    await ref.read(settingsRepositoryProvider).setApiKey(key);
    ref.invalidate(geminiApiKeyProvider);
    if (!mounted) return;
    setState(() => _saved = true);
  }

  Future<void> _clear() async {
    await ref.read(settingsRepositoryProvider).clearApiKey();
    ref.invalidate(geminiApiKeyProvider);
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('Gemini API Key', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  'Stored on-device only — used to run the diagnostic agent and '
                  'Gemini Live narration. Get a key at aistudio.google.com.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  obscureText: _obscure,
                  onChanged: (_) => setState(() => _saved = false),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'AIza...',
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _controller.text.isEmpty ? null : _clear,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentRed),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                if (_saved) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.accentGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Saved',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.accentGreen),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
