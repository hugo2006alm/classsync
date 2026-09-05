import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/classes/classes_screen.dart';
import '../../features/classes/class_detail_screen.dart';
import '../../features/overview/overview_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sync/job_detail_screen.dart';
import '../../features/sync/sync_screen.dart';
import '../shell/adaptive_app_shell.dart';

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/overview',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AdaptiveAppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/overview',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: OverviewScreen()),
          ),
          GoRoute(
            path: '/classes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ClassesScreen()),
            routes: [
              GoRoute(
                path: ':subjectId',
                builder: (context, state) => ClassDetailScreen(
                  subjectId: state.pathParameters['subjectId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/sync',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SyncScreen()),
            routes: [
              GoRoute(
                path: ':jobId',
                builder: (context, state) =>
                    JobDetailScreen(jobId: state.pathParameters['jobId']!),
              ),
            ],
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
        ],
      ),
    ],
  ),
);
