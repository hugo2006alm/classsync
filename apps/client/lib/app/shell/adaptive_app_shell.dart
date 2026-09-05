import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  static const _destinations = <_Destination>[
    _Destination('Overview', Icons.home_rounded, '/overview'),
    _Destination('Classes', Icons.school_rounded, '/classes'),
    _Destination('Sync', Icons.sync_rounded, '/sync'),
    _Destination('Settings', Icons.tune_rounded, '/settings'),
  ];

  int get _selectedIndex {
    final index = _destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 760;
      if (!desktop) {
        return Scaffold(
          body: SafeArea(bottom: false, child: child),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                context.go(_destinations[index].path),
            destinations: _destinations
                .map(
                  (destination) => NavigationDestination(
                    icon: Icon(destination.icon),
                    label: destination.label,
                  ),
                )
                .toList(),
          ),
        );
      }
      final extended = constraints.maxWidth >= 1080;
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                extended: extended,
                minExtendedWidth: 248,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    context.go(_destinations[index].path),
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 28),
                  child: _BrandMark(showName: extended),
                ),
                destinations: _destinations
                    .map(
                      (destination) => NavigationRailDestination(
                        icon: Icon(destination.icon),
                        label: Text(destination.label),
                      ),
                    )
                    .toList(),
              ),
            ),
            VerticalDivider(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(child: SafeArea(left: false, child: child)),
          ],
        ),
      );
    },
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.showName});
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.auto_stories_rounded,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 12),
          Text('ClassSync', style: Theme.of(context).textTheme.titleLarge),
        ],
      ],
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
