import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/intake_repository.dart';

final intakeRepositoryProvider = Provider<IntakeRepository>((ref) {
  return IntakeRepository();
});

final savedVehicleProvider = FutureProvider<SavedVehicleProfile?>((ref) async {
  final repo = ref.watch(intakeRepositoryProvider);
  await repo.init();
  return repo.loadVehicle();
});
