import 'package:flutter/material.dart';
import '../../../shared/theme.dart';

class AgentThinkingIndicator extends StatefulWidget {
  final String message;
  const AgentThinkingIndicator({super.key, required this.message});

  @override
  State<AgentThinkingIndicator> createState() =>
      _AgentThinkingIndicatorState();
}

class _AgentThinkingIndicatorState extends State<AgentThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Opacity(
                opacity: _pulse.value,
                child: const Icon(
                  Icons.psychology,
                  size: 64,
                  color: AppTheme.accent,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'AI Thinking',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
