import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:insta_save/screens/rating_screen.dart';
import 'package:insta_save/screens/home.dart';
import 'package:insta_save/screens/intro_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get shared prefs flags
  final prefs = await SharedPreferences.getInstance();
  final bool isIntroSeen = prefs.getBool('isIntroSeen') ?? false;
  final bool isRatingSeen = prefs.getBool('isRatingSeen') ?? false;

  runApp(MyApp(
    isIntroSeen: isIntroSeen,
    isRatingSeen: isRatingSeen,
  ));
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),

      home: !isIntroSeen
          ? const IntroScreen()
          : !isRatingSeen
          ? const ReviewsScreen()
          : const HomeScreen(),
    );
  }
}
