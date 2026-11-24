import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appearanceProvider =
    AsyncNotifierProvider<AppearanceController, ThemeMode>(
      AppearanceController.new,
    );

class AppearanceController extends AsyncNotifier<ThemeMode> {
  static const _channel = MethodChannel('classsync/appearance');

  @override
  Future<ThemeMode> build() async {
    if (!Platform.isIOS) return ThemeMode.system;
    final stored = await _channel.invokeMethod<String>('read');
    return ThemeMode.values.asNameMap()[stored] ?? ThemeMode.system;
  }

  Future<void> save(ThemeMode mode) async {
    await _channel.invokeMethod<void>('write', mode.name);
    state = AsyncData(mode);
  }
}
