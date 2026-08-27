import 'package:go_router/go_router.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/deskbreaks/desk_breaks_screen.dart';
import '../screens/dhyana/dhyana_screen.dart';
import '../screens/exercise/exercise_screen.dart';
import '../screens/food/food_screen.dart';
import '../screens/knee/knee_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/water/water_screen.dart';
import '../screens/weight/weight_screen.dart';

/// Top-level navigation shell for the 10 v1 screens (PROJECT_PLAN.md §5).
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/water', builder: (context, state) => const WaterScreen()),
    GoRoute(path: '/exercise', builder: (context, state) => const ExerciseScreen()),
    GoRoute(path: '/food', builder: (context, state) => const FoodScreen()),
    GoRoute(path: '/weight', builder: (context, state) => const WeightScreen()),
    GoRoute(path: '/knee', builder: (context, state) => const KneeScreen()),
    GoRoute(path: '/desk-breaks', builder: (context, state) => const DeskBreaksScreen()),
    GoRoute(path: '/dhyana', builder: (context, state) => const DhyanaScreen()),
    GoRoute(path: '/progress', builder: (context, state) => const ProgressScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
