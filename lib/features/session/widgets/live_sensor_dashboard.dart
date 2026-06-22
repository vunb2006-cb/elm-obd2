import 'package:flutter/material.dart';

import '../../../core/diagnosis/test_library.dart';
import '../../../core/obd/pid_constants.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/pid_value_tile.dart';
import '../session_provider.dart';
import 'sensor_chart.dart';

class LiveSensorDashboard extends StatefulWidget {
  final String testId;
  final Map<String, double> liveValues;
  final int elapsed;
  final int totalDuration;

  /// Time-series history accumulated since the current test started.
  final Map<String, List<ChartPoint>> liveHistory;

  /// PID hex codes the connected ECU reported as supported.
  /// Used to dim unsupported PIDs in the selector bar.
  final Set<String> vehicleSupportedPidCodes;

  const LiveSensorDashboard({
    super.key,
    required this.testId,
    required this.liveValues,
    required this.elapsed,
    required this.totalDuration,
    required this.liveHistory,
    required this.vehicleSupportedPidCodes,
  });

  @override
  State<LiveSensorDashboard> createState() => _LiveSensorDashboardState();
}

class _LiveSensorDashboardState extends State<LiveSensorDashboard> {
  bool _showChart = false;

  /// Which PIDs are selected for chart display.
  late Set<String> _selectedPids;

  @override
  void initState() {
    super.initState();
    // Default: all PIDs for the current test are selected.
    final def = TestLibrary.byId(widget.testId);
    _selectedPids = (def?.pids ?? widget.liveValues.keys).toSet();
  }

  @override
  void didUpdateWidget(LiveSensorDashboard old) {
    super.didUpdateWidget(old);
    if (old.testId != widget.testId) {
      final def = TestLibrary.byId(widget.testId);
      setState(() {
        _selectedPids = (def?.pids ?? widget.liveValues.keys).toSet();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final def = TestLibrary.byId(widget.testId);
    final pids = def?.pids ?? widget.liveValues.keys.toList();
    final progress =
        widget.totalDuration > 0 ? widget.elapsed / widget.totalDuration : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Progress bar + view toggle ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.elapsed}s elapsed',
                      style: Theme.of(context).textTheme.bodySmall),
                  Row(
                    children: [
                      Text('${widget.totalDuration}s total',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(width: 12),
                      _ViewToggle(
                        showChart: _showChart,
                        onToggle: () =>
                            setState(() => _showChart = !_showChart),
                      ),
                    ],
                  ),
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
        const SizedBox(height: 12),

        // ── Main content: chart or grid ────────────────────────────────────
        if (_showChart) ...[
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SensorChart(
                history: widget.liveHistory,
                selectedPids: _selectedPids,
              ),
            ),
          ),
          const SizedBox(height: 10),
          PidSelectorBar(
            availablePids: pids,
            vehicleSupportedPidCodes: widget.vehicleSupportedPidCodes,
            selected: _selectedPids,
            onToggle: (pid, isSelected) => setState(() {
              if (isSelected) {
                _selectedPids.add(pid);
              } else {
                _selectedPids.remove(pid);
              }
            }),
          ),
        ] else ...[
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
                final code = PidConstants.codeForName(pidName) ?? pidName;
                final value = widget.liveValues[pidName];
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

// ─── View toggle button ────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final bool showChart;
  final VoidCallback onToggle;

  const _ViewToggle({required this.showChart, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3A3A40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showChart ? Icons.grid_view_rounded : Icons.show_chart_rounded,
              size: 14,
              color: AppTheme.accent,
            ),
            const SizedBox(width: 4),
            Text(
              showChart ? 'Grid' : 'Chart',
              style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
