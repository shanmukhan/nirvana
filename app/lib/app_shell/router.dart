import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/navigation_input.dart';
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

/// Global navigator key so notification-tap handlers can navigate without
/// a BuildContext (see main.dart's notification response handler).
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Top-level navigation shell for the 10 v1 screens (PROJECT_PLAN.md §5)
/// plus notification-tap-to-log routes (requirements §4/§6).
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page unavailable')),
    body: Center(
      child: FilledButton.icon(
        onPressed: () => context.go('/'),
        icon: const Icon(Icons.home_outlined),
        label: const Text('Open Dashboard'),
      ),
    ),
  ),
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
      builder: (context, state) {
        final slot = parseDeskBreakSlot(
          state.pathParameters['type'],
          state.pathParameters['hour'],
          state.pathParameters['minute'],
        );
        if (slot == null) return const DeskBreaksScreen();
        final (type, hour, minute) = slot;
        final dateText = state.uri.queryParameters['date'];
        final date = parseActivityDate(dateText);
        if (dateText != null && date == null) return const DeskBreaksScreen();
        return DeskBreakLogScreen(
          key: ValueKey('${type.name}/$hour/$minute/$date'),
          type: type,
          hour: hour,
          minute: minute,
          logDate: date,
        );
      },
    ),
    GoRoute(path: '/dhyana', builder: (context, state) => const DhyanaScreen()),
    GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
    GoRoute(path: '/progress/weight', builder: (context, state) => const WeightTrendDetailScreen()),
    GoRoute(path: '/progress/knee', builder: (context, state) => const KneeTrendDetailScreen()),
    GoRoute(
      path: '/progress/day/:date',
      builder: (context, state) {
        final day = parseActivityDate(state.pathParameters['date']);
        return day == null ? const ProgressScreen() : DayActivityScreen(day: day);
      },
    ),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
