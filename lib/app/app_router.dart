import 'package:go_router/go_router.dart';

import '../features/connections/connections_page.dart';
import '../features/devices/devices_page.dart';
import '../features/home/home_page.dart';
import '../features/proxies/proxies_page.dart';
import '../features/servers/servers_page.dart';
import '../features/settings/settings_page.dart';
import '../features/setup/setup_page.dart';
import 'dashboard_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/setup',
  routes: <RouteBase>[
    GoRoute(
      path: '/setup',
      builder: (context, state) =>
          SetupPage(panelOnly: state.uri.queryParameters['panel'] == '1'),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          DashboardShell(location: state.uri.path, child: child),
      routes: <RouteBase>[
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/proxies',
          builder: (context, state) => const ProxiesPage(),
        ),
        GoRoute(
          path: '/servers',
          builder: (context, state) => const ServersPage(),
        ),
        GoRoute(
          path: '/connections',
          builder: (context, state) => const ConnectionsPage(),
        ),
        GoRoute(
          path: '/devices',
          builder: (context, state) => const DevicesPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
