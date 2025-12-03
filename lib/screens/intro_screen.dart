import 'package:flutter/material.dart';
import 'package:insta_save/screens/rating_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, required bool isIntroSeen});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IntroScreen(),
    );
  }
}

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _titles = [
    "Grab Reels, Stories &\nPosts in just one tap",
    "Repost Your Favorite\nInstagram Posts!",
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ensure the background covers the whole screen including status bar area
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE1BEE7), // Adjusted opacity for visibility (Purple)
              Color(0xFFBBDEFB), // Adjusted opacity for visibility (Blue)
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. PageView for the swipable cards
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0), // Space from status bar
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: const [
                      _IntroCard(
                        imagePath: 'assets/images/intro_01.png',
                      ),
                      _IntroCard(
                        imagePath: 'assets/images/intro_02.png',
                        rotationAngle: 0.1,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Bottom section (Text -> Dots -> Button)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end, // Pushes content to bottom
                    children: [
                      // Title Text
                      Text(
                        _titles[_currentPage],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black, // Changed to black for visibility
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),

                      const Spacer(), // Fills space between Text and Dots

                      // Dot Indicator
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: 2,
                        effect: const WormEffect(
                          dotColor: Colors.black26, // Inactive color
                          activeDotColor: Colors.black, // Active color
                          dotHeight: 10,
                          dotWidth: 10,
                          spacing: 16,
                        ),
                      ),

                      const SizedBox(height: 32), // Space between dots and button

                      // Get Started Button
                      ElevatedButton(
                        onPressed: () {
                          navigateToHomeScreen();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56), // Taller button
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> navigateToHomeScreen() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReviewsScreen()),
      );
      await prefs.setBool('isIntroSeen', true);
    }
  }
}

class _IntroCard extends StatelessWidget {
  final String imagePath;
  final double rotationAngle;

  const _IntroCard({required this.imagePath, this.rotationAngle = 0});

  @override
  Widget build(BuildContext context) {
    // Removed nested SafeArea to prevent layout issues
    return Padding(
      padding: const EdgeInsets.all(0), // Add padding so image isn't edge-to-edge
      child: Center(
        child: Transform.rotate(
          angle: rotationAngle,
          child: Container(
            decoration: BoxDecoration(
            ),
            child: ClipRRect(
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                // Ensures the card doesn't get too huge
                width: double.infinity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}