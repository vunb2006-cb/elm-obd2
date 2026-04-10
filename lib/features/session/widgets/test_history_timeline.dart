import 'package:flutter/material.dart';
import '../../../core/diagnosis/models/sensor_summary.dart';
import '../../../shared/theme.dart';

class TestHistoryTimeline extends StatelessWidget {
  final List<SensorSummary> completedTests;

  const TestHistoryTimeline({super.key, required this.completedTests});

  @override
  Widget build(BuildContext context) {
    if (completedTests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Completed Tests',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted, letterSpacing: 0.8),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: completedTests.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final s = completedTests[i];
              return _TestChip(summary: s, index: i + 1);
            },
          ),
        ),
      ],
    );
  }
}

class _TestChip extends StatelessWidget {
  final SensorSummary summary;
  final int index;

  const _TestChip({required this.summary, required this.index});

  @override
  Widget build(BuildContext context) {
    final hasEvents = summary.notableEvents.isNotEmpty;
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasEvents
              ? AppTheme.accent.withAlpha(80)
              : const Color(0xFF2A2A30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  summary.testId.replaceAll('_', ' '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                hasEvents ? Icons.flag : Icons.check,
                size: 12,
                color: hasEvents ? AppTheme.accent : AppTheme.accentGreen,
              ),
              const SizedBox(width: 4),
              Text(
                hasEvents
                    ? '${summary.notableEvents.length} event(s)'
                    : '${summary.durationSeconds}s clean',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
