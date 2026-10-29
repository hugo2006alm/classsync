import '../../domain/settings/app_settings.dart';

/// Legacy login entries used --background. Keep them compatible during upgrades.
bool isDesktopStartup(List<String> arguments) =>
    arguments.contains('--startup') || arguments.contains('--background');

bool shouldStartHidden(List<String> arguments, AppSettings settings) =>
    isDesktopStartup(arguments) &&
    settings.setupComplete &&
    settings.startMinimized;
