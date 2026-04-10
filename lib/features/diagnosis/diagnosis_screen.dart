import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnosis/models/diagnosis_result.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/severity_badge.dart';
import '../session/session_provider.dart';
import '../report/report_generator.dart';

class DiagnosisScreen extends ConsumerWidget {
  final String sessionId;
  const DiagnosisScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final result = session.finalDiagnosis;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnosis')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis Report'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            ref.read(sessionProvider.notifier).reset();
            context.go('/');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context, ref, result),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PrimaryFaultCard(result: result),
          const SizedBox(height: 16),
          _EvidenceCard(result: result),
          const SizedBox(height: 16),
          _RecommendationCard(result: result),
          if (result.symptomsMayNotice.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SymptomsCard(result: result),
          ],
          const SizedBox(height: 16),
          _HonestyCard(result: result),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(sessionProvider.notifier).reset();
              context.go('/connect');
            },
            icon: const Icon(Icons.add),
            label: const Text('Start New Diagnostic Session'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _exportPdf(
      BuildContext context, WidgetRef ref, DiagnosisResult result) async {
    final session = ref.read(sessionProvider);
    await ReportGenerator.generate(
      context: context,
      result: result,
      completedTests: session.completedTests,
    );
  }
}

class _PrimaryFaultCard extends StatelessWidget {
  final DiagnosisResult result;
  const _PrimaryFaultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.primaryFault,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SeverityBadge(
                        severity:
                            SeverityBadge.fromString(result.severity)),
                    const SizedBox(height: 6),
                    _ConfidenceBadge(confidence: result.confidence),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'high' => AppTheme.accentGreen,
      'medium' => AppTheme.accent,
      _ => AppTheme.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        '${confidence.toUpperCase()} CONFIDENCE',
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final DiagnosisResult result;
  const _EvidenceCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text('Supporting Evidence',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final e in result.evidence)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle,
                          size: 6, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final DiagnosisResult result;
  const _RecommendationCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text('Recommended Action',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Text(result.recommendedAction,
                style:
                    Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
            if (result.furtherPhysicalTests != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.engineering,
                      color: AppTheme.muted, size: 16),
                  const SizedBox(width: 8),
                  Text('For your mechanic:',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.muted)),
                ],
              ),
              const SizedBox(height: 6),
              Text(result.furtherPhysicalTests!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.muted, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  final DiagnosisResult result;
  const _SymptomsCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber,
                    color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Text('Symptoms You May Notice',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in result.symptomsMayNotice)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child:
                          Icon(Icons.circle, size: 6, color: AppTheme.muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s,
                            style:
                                Theme.of(context).textTheme.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HonestyCard extends StatelessWidget {
  final DiagnosisResult result;
  const _HonestyCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppTheme.muted, size: 18),
                const SizedBox(width: 8),
                Text('OBD2 Limitations',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.muted)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              result.whatObdCannotTell,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppTheme.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
