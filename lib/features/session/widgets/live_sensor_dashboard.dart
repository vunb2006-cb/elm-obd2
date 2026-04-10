import 'package:flutter/material.dart';

import '../../../core/diagnosis/test_library.dart';
import '../../../core/obd/pid_constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/pid_value_tile.dart';

class LiveSensorDashboard extends StatelessWidget {
  final String testId;
  final Map<String, double> liveValues;
  final int elapsed;
  final int totalDuration;

  const LiveSensorDashboard({
    super.key,
    required this.testId,
    required this.liveValues,
    required this.elapsed,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    final def = TestLibrary.byId(testId);
    final pids = def?.pids ?? liveValues.keys.toList();
    final progress = totalDuration > 0 ? elapsed / totalDuration : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${elapsed}s elapsed',
                      style: Theme.of(context).textTheme.bodySmall),
                  Text('${totalDuration}s total',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // PID grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: pids.length,
            itemBuilder: (context, i) {
              final pidName = pids[i];
              final code =
                  PidConstants.codeForName(pidName) ?? pidName;
              final value = liveValues[pidName];
              final displayValue =
                  value != null ? value.toStringAsFixed(1) : '--';
              return PidValueTile(
                label: PidConstants.nameFor(code),
                value: displayValue,
                unit: PidConstants.unitFor(code),
                valueColor: _valueColor(pidName, value),
              );
            },
          ),
        ),
      ],
    );
  }

  Color? _valueColor(String pidName, double? value) {
    if (value == null) return null;
    switch (pidName) {
      case 'coolant_temp':
        if (value > 110) return AppTheme.accentRed;
        if (value > 95) return AppTheme.accent;
        return null;
      case 'stft_b1':
      case 'ltft_b1':
        if (value.abs() > 20) return AppTheme.accentRed;
        if (value.abs() > 10) return AppTheme.accent;
        return null;
      case 'rpm':
        if (value < 500) return AppTheme.accentRed;
        return null;
      default:
        return null;
    }
  }
}
