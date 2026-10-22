import 'package:flutter/material.dart';
import 'package:mova/splash_screen.dart';

// Global theme switch: false = light mode, true = dark mode.
// The Dark Mode toggle in the home screen drawer updates this value.
final ValueNotifier<bool> themeModeNotifier = ValueNotifier<bool>(false);

// App entry point.
void main() {
  runApp(const MyApp());
}

// Root widget. Rebuilds the MaterialApp whenever the theme mode changes.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeModeNotifier,
      // Passed as `child` so the splash screen isn't rebuilt on theme changes.
      child: const SplashScreen(),
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Carpool App',

          // Light theme generated from the Mova green seed colour.
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromRGBO(15, 110, 86, 1),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // Dark theme generated from the same seed colour.
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromRGBO(15, 110, 86, 1),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          // Choose light or dark based on the notifier's value.
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          // First screen shown when the app starts.
          home: child,
        );
      },
    );
  }
}
