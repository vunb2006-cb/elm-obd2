import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnosis/gemini_agent.dart';
import '../../core/diagnosis/test_executor.dart';
import '../../core/diagnosis/test_library.dart';
import '../../core/diagnosis/models/prescribed_test.dart';
import '../../core/diagnosis/models/sensor_summary.dart';
import '../../core/diagnosis/models/diagnosis_result.dart';
import '../../core/diagnosis/models/diagnostic_session.dart';
import '../../core/obd/obd_service.dart';
import '../../core/storage/session_repository.dart';
import '../../features/connect/connect_provider.dart';
import '../../features/intake/intake_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

enum SessionPhase {
  idle,
  intakeScan,
  llmHypothesis,
  testPrescribed,
  waitingForCondition,
  collecting,
  llmAnalysis,
  concluded,
  error,
}

class SessionState {
  final SessionPhase phase;
  final String statusMessage;
  final PrescribedTest? currentTest;
  final int testNumber;
  final int maxTests;
  final List<SensorSummary> completedTests;
  final DiagnosisResult? finalDiagnosis;
  final Map<String, double> liveValues; // live PID values during collection
  final int collectingElapsed; // seconds elapsed in current test
  final List<String> vehicleInfoQuestions;
  final String? liveNarrationContext;
  final String? errorMessage;

  const SessionState({
    this.phase = SessionPhase.idle,
    this.statusMessage = '',
    this.currentTest,
    this.testNumber = 0,
    this.maxTests = 5,
    this.completedTests = const [],
    this.finalDiagnosis,
    this.liveValues = const {},
    this.collectingElapsed = 0,
    this.vehicleInfoQuestions = const [],
    this.liveNarrationContext,
    this.errorMessage,
  });

