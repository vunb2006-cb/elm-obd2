import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/obd/elm327_connector.dart';
import '../../core/obd/models/dtc_code.dart';
import '../../core/storage/intake_repository.dart';
import '../../shared/theme.dart';
import '../connect/connect_provider.dart';
import 'intake_provider.dart';
import 'intake_repository_provider.dart';

const _conditionChips = [
  'At idle',
  'Under acceleration',
  'Only when cold',
  'Check engine light on',
  'At highway speed',
];

class IntakeScreen extends ConsumerStatefulWidget {
  const IntakeScreen({super.key});

  @override
  ConsumerState<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends ConsumerState<IntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _odomCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _whenCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  final _repairsCtrl = TextEditingController();

  final Set<String> _selectedChips = {};
  String? _gettingWorse;
  bool _sameIssueAsLast = false;
  String? _lastComplaint;

  bool _dtcLoading = false;
  List<DtcCode> _previewDtcs = [];
  String? _dtcError;
  bool _vehicleLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedVehicle();
      _loadDtcPreview();
    });
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _engineCtrl.dispose();
    _odomCtrl.dispose();
    _summaryCtrl.dispose();
    _whenCtrl.dispose();
    _durationCtrl.dispose();
    _extraCtrl.dispose();
    _repairsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedVehicle() async {
    final repo = ref.read(intakeRepositoryProvider);
    await repo.init();
    final saved = repo.loadVehicle();
    if (!mounted || saved == null) return;
    setState(() {
      _makeCtrl.text = saved.make;
      _modelCtrl.text = saved.model;
      if (saved.year > 0) _yearCtrl.text = saved.year.toString();
      _engineCtrl.text = saved.engine;
      if (saved.odometer > 0) _odomCtrl.text = saved.odometer.toString();
      _lastComplaint = saved.lastComplaint;
      _vehicleLoaded = true;
    });
  }

  Future<void> _loadDtcPreview() async {
    final transport = ref.read(activeTransportProvider);
    if (!transport.isConnected) {
      setState(() {
        _dtcLoading = false;
        _previewDtcs = [];
        _dtcError = null;
      });
      return;
    }

    setState(() {
      _dtcLoading = true;
      _dtcError = null;
    });

    try {
      final obd = ref.read(obdServiceProvider);
      final dtcs = await obd.readDTCs();
      if (!mounted) return;
      setState(() {
        _dtcLoading = false;
        _previewDtcs = dtcs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dtcLoading = false;
        _dtcError = 'Could not read codes — will retry when the session starts';
      });
    }
  }

  String _buildComplaint() {
    if (_sameIssueAsLast && _lastComplaint != null && _lastComplaint!.isNotEmpty) {
      return _lastComplaint!;
    }

    final lines = <String>[_summaryCtrl.text.trim()];

    if (_selectedChips.isNotEmpty) {
      lines.add('Conditions: ${_selectedChips.join(', ')}');
    }
    final when = _whenCtrl.text.trim();
    if (when.isNotEmpty) lines.add('When: $when');
    final duration = _durationCtrl.text.trim();
    if (duration.isNotEmpty) lines.add('Duration: $duration');
    if (_gettingWorse != null) lines.add('Getting worse: $_gettingWorse');
    final extra = _extraCtrl.text.trim();
    if (extra.isNotEmpty) lines.add('Additional detail: $extra');

    return lines.join('\n');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final complaint = _buildComplaint();
    if (complaint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what is wrong')),
      );
      return;
    }

    ref.read(intakeProvider.notifier).setIntake(
          make: _makeCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          year: int.parse(_yearCtrl.text.trim()),
          engine: _engineCtrl.text.trim(),
          odometer: int.tryParse(_odomCtrl.text.trim()) ?? 0,
          complaint: complaint,
          recentRepairs: _repairsCtrl.text.trim().isEmpty
              ? null
              : _repairsCtrl.text.trim(),
          dtcs: _previewDtcs,
        );

    final repo = ref.read(intakeRepositoryProvider);
    await repo.init();
    await repo.saveVehicle(
      SavedVehicleProfile(
        make: _makeCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        year: int.parse(_yearCtrl.text.trim()),
        engine: _engineCtrl.text.trim(),
        odometer: int.tryParse(_odomCtrl.text.trim()) ?? 0,
        lastComplaint: complaint,
      ),
    );

    if (!mounted) return;
    context.push('/session');
  }

  void _toggleChip(String chip) {
    setState(() {
      if (_selectedChips.contains(chip)) {
        _selectedChips.remove(chip);
      } else {
        _selectedChips.add(chip);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(connectionStateProvider).valueOrNull;
    final isSimulating = ref.watch(isSimulatingProvider);
    final isConnected = connState == Elm327State.connected;

    ref.listen(connectionStateProvider, (prev, next) {
      final wasConnected = prev?.valueOrNull == Elm327State.connected;
      final nowConnected = next.valueOrNull == Elm327State.connected;
      if (wasConnected != nowConnected) _loadDtcPreview();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Information')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (isConnected) ...[
              _ConnectionBanner(isSimulating: isSimulating),
              const SizedBox(height: 12),
              _DtcPreviewBanner(
                loading: _dtcLoading,
                codes: _previewDtcs,
                error: _dtcError,
                onRetry: _loadDtcPreview,
              ),
              const SizedBox(height: 20),
            ],

            if (_vehicleLoaded) ...[
              _PrefillHint(onClear: () {
                setState(() {
                  _makeCtrl.clear();
                  _modelCtrl.clear();
                  _yearCtrl.clear();
                  _engineCtrl.clear();
                  _odomCtrl.clear();
                  _vehicleLoaded = false;
                });
              }),
              const SizedBox(height: 12),
            ],

            _sectionLabel(context, 'Vehicle Details'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _makeCtrl,
                    label: 'Make',
                    hint: 'Toyota',
                    required: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _modelCtrl,
                    label: 'Model',
                    hint: 'Camry',
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    controller: _yearCtrl,
                    label: 'Year',
                    hint: '2018',
                    required: true,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1996 || n > 2030) {
                        return 'Enter valid year (1996–2030)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    controller: _engineCtrl,
                    label: 'Engine',
                    hint: '2.5L 4-cyl',
                    required: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field(
              controller: _odomCtrl,
              label: 'Odometer (km)',
              hint: '85000',
              required: false,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            _sectionLabel(context, 'What\'s wrong?'),
            const SizedBox(height: 8),
            Text(
              'A clear symptom helps pick the right tests first.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
            ),
            const SizedBox(height: 12),

            if (_lastComplaint != null && _lastComplaint!.isNotEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Same issue as last session'),
                subtitle: Text(
                  _lastComplaint!.split('\n').first,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.muted),
                ),
                value: _sameIssueAsLast,
                onChanged: (v) => setState(() => _sameIssueAsLast = v ?? false),
              ),

            if (!_sameIssueAsLast) ...[
              _field(
                controller: _summaryCtrl,
                label: 'Main symptom',
                hint: 'e.g. rough idle, hesitation on acceleration',
                required: true,
              ),
              const SizedBox(height: 12),
              Text(
                'When does it happen?',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in _conditionChips)
                    FilterChip(
                      label: Text(chip),
                      selected: _selectedChips.contains(chip),
                      onSelected: (_) => _toggleChip(chip),
                      selectedColor: AppTheme.accent.withAlpha(40),
                      checkmarkColor: AppTheme.accent,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _whenCtrl,
                label: 'When (optional)',
                hint: 'e.g. only after 10 minutes of driving',
                required: false,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _durationCtrl,
                label: 'How long? (optional)',
                hint: 'e.g. 2 weeks, since last oil change',
                required: false,
              ),
              const SizedBox(height: 12),
              Text(
                'Getting worse?',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final option in ['Yes', 'No', 'Not sure'])
                    ChoiceChip(
                      label: Text(option),
                      selected: _gettingWorse == option,
                      onSelected: (selected) {
                        setState(() {
                          _gettingWorse = selected ? option : null;
                        });
                      },
                      selectedColor: AppTheme.accent.withAlpha(40),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extraCtrl,
                decoration: const InputDecoration(
                  labelText: 'Anything else? (optional)',
                  hintText: 'Noises, smells, recent changes…',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
            ],

            const SizedBox(height: 24),
            _sectionLabel(context, 'Recent Repairs (optional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _repairsCtrl,
              decoration: const InputDecoration(
                hintText: 'Any recent work done on the vehicle?',
                alignLabelWithHint: true,
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 24),
            Text(
              isConnected
                  ? 'We\'ll refresh fault codes and sensor data, then suggest tests to run.'
                  : 'Connect an OBD adapter for live codes — or continue and scan at session start.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Diagnostic Session'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.accent,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType: keyboardType,
      validator: validator ??
          (required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
              : null),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  final bool isSimulating;
  const _ConnectionBanner({required this.isSimulating});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentGreen.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(
            isSimulating ? Icons.smart_toy_outlined : Icons.bluetooth_connected,
            color: AppTheme.accentGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSimulating ? 'Simulated vehicle connected' : 'OBD adapter connected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.accentGreen,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DtcPreviewBanner extends StatelessWidget {
  final bool loading;
  final List<DtcCode> codes;
  final String? error;
  final VoidCallback onRetry;

  const _DtcPreviewBanner({
    required this.loading,
    required this.codes,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String message;

    if (loading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A30)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Reading fault codes…'),
          ],
        ),
      );
    }

    if (error != null) {
      borderColor = AppTheme.accentRed.withAlpha(80);
      bgColor = AppTheme.accentRed.withAlpha(20);
      textColor = AppTheme.accentRed;
      icon = Icons.warning_amber_rounded;
      message = error!;
    } else if (codes.isEmpty) {
      borderColor = const Color(0xFF2A2A30);
      bgColor = AppTheme.surface;
      textColor = AppTheme.muted;
      icon = Icons.check_circle_outline;
      message = 'No fault codes stored';
    } else {
      borderColor = AppTheme.accent.withAlpha(80);
      bgColor = AppTheme.accent.withAlpha(20);
      textColor = AppTheme.accent;
      icon = Icons.error_outline;
      final codeList = codes.map((c) => c.code).join(', ');
      message = codes.length == 1
          ? '1 code found — $codeList'
          : '${codes.length} codes found — $codeList';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.35,
                  ),
            ),
          ),
          if (error != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _PrefillHint extends StatelessWidget {
  final VoidCallback onClear;
  const _PrefillHint({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 18, color: AppTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Loaded your last vehicle — update if needed',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.muted),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
