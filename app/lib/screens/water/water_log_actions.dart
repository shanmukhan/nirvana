import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../providers/water_providers.dart';

final waterSavingProvider = StateProvider.autoDispose<bool>((ref) => false);

Future<bool> saveWater(BuildContext context, WidgetRef ref, int amount) async {
  if (ref.read(waterSavingProvider)) return false;
  final saving = ref.read(waterSavingProvider.notifier);
  final repo = ref.read(waterRepositoryProvider);
  final refresh = ref.read(waterRefreshProvider.notifier);
  saving.state = true;
  try {
    await repo.log(amount);
    if (refresh.mounted) refresh.state++;
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save water. Your amount is kept; please try again.'),
        ),
      );
    }
    return false;
  } finally {
    if (saving.mounted) saving.state = false;
  }
}
