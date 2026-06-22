import 'package:google_generative_ai/google_generative_ai.dart';

import 'function_tools.dart';
import 'system_prompt.dart';
import 'models/prescribed_test.dart';
import 'models/diagnosis_result.dart';
import 'models/sensor_summary.dart';
import '../../features/intake/intake_provider.dart';

// ─── Sealed action types ──────────────────────────────────────────────────────

sealed class AgentAction {}

class PrescribeTestAction extends AgentAction {
  final PrescribedTest test;
  PrescribeTestAction(this.test);
}

class RequestVehicleInfoAction extends AgentAction {
  final List<String> questions;
  final String? context;
  RequestVehicleInfoAction(this.questions, this.context);
}

class RequestLiveNarrationAction extends AgentAction {
  final String testId;
  final String context;
  RequestLiveNarrationAction(this.testId, this.context);
}

class ConcludeAction extends AgentAction {
  final DiagnosisResult result;
  ConcludeAction(this.result);
}

// ─── Agent ────────────────────────────────────────────────────────────────────

class GeminiAgent {
  late GenerativeModel _model;
  late ChatSession _chat;
  bool _initialized = false;

  Future<void> initialize(String apiKey) async {
    if (_initialized) return;
    if (apiKey.trim().isEmpty) {
      throw StateError(
          'No Gemini API key set. Add one in Settings before starting a session.');
    }

    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
      tools: FunctionTools.allTools,
      systemInstruction: Content.system(SystemPrompt.text),
      generationConfig: GenerationConfig(temperature: 0.2),
    );

    _chat = _model.startChat();
    _initialized = true;
  }

  /// Turn 1: submit intake data and receive the first action.
  Future<AgentAction> submitIntake(IntakeData intake) async {
    _ensureInitialized();
    final prompt = intake.toPromptText();
    final response = await _chat.sendMessage(Content.text(prompt));
    return _parseResponse(response);
  }

  /// Submit the result of a completed test.
  Future<AgentAction> submitTestResult(SensorSummary result) async {
    _ensureInitialized();
    final text = result.toPromptText();
    final response = await _chat.sendMessage(Content.text(text));
    return _parseResponse(response);
  }

  /// Submit user answers to a `request_vehicle_info` call.
  Future<AgentAction> submitVehicleInfo(
      List<String> questions, Map<String, String> answers) async {
    _ensureInitialized();
    final sb = StringBuffer('=== USER ANSWERS ===\n');
    for (var i = 0; i < questions.length; i++) {
      final answer = answers[questions[i]] ?? '(no answer)';
      sb.writeln('Q: ${questions[i]}');
      sb.writeln('A: $answer');
    }
    final response = await _chat.sendMessage(Content.text(sb.toString()));
    return _parseResponse(response);
  }

  AgentAction _parseResponse(GenerateContentResponse response) {
    final calls = response.functionCalls.toList();

    if (calls.isEmpty) {
      // Defensive: system prompt should prevent plain text, but handle it
      final text = response.text ?? '';
      throw StateError(
          'Gemini returned plain text instead of a function call: $text');
    }

    final call = calls.first;

    switch (call.name) {
      case 'prescribe_test':
        return PrescribeTestAction(_parsePrescribeTest(call.args));

      case 'request_vehicle_info':
        final questions =
            (call.args['questions'] as List).cast<String>();
        final context = call.args['context'] as String?;
        return RequestVehicleInfoAction(questions, context);

      case 'request_live_narration':
        return RequestLiveNarrationAction(
          call.args['test_id'] as String,
          call.args['context'] as String,
        );

      case 'conclude_diagnosis':
        return ConcludeAction(_parseDiagnosis(call.args));

      default:
        throw StateError('Unknown function call: ${call.name}');
    }
  }

  PrescribedTest _parsePrescribeTest(Map<String, Object?> args) {
    return PrescribedTest(
      testId: args['test_id'] as String,
      instruction: args['instruction'] as String,
      conditionHint: args['condition_hint'] as String?,
      rationale: args['rationale'] as String,
      urgency: args['urgency'] as String,
    );
  }

  DiagnosisResult _parseDiagnosis(Map<String, Object?> args) {
    final evidence = (args['evidence'] as List?)?.cast<String>() ?? [];
    final symptoms =
        (args['symptoms_driver_may_notice'] as List?)?.cast<String>() ?? [];
    return DiagnosisResult(
      primaryFault: args['primary_fault'] as String,
      confidence: args['confidence'] as String,
      evidence: evidence,
      severity: args['severity'] as String,
      symptomsMayNotice: symptoms,
      recommendedAction: args['recommended_action'] as String,
      whatObdCannotTell: args['what_obd_cannot_tell'] as String,
      furtherPhysicalTests: args['further_physical_tests'] as String?,
    );
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('GeminiAgent.initialize() must be called first');
    }
  }

  void reset() {
    _initialized = false;
  }
}