  SessionState copyWith({
    SessionPhase? phase,
    String? statusMessage,
    PrescribedTest? currentTest,
    bool clearCurrentTest = false,
    int? testNumber,
    int? maxTests,
    List<SensorSummary>? completedTests,
    DiagnosisResult? finalDiagnosis,
    Map<String, double>? liveValues,
    int? collectingElapsed,
    List<String>? vehicleInfoQuestions,
    String? liveNarrationContext,
    bool clearLiveNarration = false,
    String? errorMessage,
  }) {
    return SessionState(
      phase: phase ?? this.phase,
      statusMessage: statusMessage ?? this.statusMessage,
      currentTest:
          clearCurrentTest ? null : (currentTest ?? this.currentTest),
      testNumber: testNumber ?? this.testNumber,
      maxTests: maxTests ?? this.maxTests,
      completedTests: completedTests ?? this.completedTests,
      finalDiagnosis: finalDiagnosis ?? this.finalDiagnosis,
      liveValues: liveValues ?? this.liveValues,
      collectingElapsed:
          collectingElapsed ?? this.collectingElapsed,
      vehicleInfoQuestions:
          vehicleInfoQuestions ?? this.vehicleInfoQuestions,
      liveNarrationContext: clearLiveNarration
          ? null
          : (liveNarrationContext ?? this.liveNarrationContext),
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SessionNotifier extends StateNotifier<SessionState> {
  final GeminiAgent _agent;
  final ObdService _obd;
  final IntakeData? _intake;
  final SessionRepository _repo;
  TestExecutor? _executor;

  // Tracks the in-progress session being auto-saved to Hive.
  DiagnosticSession? _checkpoint;

  SessionNotifier(this._agent, this._obd, this._intake, this._repo)
      : super(const SessionState());

  Future<void> startSession() async {
    if (_intake == null) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'No intake data. Please fill in vehicle information.',
      );
      return;
    }

    state = state.copyWith(
      phase: SessionPhase.intakeScan,
      statusMessage: 'Reading fault codes and sensor data...',
    );

    try {
      // Read DTCs and freeze frame
      final dtcs = await _obd.readDTCs();
      final ff = await _obd.readFreezeFrame();
      final pids = await _obd.readSupportedPIDs();

      // Update intake with live OBD data
      final enrichedIntake = IntakeData(
        vehicleMake: _intake.vehicleMake,
        vehicleModel: _intake.vehicleModel,
        vehicleYear: _intake.vehicleYear,
        engineDisplacement: _intake.engineDisplacement,
        odometer: _intake.odometer,
        dtcs: dtcs.isNotEmpty ? dtcs : _intake.dtcs,
        freezeFrame: ff.isNotEmpty ? ff : _intake.freezeFrame,
        supportedPids: pids.isNotEmpty ? pids : _intake.supportedPids,
        driverComplaint: _intake.driverComplaint,
        recentRepairs: _intake.recentRepairs,
      );

      // Create and immediately persist an interrupted checkpoint so that
      // if the app is killed from this point forward, the user can resume.
      await _repo.init();
      _checkpoint = DiagnosticSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        vehicleDescription:
            '${_intake.vehicleYear} ${_intake.vehicleMake} ${_intake.vehicleModel}',
        driverComplaint: _intake.driverComplaint,
        isInterrupted: true,
        intakePrompt: enrichedIntake.toPromptText(),
      );
      await _repo.save(_checkpoint!);

      state = state.copyWith(
        phase: SessionPhase.llmHypothesis,
        statusMessage: 'AI is analyzing fault codes and forming hypotheses...',
      );

      await _agent.initialize();
      final action = await _agent.submitIntake(enrichedIntake);
      _handleAction(action);
    } catch (e) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Session failed: $e',
      );
    }
  }

  /// Called when the user confirms conditions are met and taps "Start Test".
  Future<void> startTest() async {
    final test = state.currentTest;
    if (test == null) return;

    final def = TestLibrary.byId(test.testId);
    if (def == null) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Unknown test: ${test.testId}',
      );
      return;
    }

    state = state.copyWith(
      phase: SessionPhase.collecting,
      statusMessage: 'Running ${def.name}...',
      collectingElapsed: 0,
    );

    _executor = TestExecutor(_obd);

    try {
      final summary = await _executor!.execute(
        test.testId,
        onProgress: (elapsed, values) {
          if (mounted) {
            state = state.copyWith(
              collectingElapsed: elapsed,
              liveValues: values,
            );
          }
        },
      );

      if (!mounted) return;

      final updatedTests = [...state.completedTests, summary];
      state = state.copyWith(
        phase: SessionPhase.llmAnalysis,
        statusMessage: 'AI is analysing test results...',
        completedTests: updatedTests,
        liveValues: {},
      );

      // Update the checkpoint so this completed test is recoverable.
      if (_checkpoint != null) {
        _checkpoint = _checkpoint!.copyWith(
          testsRun: [
            ..._checkpoint!.testsRun,
            state.currentTest!,
          ],
          testResults: updatedTests,
        );
        await _repo.save(_checkpoint!);
      }

      final action = await _agent.submitTestResult(summary);
      _handleAction(action);
    } catch (e) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Test failed: $e',
      );
    }
  }

  /// Called when condition is confirmed met and we're showing the test card.
  void confirmConditionMet() {
    state = state.copyWith(phase: SessionPhase.waitingForCondition);
  }

  /// Submit answers to a vehicle info request.
  Future<void> submitVehicleInfo(Map<String, String> answers) async {
    state = state.copyWith(
      phase: SessionPhase.llmHypothesis,
      statusMessage: 'Processing your answers...',
    );
    try {
      final action = await _agent.submitVehicleInfo(
          state.vehicleInfoQuestions, answers);
      _handleAction(action);
    } catch (e) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Failed to submit info: $e',
      );
    }
  }

  void _handleAction(AgentAction action) {
    switch (action) {
      case PrescribeTestAction(:final test):
        state = state.copyWith(
          phase: SessionPhase.testPrescribed,
          statusMessage: 'Test ready: ${test.testId}',
          currentTest: test,
          testNumber: state.testNumber + 1,
          clearLiveNarration: true,
        );

      case RequestVehicleInfoAction(:final questions, :final context):
        state = state.copyWith(
          phase: SessionPhase.testPrescribed, // reuse UI for info cards
          statusMessage: context ?? 'AI needs more information',
          vehicleInfoQuestions: questions,
        );

      case RequestLiveNarrationAction(:final context):
        state = state.copyWith(
          liveNarrationContext: context,
          statusMessage: 'Gemini Live will narrate this test',
        );
        // After setting narration context, prescribe the test in next turn
        // (Gemini follows up with prescribe_test)

      case ConcludeAction(:final result):
        state = state.copyWith(
          phase: SessionPhase.concluded,
          statusMessage: 'Diagnosis complete',
          finalDiagnosis: result,
          clearCurrentTest: true,
        );
        // Mark checkpoint as concluded so it no longer shows as interrupted.
        if (_checkpoint != null) {
          _checkpoint = _checkpoint!.copyWith(
            isInterrupted: false,
            endTime: DateTime.now(),
            finalDiagnosis: result,
          );
          _repo.save(_checkpoint!);
        }
    }
  }

  /// Resumes a previously interrupted session.
  ///
  /// Replays the original intake prompt and every completed test summary to a
  /// fresh Gemini ChatSession so the AI reconstructs its full context, then
  /// awaits the next prescribed action.
  Future<void> resumeFromCheckpoint(DiagnosticSession checkpoint) async {
    if (checkpoint.intakePrompt == null) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Cannot resume — no intake data was saved.',
      );
      return;
    }

    _checkpoint = checkpoint;

    state = state.copyWith(
      phase: SessionPhase.llmHypothesis,
      statusMessage:
          'Resuming session — replaying ${checkpoint.testResults.length} '
          'completed test(s) to AI...',
      completedTests: checkpoint.testResults,
      testNumber: checkpoint.testResults.length,
    );

    try {
      await _agent.initialize();

      // Reconstruct Gemini context with a single combined message that
      // summarises all work done so far.
      final context = StringBuffer();
      context.writeln('=== SESSION RESUME ===');
      context.writeln(
          'This is a continuation of a diagnostic session that was interrupted.');
      context.writeln(
          'The following data was collected before the interruption.\n');
      context.writeln('--- ORIGINAL VEHICLE & INTAKE DATA ---');
      context.writeln(checkpoint.intakePrompt);

      if (checkpoint.testResults.isNotEmpty) {
        context.writeln('\n--- TESTS COMPLETED BEFORE INTERRUPTION ---');
        for (final summary in checkpoint.testResults) {
          context.writeln(summary.toPromptText());
          context.writeln();
        }
        context.writeln(
            'Based on the above, please continue the diagnosis. '
            'Do not repeat any tests already completed. '
            'Prescribe the next test or conclude if you have enough evidence.');
      } else {
        context.writeln(
            '\nNo tests have been completed yet. Please begin the diagnostic '
            'process from the intake data above.');
      }

      final action = await _agent.submitIntake(
        _ResumeIntakeProxy(context.toString()),
      );
      _handleAction(action);
    } catch (e) {
      state = state.copyWith(
        phase: SessionPhase.error,
        errorMessage: 'Resume failed: $e',
      );
    }
  }

  void cancelTest() {
    _executor?.cancel();
  }

  void reset() {
    _executor?.cancel();
    _agent.reset();
    _checkpoint = null;
    state = const SessionState();
  }
}

