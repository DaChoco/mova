import 'package:flutter/material.dart';
import 'package:mova/splash_screen.dart';

final ValueNotifier<bool> themeModeNotifier = ValueNotifier<bool>(false);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: themeModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Carpool App',

          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

          home: const SplashScreen(),
        );
      },
    );
  }
}
