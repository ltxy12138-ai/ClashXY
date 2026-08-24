import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _destinations = <({String path, IconData icon})>[
    (path: '/home', icon: Icons.power_settings_new_rounded),
    (path: '/proxies', icon: Icons.hub_rounded),
    (path: '/servers', icon: Icons.inventory_2_rounded),
    (path: '/connections', icon: Icons.swap_horiz_rounded),
    (path: '/devices', icon: Icons.devices_rounded),
    (path: '/settings', icon: Icons.tune_rounded),
  ];

  int get _index {
    final index = _destinations.indexWhere(
      (item) => location.startsWith(item.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.navHome,
      l10n.navProxies,
      l10n.navProfiles,
      l10n.navConnections,
      l10n.navDevices,
      l10n.navSettings,
    ];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (index) =>
                      context.go(_destinations[index].path),
                  extended: constraints.maxWidth >= 1040,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Icon(Icons.shield_moon_rounded, size: 34),
                  ),
                  destinations: _destinations.indexed
                      .map(
                        (entry) => NavigationRailDestination(
                          icon: Icon(entry.$2.icon),
                          label: Text(labels[entry.$1]),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: child),
              ],
            );
          }
          return child;
        },
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 760
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) =>
                  context.go(_destinations[index].path),
              destinations: _destinations.indexed
                  .map(
                    (entry) => NavigationDestination(
                      icon: Icon(entry.$2.icon),
                      label: labels[entry.$1],
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }
}
