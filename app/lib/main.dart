import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_shell/router.dart';
import 'data/db/app_database.dart';
import 'providers/repository_providers.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.instance();
  await NotificationService.instance.init();
  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const NirvanaApp(),
    ),
  );
}

class NirvanaApp extends ConsumerWidget {
  const NirvanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Bootstraps the default UserProfile/RoutineConfig and exercise
    // library on first launch; screens read live data independently of
    // this completing, so we don't gate the UI on it.
    ref.watch(userProfileProvider);

    return MaterialApp.router(
      title: 'Nirvana',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
