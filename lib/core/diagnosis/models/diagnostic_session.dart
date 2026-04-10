import 'sensor_summary.dart';
import 'diagnosis_result.dart';
import 'prescribed_test.dart';

class DiagnosticSession {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  final String vehicleDescription;
  final String driverComplaint;
  final List<PrescribedTest> testsRun;
  final List<SensorSummary> testResults;
  DiagnosisResult? finalDiagnosis;

  /// True when the session was saved mid-way (app killed or navigated away).
  /// False once a final diagnosis has been committed.
  final bool isInterrupted;

  /// The exact prompt text that was sent to Gemini on Turn 1 (intake data).
  /// Stored so the Gemini context can be reconstructed when resuming.
  final String? intakePrompt;

  DiagnosticSession({
    required this.id,
    required this.startTime,
    required this.vehicleDescription,
    required this.driverComplaint,
    List<PrescribedTest>? testsRun,
    List<SensorSummary>? testResults,
    this.finalDiagnosis,
    this.endTime,
    this.isInterrupted = false,
    this.intakePrompt,
  })  : testsRun = testsRun ?? [],
        testResults = testResults ?? [];

  DiagnosticSession copyWith({
    DateTime? endTime,
    List<PrescribedTest>? testsRun,
    List<SensorSummary>? testResults,
    DiagnosisResult? finalDiagnosis,
    bool? isInterrupted,
  }) {
    return DiagnosticSession(
      id: id,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      vehicleDescription: vehicleDescription,
      driverComplaint: driverComplaint,
      testsRun: testsRun ?? this.testsRun,
      testResults: testResults ?? this.testResults,
      finalDiagnosis: finalDiagnosis ?? this.finalDiagnosis,
      isInterrupted: isInterrupted ?? this.isInterrupted,
      intakePrompt: intakePrompt,
    );
  }
}
