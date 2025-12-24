import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insta_save/screens/home_screen.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  // Optimization: Use ValueNotifier to prevent full screen rebuilds
  final ValueNotifier<int> _countdownNotifier = ValueNotifier<int>(3);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownNotifier.value > 0) {
        _countdownNotifier.value--;
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownNotifier.dispose(); // Don't forget to dispose the notifier
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar to dark icons (since background is likely light/white)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),

          // Scrollable Content
          SingleChildScrollView(
            // Add padding at bottom equal to button height + spacing
            padding: const EdgeInsets.only(bottom: 100),
            child: _buildMainContent(),
          ),

          // Sticky Button
          _buildBottomButton(),
        ],
      ),
    );
  }

  // --- WIDGET: Background Image ---
  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/rating_bg.png',
        fit: BoxFit.cover,
        errorBuilder: (_,__,___) => Container(color: Colors.white), // Fallback
      ),
    );
  }

  // --- WIDGET: Main Content (Images & Text) ---
  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Image
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50.0),
          child: Image.asset(
            'assets/images/reviews_top_section.png',
            fit: BoxFit.contain,
            errorBuilder: (_,__,___) => const SizedBox(height: 50),
          ),
        ),

        // Text & Stars Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
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

        // Bottom Image
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 50.0),
          child: Image.asset(
            'assets/images/reviews_bottom_section.png',
            fit: BoxFit.contain,
            errorBuilder: (_,__,___) => const SizedBox(height: 50),
          ),
        ),
      ],
    );
  }

  // --- WIDGET: Sticky Button with Gradient ---
  Widget _buildBottomButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Container(
            width: double.infinity,
            height: 56, // Fixed height for consistency
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFFFE9800), Color(0xFFE700A8)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE700A8).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: navigateToHomeScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              // Optimization: Only rebuild the Text widget when timer changes
              child: ValueListenableBuilder<int>(
                valueListenable: _countdownNotifier,
                builder: (context, value, child) {
                  return Text(
                    value > 0 ? 'Continue ($value)' : 'Continue',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> navigateToHomeScreen() async {
    final prefs = await SharedPreferences.getInstance();

    // Save flag
    await prefs.setBool('isRatingSeen', true);

    if (mounted) {
      // Use pushAndRemoveUntil to ensure user can't go back to this screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    }
  }
}