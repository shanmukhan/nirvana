import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/repository_providers.dart';
import '../../providers/water_providers.dart';
import '../screen_scaffold.dart';

/// Opened by tapping the water reminder notification (requirements §6):
/// a focused quick-log screen so drinking water can be recorded straight
/// from the notification without navigating into the full Water screen.
class WaterLogScreen extends ConsumerStatefulWidget {
  const WaterLogScreen({super.key});

  @override
  ConsumerState<WaterLogScreen> createState() => _WaterLogScreenState();
}

class _WaterLogScreenState extends ConsumerState<WaterLogScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _log(int amountMl) async {
    await ref.read(waterRepositoryProvider).log(amountMl);
    ref.read(waterRefreshProvider.notifier).state++;
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final hydrationConfigAsync = ref.watch(hydrationConfigProvider);
    return ScreenScaffold(
      title: 'Log water',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How much did you drink?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            hydrationConfigAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Could not load quick-log amounts: $e'),
              data: (config) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final amount in config.quickLogAmountsMl)
                    FilledButton.tonal(
                      onPressed: () => _log(amount),
                      child: Text('+$amount ml'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Custom amount (ml)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final amount = int.tryParse(_controller.text.trim());
                    if (amount == null || amount <= 0) return;
                    _log(amount);
                  },
                  child: const Text('Log'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
