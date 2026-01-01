import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:insta_save/screens/rating_screen.dart';
import 'package:insta_save/screens/home_screen.dart'; // Renamed for consistency (was home_screen.dart)
import 'package:insta_save/screens/intro_screen.dart';
import 'package:insta_save/services/remote_config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // 1. Lock Orientation to Portrait (Optional but recommended for this type of app)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 2. Make Status Bar Transparent for edge-to-edge look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // Dark icons for white background
    ),
  );

  // Default values in case SharedPreferences fails
  bool isIntroSeen = false;
  bool isRatingSeen = false;

  try {
    // Initialize Remote Config with a timeout (e.g., 5 seconds)
    // This ensures that even if Remote Config fails, the app still opens
    await RemoteConfigService().initialize();
    //     .timeout(
    //   const Duration(seconds: 5),
    //   onTimeout: () => print("Remote Config timeout"),
    // );

    // 3. Load Preferences (inside try-catch to handle platform channel errors)
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{'isIntroSeen', 'isRatingSeen'},
      ),
    );
    isIntroSeen = prefs.getBool('isIntroSeen') ?? false;
    // Note: Blocking user with Rating screen on startup can be aggressive.
    // Consider moving rating logic inside Home Screen triggered by an event.
    isRatingSeen = prefs.getBool('isRatingSeen') ?? false;
  } catch (e) {
    print("Initialization error: $e");
  }

  runApp(MyApp(isIntroSeen: isIntroSeen, isRatingSeen: isRatingSeen));
}

class MyApp extends StatelessWidget {
  final bool isIntroSeen;
  final bool isRatingSeen;

  const MyApp({
    super.key,
    required this.isIntroSeen,
    required this.isRatingSeen,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InstaSave',
      debugShowCheckedModeBanner: false,

      // 4. Proper Material 3 Theme Configuration
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black, // Primary Brand Color
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // Removes scroll color tint
          elevation: 0,
        ),
      ),

      // 5. Clean Screen Selection Logic
      home: _getStartScreen(),
    );
  }

  // Helper to determine the starting screen
  Widget _getStartScreen() {
    if (!isIntroSeen) {
      return const IntroScreen();
    }

    if (!isRatingSeen) {
      // ⚠️ UX Warning: This forces users to see the Rating screen
      // every time they open the app until they rate it.
      return const ReviewsScreen();
    }

    return const HomeScreen();
  }
}
