import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/screens/home.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int _countdown = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown(); // Start the real timer
  }

  // Real countdown timer
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
        // Optionally, auto-navigate when countdown finishes
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to dark for light background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/images/rating_bg.png', // TODO: Change this
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),

          // 1. Main Scrollable Content
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50.0),
                  child: Image.asset(
                    'assets/images/reviews_top_section.png',
                    // TODO: Add your top image
                    fit: BoxFit.contain, // Adjust fit as needed
                  ),
                ),

                // --- "TEXT" SECTION ---
                // (The stars, title, and subtitle)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      // Star Rating
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Color(0xFFFFCC00), size: 36),
                          Icon(Icons.star, color: Color(0xFFFFCC00), size: 36),
                          Icon(Icons.star, color: Color(0xFFFFCC00), size: 36),
                          Icon(Icons.star, color: Color(0xFFFFCC00), size: 36),
                          Icon(Icons.star, color: Color(0xFFFFCC00), size: 36),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Main Title
                      const Text(
                        'Loved by Thousands',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      const Text(
                        'Trusted by creators and users worldwide.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- "SECOND IMAGE" ---
                // (Contains bottom reviews)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 50.0),
                  child: Image.asset(
                    'assets/images/reviews_bottom_section.png',
                    // TODO: Add your bottom image
                    fit: BoxFit.contain, // Adjust fit as needed
                  ),
                ),

                // This adds empty space at the bottom, so the
                // content can scroll up above the "Continue" button
                const SizedBox(height: 120),
              ],
            ),
          ),

          // 2. "COUNTINUR BUTTON" (Sticky Bottom Button)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea( // Ensures button is above home bar
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 24.0, left: 24, right: 24),
                child: Container(
                  width: double.infinity, // Make button full width
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFE9800), Color(0xFFE700A8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      navigateToHomeScreen();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Continue(${_countdown})', // Display countdown
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> navigateToHomeScreen() async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Set the 'isRatingSeen' flag to true
    await prefs.setBool('isRatingSeen', true);

    if (context.mounted) {
      // ✅ Navigate to the final HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}