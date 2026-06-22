import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Last vehicle details and complaint, pre-filled on the next intake visit.
class SavedVehicleProfile {
  final String make;
  final String model;
  final int year;
  final String engine;
  final int odometer;
  final String? lastComplaint;

  const SavedVehicleProfile({
    required this.make,
    required this.model,
    required this.year,
    required this.engine,
    required this.odometer,
    this.lastComplaint,
  });

  Map<String, dynamic> toJson() => {
        'make': make,
        'model': model,
        'year': year,
        'engine': engine,
        'odometer': odometer,
        if (lastComplaint != null) 'lastComplaint': lastComplaint,
      };

  factory SavedVehicleProfile.fromJson(Map<String, dynamic> json) {
    return SavedVehicleProfile(
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      engine: json['engine'] as String? ?? '',
      odometer: json['odometer'] as int? ?? 0,
      lastComplaint: json['lastComplaint'] as String?,
    );
  }
}

class IntakeRepository {
  static const _boxName = 'intake';
  static const _vehicleKey = 'lastVehicle';

  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  SavedVehicleProfile? loadVehicle() {
    final raw = _box.get(_vehicleKey);
    if (raw == null) return null;
    try {
      return SavedVehicleProfile.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveVehicle(SavedVehicleProfile profile) async {
    await _box.put(_vehicleKey, jsonEncode(profile.toJson()));
  }
}
