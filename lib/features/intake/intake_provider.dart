import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/obd/models/dtc_code.dart';

class IntakeData {
  final String vehicleMake;
  final String vehicleModel;
  final int vehicleYear;
  final String engineDisplacement;
  final int odometer;
  final List<DtcCode> dtcs;
  final Map<String, double> freezeFrame;
  final List<String> supportedPids;
  final String driverComplaint;
  final String? recentRepairs;

  const IntakeData({
    required this.vehicleMake,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.engineDisplacement,
    required this.odometer,
    required this.dtcs,
    required this.freezeFrame,
    required this.supportedPids,
    required this.driverComplaint,
    this.recentRepairs,
  });

  /// Format as a structured text block for the Gemini prompt.
  String toPromptText() {
    final sb = StringBuffer();
    sb.writeln('=== VEHICLE INFORMATION ===');
    sb.writeln('Make/Model: $vehicleYear $vehicleMake $vehicleModel');
    if (engineDisplacement.isNotEmpty) {
      sb.writeln('Engine: $engineDisplacement');
    }
    if (odometer > 0) sb.writeln('Odometer: ${odometer}km');

    sb.writeln('\n=== FAULT CODES ===');
    if (dtcs.isEmpty) {
      sb.writeln('No stored fault codes.');
    } else {
      for (final dtc in dtcs) {
        sb.writeln(
            '${dtc.isPending ? "[PENDING] " : ""}${dtc.code}${dtc.description != null ? " — ${dtc.description}" : ""}');
      }
    }

    if (freezeFrame.isNotEmpty) {
      sb.writeln('\n=== FREEZE FRAME DATA ===');
      for (final entry in freezeFrame.entries) {
        sb.writeln('${entry.key}: ${entry.value.toStringAsFixed(2)}');
      }
    }

    sb.writeln('\n=== DRIVER COMPLAINT ===');
    sb.writeln(driverComplaint);

    if (recentRepairs != null && recentRepairs!.isNotEmpty) {
      sb.writeln('\n=== RECENT REPAIRS ===');
      sb.writeln(recentRepairs);
    }

    sb.writeln('\n=== SUPPORTED PIDs ===');
    sb.writeln(supportedPids.join(', '));

    return sb.toString();
  }
}

class IntakeNotifier extends StateNotifier<IntakeData?> {
  IntakeNotifier() : super(null);

  void setIntake({
    required String make,
    required String model,
    required int year,
    required String engine,
    required int odometer,
    required String complaint,
    String? recentRepairs,
    List<DtcCode> dtcs = const [],
    Map<String, double> freezeFrame = const {},
    List<String> supportedPids = const [],
  }) {
    state = IntakeData(
      vehicleMake: make,
      vehicleModel: model,
      vehicleYear: year,
      engineDisplacement: engine,
      odometer: odometer,
      dtcs: dtcs,
      freezeFrame: freezeFrame,
      supportedPids: supportedPids,
      driverComplaint: complaint,
      recentRepairs: recentRepairs,
    );
  }

  void updateDtcs(List<DtcCode> dtcs) {
    if (state == null) return;
    state = IntakeData(
      vehicleMake: state!.vehicleMake,
      vehicleModel: state!.vehicleModel,
      vehicleYear: state!.vehicleYear,
      engineDisplacement: state!.engineDisplacement,
      odometer: state!.odometer,
      dtcs: dtcs,
      freezeFrame: state!.freezeFrame,
      supportedPids: state!.supportedPids,
      driverComplaint: state!.driverComplaint,
      recentRepairs: state!.recentRepairs,
    );
  }

  void updateFreezeFrame(Map<String, double> ff) {
    if (state == null) return;
    state = IntakeData(
      vehicleMake: state!.vehicleMake,
      vehicleModel: state!.vehicleModel,
      vehicleYear: state!.vehicleYear,
      engineDisplacement: state!.engineDisplacement,
      odometer: state!.odometer,
      dtcs: state!.dtcs,
      freezeFrame: ff,
      supportedPids: state!.supportedPids,
      driverComplaint: state!.driverComplaint,
      recentRepairs: state!.recentRepairs,
    );
  }

  void updateSupportedPids(List<String> pids) {
    if (state == null) return;
    state = IntakeData(
      vehicleMake: state!.vehicleMake,
      vehicleModel: state!.vehicleModel,
      vehicleYear: state!.vehicleYear,
      engineDisplacement: state!.engineDisplacement,
      odometer: state!.odometer,
      dtcs: state!.dtcs,
      freezeFrame: state!.freezeFrame,
      supportedPids: pids,
      driverComplaint: state!.driverComplaint,
      recentRepairs: state!.recentRepairs,
    );
  }
}

final intakeProvider =
    StateNotifierProvider<IntakeNotifier, IntakeData?>((ref) {
  return IntakeNotifier();
});
