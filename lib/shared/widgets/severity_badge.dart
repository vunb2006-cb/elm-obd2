import 'package:flutter/material.dart';
import '../theme.dart';

enum Severity { critical, high, medium, low }

class SeverityBadge extends StatelessWidget {
  final Severity severity;
  final String? label;

  const SeverityBadge({super.key, required this.severity, this.label});

  static Severity fromString(String s) {
    switch (s.toLowerCase()) {
      case 'critical':
        return Severity.critical;
      case 'high':
        return Severity.high;
      case 'medium':
        return Severity.medium;
      default:
        return Severity.low;
    }
  }

  Color get _color {
    switch (severity) {
      case Severity.critical:
        return AppTheme.accentRed;
      case Severity.high:
        return const Color(0xFFE86B2A);
      case Severity.medium:
        return AppTheme.accent;
      case Severity.low:
        return AppTheme.accentGreen;
    }
  }

  String get _defaultLabel {
    switch (severity) {
      case Severity.critical:
        return 'CRITICAL';
      case Severity.high:
        return 'HIGH';
      case Severity.medium:
        return 'MEDIUM';
      case Severity.low:
        return 'LOW';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label ?? _defaultLabel,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
