import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialise the global notifier before anything reads AppColors
  themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const GitGrabberApp());
}

class GitGrabberApp extends StatelessWidget {
  const GitGrabberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (_, mode, __) {
        // Update status bar brightness based on theme
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              mode == ThemeMode.dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          title: 'Git Grabber',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
