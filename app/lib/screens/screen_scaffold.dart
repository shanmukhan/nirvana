import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_shell/nav_destinations.dart';

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
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Nirvana',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          for (final destination in navDestinations)
            ListTile(
              leading: Icon(destination.icon),
              title: Text(destination.label),
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