// ─── Resume proxy ─────────────────────────────────────────────────────────────

/// Thin wrapper used when resuming: returns a pre-built context string
/// directly so [GeminiAgent.submitIntake] sends the full reconstruction prompt.
class _ResumeIntakeProxy extends IntakeData {
  final String _prebuiltPrompt;

  _ResumeIntakeProxy(this._prebuiltPrompt)
      : super(
          vehicleMake: '',
          vehicleModel: '',
          vehicleYear: 0,
          engineDisplacement: '',
          odometer: 0,
          dtcs: const [],
          freezeFrame: const {},
          supportedPids: const [],
          driverComplaint: '',
        );

  @override
  String toPromptText() => _prebuiltPrompt;
}

// ─── Providers ────────────────────────────────────────────────────────────────

final geminiAgentProvider = Provider<GeminiAgent>((ref) {
  final agent = GeminiAgent();
  ref.onDispose(agent.reset);
  return agent;
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository();
});

/// Provides the most recent interrupted session, if any exists.
final interruptedSessionProvider =
    FutureProvider<DiagnosticSession?>((ref) async {
  final repo = ref.watch(sessionRepositoryProvider);
  await repo.init();
  return repo.loadInterrupted();
});

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final agent = ref.watch(geminiAgentProvider);
  final obd = ref.watch(obdServiceProvider);
  final intake = ref.watch(intakeProvider);
  final repo = ref.watch(sessionRepositoryProvider);
  return SessionNotifier(agent, obd, intake, repo);
});
