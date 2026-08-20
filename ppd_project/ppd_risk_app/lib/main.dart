import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const PpdRiskApp());
}

class PpdRiskApp extends StatefulWidget {
  const PpdRiskApp({super.key});

  @override
  State<PpdRiskApp> createState() => _PpdRiskAppState();
}

class _PpdRiskAppState extends State<PpdRiskApp> {
  @override
  void initState() {
    super.initState();
    loadSavedThemeMode();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MotherWell',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
