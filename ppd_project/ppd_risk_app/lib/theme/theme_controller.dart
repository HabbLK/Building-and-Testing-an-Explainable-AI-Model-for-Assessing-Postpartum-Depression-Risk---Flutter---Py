import 'package:flutter/material.dart';
import '../services/local_store.dart';

/// App-wide theme mode, readable/writable from any screen without a
/// dependency-injection setup — this app is small enough that a single
/// notifier is simpler than plumbing state through every route.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.light);

Future<void> loadSavedThemeMode() async {
  final isDark = await LocalStore.isDarkMode();
  themeModeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
}

Future<void> toggleThemeMode(bool dark) async {
  themeModeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  await LocalStore.setDarkMode(dark);
}
