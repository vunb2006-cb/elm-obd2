import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/diagnosis/condition_evaluator.dart';
import '../../../core/diagnosis/models/prescribed_test.dart';
import '../../../core/diagnosis/test_library.dart';
import '../../../features/connect/connect_provider.dart';
import '../../../shared/theme.dart';

class TestInstructionCard extends ConsumerStatefulWidget {
  final PrescribedTest test;
  final VoidCallback onStartTest;

  const TestInstructionCard({
    super.key,
    required this.test,
    required this.onStartTest,
  });

  @override
  ConsumerState<TestInstructionCard> createState() =>
      _TestInstructionCardState();
}

class _TestInstructionCardState extends ConsumerState<TestInstructionCard> {
  ConditionEvaluator? _evaluator;
  ConditionStatus? _conditionStatus;
  bool _rationaleExpanded = false;

  @override
  void initState() {
    super.initState();
    _startConditionCheck();
  }

  void _startConditionCheck() {
    final def = TestLibrary.byId(widget.test.testId);
    if (def == null) return;

    _evaluator = ConditionEvaluator(ref.read(obdServiceProvider));
    _evaluator!
        .evaluate(def.conditionExpression)
        .listen((status) {
      if (mounted) setState(() => _conditionStatus = status);
    });
  }

  @override
  void dispose() {
    _evaluator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = TestLibrary.byId(widget.test.testId);
    final condMet = _conditionStatus?.isMet ?? false;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test name + urgency badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    def?.name ?? widget.test.testId,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _UrgencyBadge(urgency: widget.test.urgency),
              ],
            ),
            const SizedBox(height: 16),

            // Instruction
            Text(
              widget.test.instruction,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),

            // Condition status
            if (_conditionStatus != null)
              _ConditionIndicator(status: _conditionStatus!, def: def)
            else
              const _ConditionLoading(),

            const SizedBox(height: 20),

            // Start button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: condMet ? widget.onStartTest : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(condMet
                    ? 'Start Test'
                    : 'Waiting for condition...'),
              ),
            ),
            const SizedBox(height: 12),

            // Rationale (collapsible)
            InkWell(
              onTap: () =>
                  setState(() => _rationaleExpanded = !_rationaleExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.psychology,
                        size: 16, color: AppTheme.muted),
                    const SizedBox(width: 6),
                    Text('Why this test?',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.accent)),
                    const Spacer(),
                    Icon(
                      _rationaleExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (_rationaleExpanded) ...[
              const SizedBox(height: 8),
              Text(
                widget.test.rationale,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.muted, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConditionIndicator extends StatelessWidget {
  final ConditionStatus status;
  final TestDefinition? def;

  const _ConditionIndicator({required this.status, this.def});

  @override
  Widget build(BuildContext context) {
    final color = status.isMet ? AppTheme.accentGreen : AppTheme.accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.isMet ? Icons.check_circle : Icons.hourglass_top,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                status.isMet ? 'Condition met' : 'Waiting for condition',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (status.currentValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: status.currentValues.entries.map((e) {
                final target = status.targetDescriptions[e.key] ?? '';
                return Text(
                  '${e.key}: ${e.value.toStringAsFixed(1)} ($target)',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConditionLoading extends StatelessWidget {
  const _ConditionLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('Checking condition...',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  const _UrgencyBadge({required this.urgency});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (urgency) {
      'first' => ('First Test', AppTheme.accentGreen),
      'confirmatory' => ('Confirmatory', AppTheme.accent),
      _ => ('Follow-up', AppTheme.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
