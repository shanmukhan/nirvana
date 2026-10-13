import 'package:flutter/material.dart';

class LoadRetry extends StatelessWidget {
  final VoidCallback onRetry;
  const LoadRetry({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      const Text('Could not load this data.'),
      TextButton(onPressed: onRetry, child: const Text('Retry')),
    ],
  );
}
