class PrescribedTest {
  final String testId;
  final String instruction;
  final String? conditionHint;
  final String rationale;
  final String urgency; // "first" | "follow_up" | "confirmatory"

  const PrescribedTest({
    required this.testId,
    required this.instruction,
    this.conditionHint,
    required this.rationale,
    required this.urgency,
  });
}
