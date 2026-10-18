import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/water_providers.dart';
import '../screen_scaffold.dart';
import 'water_log_actions.dart';

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
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _log(int amountMl) async {
    final saved = await saveWater(context, ref, amountMl);
    if (saved && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final hydrationConfigAsync = ref.watch(hydrationConfigProvider);
    return ScreenScaffold(
      title: 'Log water',
      body: SingleChildScrollView(
        child: Padding(
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
                        onPressed: ref.watch(waterSavingProvider) ? null : () => _log(amount),
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
                      decoration: InputDecoration(
                        errorText: _error,
                        labelText: 'Custom amount (ml)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: ref.watch(waterSavingProvider)
                        ? null
                        : () {
                            final amount = int.tryParse(_controller.text.trim());
                            if (amount == null || amount <= 0) {
                              setState(() => _error = 'Enter an amount greater than zero.');
                              return;
                            }
                            setState(() => _error = null);
                            _log(amount);
                          },
                    child: const Text('Log'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
