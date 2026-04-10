import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../diagnosis/models/diagnosis_result.dart';
import '../diagnosis/models/diagnostic_session.dart';
import '../diagnosis/models/prescribed_test.dart';
import '../diagnosis/models/sensor_summary.dart';

/// Persists diagnostic sessions to Hive.
///
/// Sessions are stored as JSON strings under the key = session.id.
class SessionRepository {
  static const _boxName = 'sessions';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  Future<void> save(DiagnosticSession session) async {
    final json = jsonEncode(_sessionToMap(session));
    await _box.put(session.id, json);
  }

  Future<List<DiagnosticSession>> loadAll() async {
    final sessions = <DiagnosticSession>[];
    for (final key in _box.keys) {
      final json = _box.get(key as String);
      if (json != null) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          sessions.add(_sessionFromMap(map));
        } catch (_) {
          // Skip corrupted entries
        }
      }
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Returns the most recent session that was saved mid-way (not concluded).
  /// Returns null if no interrupted session exists.
  Future<DiagnosticSession?> loadInterrupted() async {
    final all = await loadAll();
    try {
      return all.firstWhere((s) => s.isInterrupted);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) => _box.delete(id);

  Future<void> clear() => _box.clear();

  // ─── Serialization ───────────────────────────────────────────────────────

  Map<String, dynamic> _sessionToMap(DiagnosticSession s) => {
        'id': s.id,
        'startTime': s.startTime.toIso8601String(),
        'endTime': s.endTime?.toIso8601String(),
        'vehicleDescription': s.vehicleDescription,
        'driverComplaint': s.driverComplaint,
        'testsRun': s.testsRun.map(_testToMap).toList(),
        'testResults': s.testResults.map(_summaryToMap).toList(),
        'finalDiagnosis': s.finalDiagnosis != null
            ? _diagnosisToMap(s.finalDiagnosis!)
            : null,
        'isInterrupted': s.isInterrupted,
        'intakePrompt': s.intakePrompt,
      };

  DiagnosticSession _sessionFromMap(Map<String, dynamic> m) =>
      DiagnosticSession(
        id: m['id'] as String,
        startTime: DateTime.parse(m['startTime'] as String),
        endTime: m['endTime'] != null
            ? DateTime.parse(m['endTime'] as String)
            : null,
        vehicleDescription: m['vehicleDescription'] as String,
        driverComplaint: m['driverComplaint'] as String,
        testsRun: (m['testsRun'] as List)
            .map((e) => _testFromMap(e as Map<String, dynamic>))
            .toList(),
        testResults: (m['testResults'] as List)
            .map((e) => _summaryFromMap(e as Map<String, dynamic>))
            .toList(),
        finalDiagnosis: m['finalDiagnosis'] != null
            ? _diagnosisFromMap(
                m['finalDiagnosis'] as Map<String, dynamic>)
            : null,
        isInterrupted: m['isInterrupted'] as bool? ?? false,
        intakePrompt: m['intakePrompt'] as String?,
      );

  Map<String, dynamic> _testToMap(PrescribedTest t) => {
        'testId': t.testId,
        'instruction': t.instruction,
        'conditionHint': t.conditionHint,
        'rationale': t.rationale,
        'urgency': t.urgency,
      };

  PrescribedTest _testFromMap(Map<String, dynamic> m) => PrescribedTest(
        testId: m['testId'] as String,
        instruction: m['instruction'] as String,
        conditionHint: m['conditionHint'] as String?,
        rationale: m['rationale'] as String,
        urgency: m['urgency'] as String,
      );

  Map<String, dynamic> _summaryToMap(SensorSummary s) => {
        'testId': s.testId,
        'durationSeconds': s.durationSeconds,
        'sampleCount': s.sampleCount,
        'pidSummaries': {
          for (final e in s.pidSummaries.entries)
            e.key: {
              'pid': e.value.pid,
              'avg': e.value.avg,
              'min': e.value.min,
              'max': e.value.max,
              'stdDev': e.value.stdDev,
              'stability': e.value.stability,
            }
        },
        'notableEvents': s.notableEvents
            .map((e) => {
                  'secondsIntoTest': e.secondsIntoTest,
                  'description': e.description,
                })
            .toList(),
        'skippedPids': s.skippedPids,
      };

  SensorSummary _summaryFromMap(Map<String, dynamic> m) {
    final pidMap = m['pidSummaries'] as Map<String, dynamic>;
    final pidSummaries = <String, PidSummary>{};
    for (final entry in pidMap.entries) {
      final v = entry.value as Map<String, dynamic>;
      pidSummaries[entry.key] = PidSummary(
        pid: v['pid'] as String,
        avg: (v['avg'] as num).toDouble(),
        min: (v['min'] as num).toDouble(),
        max: (v['max'] as num).toDouble(),
        stdDev: (v['stdDev'] as num).toDouble(),
        stability: v['stability'] as String,
      );
    }
    final events = (m['notableEvents'] as List)
        .map((e) => NotableEvent(
              secondsIntoTest: e['secondsIntoTest'] as int,
              description: e['description'] as String,
            ))
        .toList();
    final skippedPids =
        (m['skippedPids'] as List?)?.cast<String>() ?? const <String>[];
    return SensorSummary(
      testId: m['testId'] as String,
      durationSeconds: m['durationSeconds'] as int,
      sampleCount: m['sampleCount'] as int,
      pidSummaries: pidSummaries,
      notableEvents: events,
      skippedPids: skippedPids,
    );
  }

  Map<String, dynamic> _diagnosisToMap(DiagnosisResult d) => {
        'primaryFault': d.primaryFault,
        'confidence': d.confidence,
        'evidence': d.evidence,
        'severity': d.severity,
        'symptomsMayNotice': d.symptomsMayNotice,
        'recommendedAction': d.recommendedAction,
        'whatObdCannotTell': d.whatObdCannotTell,
        'furtherPhysicalTests': d.furtherPhysicalTests,
      };

  DiagnosisResult _diagnosisFromMap(Map<String, dynamic> m) =>
      DiagnosisResult(
        primaryFault: m['primaryFault'] as String,
        confidence: m['confidence'] as String,
        evidence: (m['evidence'] as List).cast<String>(),
        severity: m['severity'] as String,
        symptomsMayNotice:
            (m['symptomsMayNotice'] as List).cast<String>(),
        recommendedAction: m['recommendedAction'] as String,
        whatObdCannotTell: m['whatObdCannotTell'] as String,
        furtherPhysicalTests: m['furtherPhysicalTests'] as String?,
      );
}
