import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/obd/pid_constants.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/pid_value_tile.dart';
import '../connect/connect_provider.dart';

class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final _cmdController = TextEditingController();
  final _log = <_LogEntry>[];
  Timer? _liveTimer;
  bool _liveRunning = false;
  double? _rpm;
  double? _coolant;
  bool _loading = false;

  @override
  void dispose() {
    _liveTimer?.cancel();
    _cmdController.dispose();
    super.dispose();
  }

  Future<void> _sendCommand(String cmd) async {
    if (cmd.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(activeTransportProvider)
          .sendCommand(cmd.trim().toUpperCase());
      _addLog(cmd.toUpperCase(), response, isError: false);
    } catch (e) {
      _addLog(cmd.toUpperCase(), e.toString(), isError: true);
    } finally {
      setState(() => _loading = false);
    }
  }

  void _addLog(String cmd, String response, {required bool isError}) {
    setState(() {
      _log.insert(
          0, _LogEntry(cmd: cmd, response: response, isError: isError));
      if (_log.length > 100) _log.removeLast();
    });
  }

  void _toggleLive() {
    if (_liveRunning) {
      _liveTimer?.cancel();
      setState(() => _liveRunning = false);
      return;
    }
    setState(() => _liveRunning = true);
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollLive());
  }

  Future<void> _pollLive() async {
    final obd = ref.read(obdServiceProvider);
    try {
      final rpm = await obd.readPID(PidConstants.rpm);
      final coolant = await obd.readPID(PidConstants.coolantTemp);
      if (mounted) {
        setState(() {
          _rpm = rpm;
          _coolant = coolant;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OBD Debug'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/connect'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/intake'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Diagnostic'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live PID panel
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: PidValueTile(
                    label: 'RPM',
                    value: _rpm != null ? _rpm!.toStringAsFixed(0) : '--',
                    unit: 'RPM',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PidValueTile(
                    label: 'Coolant Temp',
                    value: _coolant != null
                        ? _coolant!.toStringAsFixed(1)
                        : '--',
                    unit: '°C',
                    valueColor: _coolant != null && _coolant! > 100
                        ? AppTheme.accentRed
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _toggleLive,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _liveRunning
                        ? AppTheme.accentRed
                        : AppTheme.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: Text(_liveRunning ? 'Stop' : 'Live'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Command input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cmdController,
                    decoration: const InputDecoration(
                      hintText: 'Enter AT or OBD command (e.g. ATZ, 010C)',
                      prefixIcon: Icon(Icons.terminal),
                    ),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 14),
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (v) {
                      _sendCommand(v);
                      _cmdController.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading
                      ? null
                      : () {
                          _sendCommand(_cmdController.text);
                          _cmdController.clear();
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
          // Quick commands
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final cmd in [
                  'ATZ',
                  'ATI',
                  '0100',
                  '010C',
                  '0105',
                  '010D',
                  '0104',
                  '03',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(cmd,
                          style:
                              const TextStyle(fontFamily: 'monospace')),
                      onPressed: () => _sendCommand(cmd),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Response log
          Expanded(
            child: _log.isEmpty
                ? Center(
                    child: Text('Send a command to see the response',
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _log.length,
                    itemBuilder: (context, i) => _LogTile(entry: _log[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogEntry {
  final String cmd;
  final String response;
  final bool isError;
  _LogEntry({required this.cmd, required this.response, required this.isError});
}

class _LogTile extends StatelessWidget {
  final _LogEntry entry;
  const _LogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('> ${entry.cmd}',
              style: const TextStyle(
                  color: AppTheme.accent,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            entry.response,
            style: TextStyle(
              color: entry.isError ? AppTheme.accentRed : AppTheme.muted,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
