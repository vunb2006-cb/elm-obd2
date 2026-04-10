import 'dart:async';

import '../obd/obd_service.dart';
import '../obd/pid_constants.dart';

class ConditionStatus {
  final bool isMet;
  final Map<String, double> currentValues;
  final Map<String, String> targetDescriptions;

  const ConditionStatus({
    required this.isMet,
    required this.currentValues,
    required this.targetDescriptions,
  });
}

/// Evaluates a condition expression string against live OBD data.
///
/// Condition expressions are simple strings like:
///   "coolant_temp > 85 && rpm < 1000"
/// Each clause is "<pid_name> <op> <value>", joined by "&&".
class ConditionEvaluator {
  final ObdService _obd;
  StreamController<ConditionStatus>? _controller;
  Timer? _timer;

  ConditionEvaluator(this._obd);

  /// Start polling condition every [pollIntervalSeconds] seconds.
  Stream<ConditionStatus> evaluate(
    String conditionExpression, {
    int pollIntervalSeconds = 3,
  }) {
    _controller?.close();
    _controller = StreamController<ConditionStatus>.broadcast();

    final clauses = _parseClauses(conditionExpression);
    final pids = clauses.map((c) => c.pidName).toSet().toList();

    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: pollIntervalSeconds),
      (_) => _poll(clauses, pids),
    );

    // Immediate first poll
    _poll(clauses, pids);

    return _controller!.stream;
  }

  Future<void> _poll(
      List<_Clause> clauses, List<String> pidNames) async {
    final values = <String, double>{};
    for (final name in pidNames) {
      final code = PidConstants.codeForName(name);
      if (code == null) continue;
      try {
        final v = await _obd.readPID(code);
        if (v != null) values[name] = v;
      } catch (_) {}
    }

    bool allMet = true;
    final targets = <String, String>{};

    for (final clause in clauses) {
      final current = values[clause.pidName];
      final met = current != null && clause.evaluate(current);
      if (!met) allMet = false;
      targets[clause.pidName] = clause.description;
    }

    _controller?.add(ConditionStatus(
      isMet: allMet,
      currentValues: values,
      targetDescriptions: targets,
    ));
  }

  List<_Clause> _parseClauses(String expression) {
    final clauses = <_Clause>[];
    final parts = expression.split('&&').map((s) => s.trim());

    for (final part in parts) {
      final clause = _Clause.tryParse(part);
      if (clause != null) clauses.add(clause);
    }

    return clauses;
  }

  void stop() {
    _timer?.cancel();
    _controller?.close();
    _controller = null;
  }

  void dispose() => stop();
}

class _Clause {
  final String pidName;
  final String operator;
  final double threshold;

  const _Clause({
    required this.pidName,
    required this.operator,
    required this.threshold,
  });

  static _Clause? tryParse(String clause) {
    // Patterns: "rpm < 1000", "coolant_temp > 85", "rpm > 1800 && rpm < 2200"
    final patterns = [
      RegExp(r'^(\w+)\s*(>=|<=|>|<|==)\s*([\d.]+)$'),
    ];

    for (final re in patterns) {
      final m = re.firstMatch(clause.trim());
      if (m != null) {
        return _Clause(
          pidName: m.group(1)!,
          operator: m.group(2)!,
          threshold: double.parse(m.group(3)!),
        );
      }
    }
    return null;
  }

  bool evaluate(double value) {
    switch (operator) {
      case '>':
        return value > threshold;
      case '<':
        return value < threshold;
      case '>=':
        return value >= threshold;
      case '<=':
        return value <= threshold;
      case '==':
        return (value - threshold).abs() < 0.001;
      default:
        return false;
    }
  }

  String get description {
    final unit = PidConstants.unitFor(PidConstants.codeForName(pidName) ?? '');
    return 'needs to be $operator ${threshold.toStringAsFixed(0)}$unit';
  }
}
