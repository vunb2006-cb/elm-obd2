import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/theme.dart';
import 'intake_provider.dart';

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
  final _complaintCtrl = TextEditingController();
  final _repairsCtrl = TextEditingController();

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _engineCtrl.dispose();
    _odomCtrl.dispose();
    _complaintCtrl.dispose();
    _repairsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(intakeProvider.notifier).setIntake(
          make: _makeCtrl.text.trim(),
          model: _modelCtrl.text.trim(),
          year: int.parse(_yearCtrl.text.trim()),
          engine: _engineCtrl.text.trim(),
          odometer: int.tryParse(_odomCtrl.text.trim()) ?? 0,
          complaint: _complaintCtrl.text.trim(),
          recentRepairs: _repairsCtrl.text.trim().isEmpty
              ? null
              : _repairsCtrl.text.trim(),
        );
    context.go('/session');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Information')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            _sectionLabel(context, 'Driver Complaint'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _complaintCtrl,
              decoration: const InputDecoration(
                hintText:
                    'Describe the problem in detail — when it happens, under what conditions, how long it has been happening...',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please describe the issue'
                  : null,
            ),
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
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Diagnostic Session'),
            ),
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
