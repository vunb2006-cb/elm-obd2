import 'package:google_generative_ai/google_generative_ai.dart';

import 'test_library.dart';

/// Gemini function tool declarations for the diagnostic agent.
class FunctionTools {
  FunctionTools._();

  static final prescribeTest = FunctionDeclaration(
    'prescribe_test',
    'Prescribe a specific diagnostic test for the user to run on the vehicle.',
    Schema.object(
      properties: {
        'test_id': Schema.string(
          description:
              'The test ID to run. Must be one of: ${TestLibrary.all.map((t) => t.id).join(", ")}',
        ),
        'instruction': Schema.string(
          description:
              'Plain English instruction shown to the user explaining what to do.',
        ),
        'condition_hint': Schema.string(
          description:
              'Brief reminder of the required engine condition, e.g. "engine warm, at idle, in neutral".',
        ),
        'rationale': Schema.string(
          description:
              'Why this test is needed and what hypothesis it is testing. Be specific.',
        ),
        'urgency': Schema.enumString(
          enumValues: ['first', 'follow_up', 'confirmatory'],
          description: 'The role of this test in the diagnostic sequence.',
        ),
      },
      requiredProperties: ['test_id', 'instruction', 'rationale', 'urgency'],
    ),
  );

  static final requestVehicleInfo = FunctionDeclaration(
    'request_vehicle_info',
    'Ask the user up to 3 clarifying questions about the vehicle or symptoms.',
    Schema.object(
      properties: {
        'questions': Schema.array(
          items: Schema.string(),
          description: 'List of questions for the user. Maximum 3.',
        ),
        'context': Schema.string(
          description: 'Why this information is needed for the diagnosis.',
        ),
      },
      requiredProperties: ['questions'],
    ),
  );

  static final concludeDiagnosis = FunctionDeclaration(
    'conclude_diagnosis',
    'Conclude the diagnostic session with a final diagnosis and recommendations.',
    Schema.object(
      properties: {
        'primary_fault': Schema.string(
          description:
              'The primary fault or root cause identified. Be specific.',
        ),
        'confidence': Schema.enumString(
          enumValues: ['high', 'medium', 'low'],
          description: 'Confidence level in this diagnosis.',
        ),
        'evidence': Schema.array(
          items: Schema.string(),
          description:
              'Bullet points of supporting evidence from the sensor data.',
        ),
        'severity': Schema.enumString(
          enumValues: ['critical', 'high', 'medium', 'low'],
          description: 'Severity of the fault for the driver.',
        ),
        'symptoms_driver_may_notice': Schema.array(
          items: Schema.string(),
          description: 'Symptoms the driver may experience.',
        ),
        'recommended_action': Schema.string(
          description: 'What the driver should do next.',
        ),
        'what_obd_cannot_tell': Schema.string(
          description:
              'Honest statement of what OBD2 data cannot confirm and what remains uncertain.',
        ),
        'further_physical_tests': Schema.string(
          description:
              'Physical tests a mechanic should perform beyond OBD2 scope.',
        ),
      },
      requiredProperties: [
        'primary_fault',
        'confidence',
        'evidence',
        'severity',
        'recommended_action',
        'what_obd_cannot_tell',
      ],
    ),
  );

  static final requestLiveNarration = FunctionDeclaration(
    'request_live_narration',
    'Request Gemini Live voice narration during the next test.',
    Schema.object(
      properties: {
        'test_id': Schema.string(
          description: 'The test about to be run.',
        ),
        'context': Schema.string(
          description:
              'What Gemini Live should watch for and narrate during the test.',
        ),
      },
      requiredProperties: ['test_id', 'context'],
    ),
  );

  static List<Tool> get allTools => [
        Tool(functionDeclarations: [
          prescribeTest,
          requestVehicleInfo,
          concludeDiagnosis,
          requestLiveNarration,
        ]),
      ];
}
