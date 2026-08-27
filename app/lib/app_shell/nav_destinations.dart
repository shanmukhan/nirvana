import 'package:flutter/material.dart';

/// The 10 v1 screens, in the order defined by PROJECT_PLAN.md §5.
class NavDestination {
  final String path;
  final String label;
  final IconData icon;

  const NavDestination({
    required this.path,
    required this.label,
    required this.icon,
  });
}

const List<NavDestination> navDestinations = [
  NavDestination(path: '/', label: 'Dashboard', icon: Icons.dashboard_outlined),
  NavDestination(path: '/water', label: 'Water', icon: Icons.water_drop_outlined),
  NavDestination(path: '/exercise', label: 'Exercise', icon: Icons.fitness_center_outlined),
  NavDestination(path: '/food', label: 'Food', icon: Icons.restaurant_outlined),
  NavDestination(path: '/weight', label: 'Weight', icon: Icons.monitor_weight_outlined),
  NavDestination(path: '/knee', label: 'Knee', icon: Icons.accessibility_new_outlined),
  NavDestination(path: '/desk-breaks', label: 'Desk Breaks', icon: Icons.chair_outlined),
  NavDestination(path: '/dhyana', label: 'Dhyana', icon: Icons.self_improvement_outlined),
  NavDestination(path: '/progress', label: 'Progress / History', icon: Icons.show_chart_outlined),
  NavDestination(path: '/settings', label: 'Settings', icon: Icons.settings_outlined),
];
