import 'package:classsync/app/theme/classsync_theme.dart';
import 'package:classsync/features/setup/setup_wizard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wide setup explains prerequisites and shows syllabus', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 820);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());

    expect(find.text('SETUP SYLLABUS'), findsOneWidget);
    expect(find.text('Have these four things ready'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(
      find.text(
        'Firebase, Cloudflare, and the production relay URL are already configured in this build.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Start setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact setup remains focused and usable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_testApp());

    expect(find.text('ClassSync'), findsOneWidget);
    expect(find.text('1 / 9'), findsOneWidget);
    expect(find.text('SETUP SYLLABUS'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Start setup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp() => ProviderScope(
  child: MaterialApp(theme: ClassSyncTheme.light(), home: const SetupWizard()),
);
