import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Manages a Gemini Live WebSocket session for real-time voice narration
/// during an active test collection phase.
///
/// Protocol:
/// 1. Open WebSocket to Gemini Live endpoint
/// 2. Send a setup message with model config + system instruction
/// 3. Every [updateIntervalSeconds], send a text message with live PID values
/// 4. Receive audio stream; expose it for playback
/// 5. Close on test completion
class GeminiLiveService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _active = false;
  String? _systemInstruction;

  final _narrationController =
      StreamController<String>.broadcast();
  final _audioController =
      StreamController<List<int>>.broadcast();

  /// Text narration segments received from Gemini Live.
  Stream<String> get narrationStream => _narrationController.stream;

  /// Raw audio bytes received from Gemini Live (PCM/opus).
  Stream<List<int>> get audioStream => _audioController.stream;

  bool get isActive => _active;

  /// Start a live narration session.
  ///
  /// [context] becomes the system instruction guiding what Gemini Live
  /// should watch for and say.
  Future<void> start(String context) async {
    if (_active) await stop();

    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'your_key_here') return;

    _systemInstruction = context;

    // Gemini Live API WebSocket endpoint
    final uri = Uri.parse(
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent'
      '?key=$apiKey',
    );

    try {
      _channel = WebSocketChannel.connect(uri);
      _active = true;

      // Send setup message
      _sendSetup();

      // Listen to incoming messages
      _sub = _channel!.stream.listen(
        _onMessage,
        onError: (e) => _narrationController
            .add('[Live narration error: $e]'),
        onDone: () => _active = false,
      );
    } catch (e) {
      _active = false;
      _narrationController.add('[Could not connect to Gemini Live: $e]');
    }
  }

  /// Send a live sensor update to Gemini Live.
  void sendSensorUpdate({
    required int elapsed,
    required Map<String, double> values,
  }) {
    if (!_active || _channel == null) return;

    final parts = values.entries
        .map((e) =>
            '${e.key.toUpperCase()}:${e.value.toStringAsFixed(1)}')
        .join(' ');
    final text = '[${elapsed}s] $parts';

    final message = jsonEncode({
      'client_content': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text}
            ],
          }
        ],
        'turn_complete': false,
      }
    });
    _channel!.sink.add(message);
  }

  void _sendSetup() {
    final setup = jsonEncode({
      'setup': {
        'model':
            'models/gemini-2.0-flash-live-001',
        'generation_config': {
          'response_modalities': ['AUDIO', 'TEXT'],
          'speech_config': {
            'voice_config': {
              'prebuilt_voice_config': {'voice_name': 'Aoede'}
            }
          },
        },
        'system_instruction': {
          'parts': [
            {'text': _systemInstruction ?? ''}
          ]
        },
      }
    });
    _channel!.sink.add(setup);
  }

  void _onMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String) as Map<String, dynamic>;

      // Text narration
      final serverContent =
          decoded['serverContent'] as Map<String, dynamic>?;
      final modelTurn =
          serverContent?['modelTurn'] as Map<String, dynamic>?;
      final parts = modelTurn?['parts'] as List?;

      if (parts != null) {
        for (final part in parts) {
          final text = part['text'] as String?;
          if (text != null && text.isNotEmpty) {
            _narrationController.add(text);
          }

          // Audio bytes (inlineData)
          final inlineData =
              part['inlineData'] as Map<String, dynamic>?;
          if (inlineData != null) {
            final b64 = inlineData['data'] as String?;
            if (b64 != null) {
              _audioController.add(base64Decode(b64));
            }
          }
        }
      }
    } catch (_) {
      // Ignore parse errors from non-JSON messages
    }
  }

  Future<void> stop() async {
    _active = false;
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    stop();
    _narrationController.close();
    _audioController.close();
  }
}
