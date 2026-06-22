import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/obd/simulated/fault_profile.dart';
import '../../core/obd/simulated/virtual_ecu.dart';
import '../../shared/theme.dart';
import 'connect_provider.dart';

/// Radio-list dialog used to pick a [FaultProfile] before starting a
/// simulated session.
Future<FaultProfile?> showFaultProfilePicker(BuildContext context) {
  return showDialog<FaultProfile>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Choose a scenario'),
      children: [
        for (final profile in FaultProfile.values)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(profile),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    profile.description,
                    style: TextStyle(
                        fontSize: 12.5, color: AppTheme.muted, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// Opens the live driver-controls bottom sheet for the running virtual ECU.
void showSimulatorControlPanel(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const SimulatorControlPanelSheet(),
  );
}

/// Live controls for the virtual ECU: throttle, target speed, warm-up
/// fast-forward, and a fault-profile switch — the simulated equivalent of
/// actually driving the car to satisfy a test's condition expression.
class SimulatorControlPanelSheet extends ConsumerStatefulWidget {
  const SimulatorControlPanelSheet({super.key});

  @override
  ConsumerState<SimulatorControlPanelSheet> createState() =>
      _SimulatorControlPanelSheetState();
}

class _SimulatorControlPanelSheetState
    extends ConsumerState<SimulatorControlPanelSheet> {
  Timer? _refreshTimer;
  bool _snapping = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _snapThrottle() async {
    setState(() => _snapping = true);
    await ref.read(simulatedElm327Provider).ecu.snapThrottle();
    if (mounted) setState(() => _snapping = false);
  }

  @override
  Widget build(BuildContext context) {
    final connector = ref.watch(simulatedElm327Provider);
    final ecu = connector.ecu;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text('Simulator Controls',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),

            _readout(ecu),
            const SizedBox(height: 20),

            Text('Throttle', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: ecu.throttlePct,
              max: 100,
              activeColor: AppTheme.accent,
              label: '${ecu.throttlePct.round()}%',
              onChanged: (v) => setState(() => ecu.setThrottle(v)),
            ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _snapping ? null : _snapThrottle,
                icon: const Icon(Icons.bolt, size: 16),
                label: Text(_snapping ? 'Snapping…' : 'Snap Throttle'),
              ),
            ),

            const SizedBox(height: 16),
            Text('Target speed (km/h)',
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: ecu.targetSpeedKph,
              max: 140,
              activeColor: AppTheme.accent,
              label: '${ecu.targetSpeedKph.round()} km/h',
              onChanged: (v) => setState(() => ecu.setTargetSpeed(v)),
            ),

            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fast-forward warm-up'),
              subtitle: const Text('Speeds up coolant warm-up ~5x',
                  style: TextStyle(fontSize: 12)),
              activeThumbColor: AppTheme.accent,
              value: ecu.warmupFastForward,
              onChanged: (v) => setState(() => ecu.setWarmupFastForward(v)),
            ),

            const SizedBox(height: 8),
            Text('Fault scenario',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final profile in FaultProfile.values)
                  ChoiceChip(
                    label: Text(profile.label, style: const TextStyle(fontSize: 12)),
                    selected: ecu.fault == profile,
                    selectedColor: AppTheme.accent.withAlpha(40),
                    onSelected: (_) => setState(() => ecu.setFault(profile)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _readout(VirtualEcu ecu) {
    return Row(
      children: [
        _metric('RPM', ecu.rpm.toStringAsFixed(0)),
        _metric('Coolant', '${ecu.coolantTemp.toStringAsFixed(0)}°C'),
        _metric('Speed', '${ecu.speedKph.toStringAsFixed(0)} km/h'),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
