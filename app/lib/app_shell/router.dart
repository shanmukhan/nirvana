import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/deskbreaks/desk_break_log_screen.dart';
import '../screens/deskbreaks/desk_breaks_screen.dart';
import '../screens/dhyana/dhyana_screen.dart';
import '../screens/exercise/exercise_screen.dart';
import '../screens/food/food_screen.dart';
import '../screens/knee/knee_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/water/water_log_screen.dart';
import '../screens/water/water_screen.dart';
import '../screens/weight/weight_screen.dart';
import '../services/reminder_prefs.dart';

/// Global navigator key so notification-tap handlers can navigate without
/// a BuildContext (see main.dart's notification response handler).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Top-level navigation shell for the 10 v1 screens (PROJECT_PLAN.md §5)
/// plus notification-tap-to-log routes (requirements §4/§6).
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/water', builder: (context, state) => const WaterScreen()),
    GoRoute(path: '/water-log', builder: (context, state) => const WaterLogScreen()),
    GoRoute(path: '/exercise', builder: (context, state) => const ExerciseScreen()),
    GoRoute(path: '/food', builder: (context, state) => const FoodScreen()),
    GoRoute(path: '/weight', builder: (context, state) => const WeightScreen()),
    GoRoute(path: '/knee', builder: (context, state) => const KneeScreen()),
    GoRoute(path: '/desk-breaks', builder: (context, state) => const DeskBreaksScreen()),
    GoRoute(
      path: '/desk-break-log/:type/:hour/:minute',
      builder: (context, state) => DeskBreakLogScreen(
        type: DeskBreakType.values.byName(state.pathParameters['type']!),
        hour: int.parse(state.pathParameters['hour']!),
        minute: int.parse(state.pathParameters['minute']!),
      ),
    ),
    GoRoute(path: '/dhyana', builder: (context, state) => const DhyanaScreen()),
    GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
