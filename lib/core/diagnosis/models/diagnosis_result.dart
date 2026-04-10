class DiagnosisResult {
  final String primaryFault;
  final String confidence; // "high" | "medium" | "low"
  final List<String> evidence;
  final String severity; // "critical" | "high" | "medium" | "low"
  final List<String> symptomsMayNotice;
  final String recommendedAction;
  final String whatObdCannotTell;
  final String? furtherPhysicalTests;

  const DiagnosisResult({
    required this.primaryFault,
    required this.confidence,
    required this.evidence,
    required this.severity,
    required this.symptomsMayNotice,
    required this.recommendedAction,
    required this.whatObdCannotTell,
    this.furtherPhysicalTests,
  });
}
