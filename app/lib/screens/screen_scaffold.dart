import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell/nav_destinations.dart';
import '../theme/app_theme.dart';

/// Shared chrome for every top-level screen: an app bar with the screen
/// title and a drawer listing all 10 v1 screens (PROJECT_PLAN.md §5).
class ScreenScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const ScreenScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: const NirvanaDrawer(),
      body: body,
    );
  }
}

class NirvanaDrawer extends StatelessWidget {
  const NirvanaDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final topInset = MediaQuery.of(context).padding.top;
    return Drawer(
      backgroundColor: NirvanaColors.barGreen,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 20),
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/nirvana_icon.png',
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nirvana',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Your daily wellness companion',
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (final destination in navDestinations)
            _DrawerItem(
              destination: destination,
              selected: currentRoute == destination.path,
              onTap: () {
                Navigator.of(context).pop();
                if (currentRoute != destination.path) {
                  context.go(destination.path);
                }
              },
            ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({required this.destination, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(destination.icon, color: Colors.white),
        title: Text(destination.label, style: const TextStyle(color: Colors.white)),
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        onTap: onTap,
      ),
    );
  }
}
