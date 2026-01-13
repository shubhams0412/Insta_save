import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:insta_save/screens/rating_screen.dart';
import 'package:insta_save/screens/home_screen.dart'; // Renamed for consistency (was home_screen.dart)
import 'package:insta_save/screens/intro_screen.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/services/ad_service.dart';
import 'package:insta_save/services/notification_service.dart';
import 'package:insta_save/services/iap_service.dart';
import 'package:insta_save/utils/constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Notification Service
  await NotificationService().init();

  // Initialize IAP Service
  await IAPService().initialize();

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

  // Initialize Remote Config and Ads
  try {
    await RemoteConfigService().initialize();
    await AdService().initialize();
    // Load the first ad immediately so it's ready
    await AdService().loadAppOpenAd();

    final prefs = await SharedPreferences.getInstance();
    isIntroSeen = prefs.getBool('isIntroSeen') ?? false;
    isRatingSeen = prefs.getBool('isRatingSeen') ?? false;
  } catch (e) {
    debugPrint("Initialization error: $e");
  }

  runApp(MyApp(isIntroSeen: isIntroSeen, isRatingSeen: isRatingSeen));
}

class MyApp extends StatefulWidget {
  final bool isIntroSeen;
  final bool isRatingSeen;

  const MyApp({
    super.key,
    required this.isIntroSeen,
    required this.isRatingSeen,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Try showing ad on cold start (after layout)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint("App Open Ad Flow: Initial PostFrameCallback check.");
      if (navigatorKey.currentContext != null) {
        AdService().showAppOpenAdWithLoader(navigatorKey.currentContext!);
      } else {
        debugPrint(
          "App Open Ad Flow: navigatorKey.currentContext is NULL on init",
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  AppLifecycleState? _lastState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint(
      "App Open Ad Flow: Lifecycle State Changed: $state (Previous: $_lastState)",
    );

    // Only show ad if we were previously in 'paused' state (true background)
    // and NOT from 'inactive' (which happens on notifications/overlays)
    if (state == AppLifecycleState.resumed &&
        _lastState == AppLifecycleState.paused) {
      if (navigatorKey.currentContext != null) {
        debugPrint(
          "App Open Ad Flow: Calling showAppOpenAdWithLoader from Lifecycle (Background to Foreground)",
        );
        AdService().showAppOpenAdWithLoader(navigatorKey.currentContext!);
      }
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: Constants.AppName,
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
    if (!widget.isIntroSeen) {
      return const IntroScreen();
    }

    if (!widget.isRatingSeen) {
      return const ReviewsScreen();
    }

    return const HomeScreen();
  }
}
