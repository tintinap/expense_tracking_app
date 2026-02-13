import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'screens/main_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        final brightness = settings.brightness;
        final theme = brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        return MaterialApp(
          title: 'DailySpend',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const MainScreen(),
        );
      },
    );
  }
}
