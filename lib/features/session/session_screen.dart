import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnosis/test_library.dart';
import '../../shared/theme.dart';
import '../connect/connect_provider.dart';
import '../connect/simulator_control_panel.dart';
import 'session_provider.dart';
import 'widgets/agent_thinking_indicator.dart';
import 'widgets/live_sensor_dashboard.dart';
import 'widgets/test_history_timeline.dart';
import 'widgets/test_instruction_card.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Skip auto-start if a resume is already in flight: resumeFromCheckpoint
      // advances the phase past `idle` synchronously before this screen's
      // first frame, so this only fires for a genuinely fresh session.
      if (ref.read(sessionProvider).phase == SessionPhase.idle) {
        ref.read(sessionProvider.notifier).startSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isSimulating = ref.watch(isSimulatingProvider);

    // Navigate to diagnosis screen when concluded
    ref.listen(sessionProvider, (_, next) {
      if (next.phase == SessionPhase.concluded && next.finalDiagnosis != null) {
        context.pushReplacement('/diagnosis');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Session'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(sessionProvider.notifier).reset();
            context.go('/');
          },
        ),
        actions: [
          if (isSimulating)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Simulator Controls',
              onPressed: () => showSimulatorControlPanel(context),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _StatusBar(session: session),
        ),
      ),
      body: Column(
        children: [
          // Zone 2 — main content
          Expanded(child: _MainContent(session: session)),
          // Zone 3 — test history timeline
          TestHistoryTimeline(completedTests: session.completedTests),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final SessionState session;
  const _StatusBar({required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A30))),
      ),
      child: Row(
        children: [
          if (session.phase == SessionPhase.llmHypothesis ||
              session.phase == SessionPhase.llmAnalysis ||
              session.phase == SessionPhase.intakeScan)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            )
          else
            Icon(_phaseIcon(session.phase), size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.statusMessage,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (session.testNumber > 0)
            Text(
              'Test ${session.testNumber}/${session.maxTests}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.accent),
            ),
        ],
      ),
    );
  }

  IconData _phaseIcon(SessionPhase phase) {
    return switch (phase) {
      SessionPhase.testPrescribed => Icons.assignment,
      SessionPhase.waitingForCondition => Icons.hourglass_top,
      SessionPhase.collecting => Icons.sensors,
      SessionPhase.concluded => Icons.check_circle,
      SessionPhase.error => Icons.error_outline,
      _ => Icons.info_outline,
    };
  }
}

class _MainContent extends ConsumerWidget {
  final SessionState session;
  const _MainContent({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (session.phase) {
      SessionPhase.idle ||
      SessionPhase.intakeScan ||
      SessionPhase.llmHypothesis =>
        AgentThinkingIndicator(message: session.statusMessage),

      SessionPhase.llmAnalysis =>
        AgentThinkingIndicator(message: session.statusMessage),

      SessionPhase.testPrescribed ||
      SessionPhase.waitingForCondition =>
        session.currentTest != null
            ? SingleChildScrollView(
                child: TestInstructionCard(
                  test: session.currentTest!,
                  onStartTest: () =>
                      ref.read(sessionProvider.notifier).startTest(),
                ),
              )
            : _VehicleInfoCard(session: session),

      SessionPhase.collecting => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: LiveSensorDashboard(
              testId: session.currentTest?.testId ?? '',
              liveValues: session.liveValues,
              elapsed: session.collectingElapsed,
              totalDuration: _testDuration(session.currentTest?.testId),
              liveHistory: session.liveHistory,
              vehicleSupportedPidCodes: session.vehicleSupportedPids,
            ),
          ),
        ),

      SessionPhase.concluded => const Center(
          child: CircularProgressIndicator(),
        ),

      SessionPhase.error => _ErrorView(message: session.errorMessage),
    };
  }

  int _testDuration(String? testId) {
    if (testId == null) return 60;
    return TestLibrary.byId(testId)?.durationSeconds ?? 60;
  }
}

class _VehicleInfoCard extends ConsumerStatefulWidget {
  final SessionState session;
  const _VehicleInfoCard({required this.session});

  @override
  ConsumerState<_VehicleInfoCard> createState() => _VehicleInfoCardState();
}

class _VehicleInfoCardState extends ConsumerState<_VehicleInfoCard> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final q in widget.session.vehicleInfoQuestions) {
      _controllers[q] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final answers = <String, String>{
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    };
    ref.read(sessionProvider.notifier).submitVehicleInfo(answers);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline,
                      color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  Text('AI needs more information',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 16),
              for (final q in widget.session.vehicleInfoQuestions) ...[
                Text(q,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                TextField(
                  controller: _controllers[q],
                  decoration: const InputDecoration(hintText: 'Your answer'),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Submit Answers'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? message;
  const _ErrorView({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: AppTheme.accentRed),
            const SizedBox(height: 16),
            Text('Session Error',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message ?? 'An unknown error occurred.',
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
