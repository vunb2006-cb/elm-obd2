import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/obd/pid_constants.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/pid_value_tile.dart';
import '../connect/connect_provider.dart';
import '../connect/simulator_control_panel.dart';
import '../session/widgets/sensor_chart.dart';
import 'monitor_provider.dart';

class LiveMonitorScreen extends ConsumerWidget {
  const LiveMonitorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitor = ref.watch(liveMonitorProvider);
    final notifier = ref.read(liveMonitorProvider.notifier);
    final isSimulating = ref.watch(isSimulatingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        actions: [
          if (isSimulating)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Simulator Controls',
              onPressed: () => showSimulatorControlPanel(context),
            ),
          if (monitor.history.isNotEmpty && !monitor.isPolling)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear history',
              onPressed: notifier.clearHistory,
            ),
          const SizedBox(width: 4),
          _StartStopButton(
            isPolling: monitor.isPolling,
            hasSelection: monitor.selectedPids.isNotEmpty,
            onStart: notifier.startPolling,
            onStop: notifier.stopPolling,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Chart area ─────────────────────────────────────────────────────
          Expanded(
            child: monitor.history.isEmpty && !monitor.isPolling
                ? _IdleHint(hasSelection: monitor.selectedPids.isNotEmpty)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                    child: SensorChart(
                      history: monitor.history,
                      selectedPids: monitor.selectedPids,
                    ),
                  ),
          ),

          // ── Current values strip ───────────────────────────────────────────
          if (monitor.currentValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: monitor.selectedPids.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final pidName = monitor.selectedPids.elementAt(i);
                  final code = PidConstants.codeForName(pidName) ?? pidName;
                  final value = monitor.currentValues[pidName];
                  return SizedBox(
                    width: 140,
                    child: PidValueTile(
                      label: PidConstants.nameFor(code),
                      value: value != null ? value.toStringAsFixed(1) : '--',
                      unit: PidConstants.unitFor(code),
                    ),
                  );
                },
              ),
            ),
          ],

          const Divider(height: 1, thickness: 1, color: Color(0xFF2A2A30)),

          // ── PID selector ───────────────────────────────────────────────────
          _PidGroupSelector(
            selectedPids: monitor.selectedPids,
            vehicleSupportedPidCodes: monitor.vehicleSupportedPids,
            onToggle: notifier.togglePid,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Start / Stop button ──────────────────────────────────────────────────────

class _StartStopButton extends StatelessWidget {
  final bool isPolling;
  final bool hasSelection;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _StartStopButton({
    required this.isPolling,
    required this.hasSelection,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    if (isPolling) {
      return ElevatedButton.icon(
        onPressed: onStop,
        icon: const Icon(Icons.stop_rounded, size: 18),
        label: const Text('Stop'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentRed,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: hasSelection ? onStart : null,
      icon: const Icon(Icons.play_arrow_rounded, size: 18),
      label: const Text('Start'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Idle hint ────────────────────────────────────────────────────────────────

class _IdleHint extends StatelessWidget {
  final bool hasSelection;
  const _IdleHint({required this.hasSelection});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart_rounded,
              size: 52, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            hasSelection
                ? 'Tap Start to begin logging'
                : 'Select sensors below, then tap Start',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── PID group selector ───────────────────────────────────────────────────────

class _PidGroupSelector extends StatefulWidget {
  final Set<String> selectedPids;
  final Set<String> vehicleSupportedPidCodes;
  final void Function(String pid) onToggle;

  const _PidGroupSelector({
    required this.selectedPids,
    required this.vehicleSupportedPidCodes,
    required this.onToggle,
  });

  @override
  State<_PidGroupSelector> createState() => _PidGroupSelectorState();
}

class _PidGroupSelectorState extends State<_PidGroupSelector> {
  String _activeGroup = pidGroups.keys.first;

  @override
  Widget build(BuildContext context) {
    final pids = pidGroups[_activeGroup] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category tab row
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: pidGroups.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final group = pidGroups.keys.elementAt(i);
              final isActive = group == _activeGroup;
              return GestureDetector(
                onTap: () => setState(() => _activeGroup = group),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.accent.withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isActive ? AppTheme.accent : AppTheme.muted,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // PID chips for selected category
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: pids.map((pid) {
              final code = PidConstants.codeForName(pid) ?? pid;
              final isSupported = widget.vehicleSupportedPidCodes.isEmpty ||
                  widget.vehicleSupportedPidCodes
                      .contains(code.toUpperCase());
              final isSelected = widget.selectedPids.contains(pid);
              final colorIdx = _allPids.indexOf(pid);
              final chipColor = _chipColor(colorIdx);
              final label = _shortName(pid);

              return FilterChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: isSelected,
                onSelected: isSupported ? (_) => widget.onToggle(pid) : null,
                selectedColor: chipColor.withValues(alpha: 0.2),
                checkmarkColor: chipColor,
                side: BorderSide(
                  color: isSelected
                      ? chipColor
                      : isSupported
                          ? const Color(0xFF3A3A40)
                          : const Color(0xFF252528),
                ),
                backgroundColor: const Color(0xFF1A1A1F),
                disabledColor: const Color(0xFF1A1A1F),
                labelStyle: TextStyle(
                  color: isSelected
                      ? chipColor
                      : isSupported
                          ? AppTheme.muted
                          : const Color(0xFF3A3A3A),
                ),
                tooltip: isSupported
                    ? '${PidConstants.nameFor(code)} · ${PidConstants.unitFor(code)}'
                    : 'Not supported by this vehicle',
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Flat ordered list of all PID names across all groups — used for color assignment.
final _allPids =
    pidGroups.values.expand((pids) => pids).toList();

const _palette = [
  Color(0xFFE8B84B),
  Color(0xFF4CAF82),
  Color(0xFF5B9CF6),
  Color(0xFFCF4747),
  Color(0xFFB86BE8),
  Color(0xFFE8724B),
  Color(0xFF4BE8D8),
  Color(0xFFE84BAA),
  Color(0xFFD4E84B),
  Color(0xFF4B8BE8),
  Color(0xFFE8C44B),
  Color(0xFF82CF4C),
];

Color _chipColor(int index) =>
    _palette[(index < 0 ? 0 : index) % _palette.length];

String _shortName(String pid) {
  const overrides = {
    'coolant_temp': 'Coolant',
    'stft_b1': 'STFT B1',
    'ltft_b1': 'LTFT B1',
    'stft_b2': 'STFT B2',
    'ltft_b2': 'LTFT B2',
    'engine_load': 'Load',
    'o2_b1s1': 'O2 ↑B1',
    'o2_b1s2': 'O2 ↓B1',
    'iat': 'IAT',
    'throttle': 'TPS',
    'egr_commanded': 'EGR',
    'baro_pressure': 'Baro',
    'oil_temp': 'Oil °C',
    'engine_run_time': 'Run Time',
    'distance_mil_on': 'MIL km',
    'fuel_pressure': 'Fuel P',
    'fuel_level': 'Fuel %',
  };
  return overrides[pid] ?? pid.replaceAll('_', ' ');
}
