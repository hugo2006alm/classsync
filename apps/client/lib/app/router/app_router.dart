import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/classes/classes_screen.dart';
import '../../features/classes/class_detail_screen.dart';
import '../../features/overview/overview_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/academic/academic_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/sync/job_detail_screen.dart';
import '../../features/sync/sync_screen.dart';
import '../shell/adaptive_app_shell.dart';

final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/overview',
    routes: [
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AdaptiveAppShell(
          location: state.uri.path,
          onNavigate: (path) {
            _shellNavigatorKey.currentState?.popUntil((route) => route.isFirst);
            context.go(path);
          },
          child: child,
        ),
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
                pageBuilder: (context, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: ClassDetailScreen(
                    subjectId: state.pathParameters['subjectId']!,
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/academic',
            pageBuilder: (context, state) => NoTransitionPage(
              child: AcademicScreen(
                initialSection:
                    int.tryParse(state.uri.queryParameters['section'] ?? '') ??
                    0,
              ),
            ),
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
            path: '/library',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LibraryScreen()),
            routes: [
              GoRoute(
                path: ':pageId',
                builder: (context, state) => LibraryDetailScreen(
                  pageId: state.pathParameters['pageId']!,
                  title: state.uri.queryParameters['title'] ?? 'Lecture notes',
                  notionUrl: state.uri.queryParameters['url'],
                ),
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
