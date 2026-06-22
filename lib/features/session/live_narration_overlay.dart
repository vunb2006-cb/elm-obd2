import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnosis/gemini_live_service.dart';
import '../../shared/theme.dart';
import '../settings/settings_provider.dart';

final _liveServiceProvider = Provider<GeminiLiveService>((ref) {
  final s = GeminiLiveService();
  ref.onDispose(s.dispose);
  return s;
});

class LiveNarrationOverlay extends ConsumerStatefulWidget {
  final String context;
  final Map<String, double> liveValues;
  final int elapsed;

  const LiveNarrationOverlay({
    super.key,
    required this.context,
    required this.liveValues,
    required this.elapsed,
  });

  @override
  ConsumerState<LiveNarrationOverlay> createState() =>
      _LiveNarrationOverlayState();
}

class _LiveNarrationOverlayState
    extends ConsumerState<LiveNarrationOverlay> {
  final List<String> _narrationLines = [];
  StreamSubscription? _textSub;
  Timer? _updateTimer;
  int _lastElapsed = -1;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final service = ref.read(_liveServiceProvider);
    final apiKey = await ref.read(geminiApiKeyProvider.future);
    if (!mounted || apiKey == null) return;
    await service.start(widget.context, apiKey);
    _textSub = service.narrationStream.listen((text) {
      if (mounted) {
        setState(() {
          _narrationLines.add(text);
          if (_narrationLines.length > 10) _narrationLines.removeAt(0);
        });
      }
    });

    // Send updates every 2 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (widget.elapsed != _lastElapsed) {
        _lastElapsed = widget.elapsed;
        service.sendSensorUpdate(
          elapsed: widget.elapsed,
          values: widget.liveValues,
        );
      }
    });
  }

  @override
  void dispose() {
    _textSub?.cancel();
    _updateTimer?.cancel();
    ref.read(_liveServiceProvider).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _PulsingDot(),
              const SizedBox(width: 8),
              Text(
                'Live narration',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (_narrationLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final line in _narrationLines.reversed.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        height: 1.4,
                      ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Listening to sensor data...',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: _anim.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
