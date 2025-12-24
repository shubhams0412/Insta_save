import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/screens/rating_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();

  // Optimization: Use ValueNotifier to update ONLY the text title, not the whole screen
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);

  // Data Model for the slides
  final List<IntroItem> _items = [
    IntroItem(
      image: 'assets/images/intro_01.png',
      title: "Grab Reels, Stories &\nPosts in just one tap",
      rotation: 0.0,
    ),
    IntroItem(
      image: 'assets/images/intro_02.png',
      title: "Repost Your Favorite\nInstagram Posts!",
      rotation: 0.1, // Slight rotation for the second image
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure status bar icons are dark (visible on light gradient)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Background Gradient
          _buildBackground(),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // --- SWIPEABLE CARDS ---
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _items.length,
                      onPageChanged: (int page) {
                        // Update the notifier without rebuilding the whole Scaffold
                        _currentPageNotifier.value = page;
                      },
                      itemBuilder: (context, index) {
                        return _IntroCard(
                          imagePath: _items[index].image,
                          rotationAngle: _items[index].rotation,
                        );
                      },
                    ),
                  ),
                ),

                // --- BOTTOM SECTION ---
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Dynamic Title (Listens to page changes)
                        ValueListenableBuilder<int>(
                          valueListenable: _currentPageNotifier,
                          builder: (context, pageIndex, child) {
                            return Text(
                              _items[pageIndex].title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            );
                          },
                        ),

                        const Spacer(),

                        // Dots
                        SmoothPageIndicator(
                          controller: _pageController,
                          count: _items.length,
                          effect: const WormEffect(
                            dotColor: Colors.black26,
                            activeDotColor: Colors.black,
                            dotHeight: 10,
                            dotWidth: 10,
                            spacing: 16,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Button
                        ElevatedButton(
                          onPressed: navigateToReviewsScreen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 56),
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
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE1BEE7), // Purple
            Color(0xFFBBDEFB), // Blue
          ],
        ),
      ),
    );
  }

  Future<void> navigateToReviewsScreen() async {
    final prefs = await SharedPreferences.getInstance();
    // Save preference
    await prefs.setBool('isIntroSeen', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReviewsScreen()),
      );
    }
  }
}

// --- HELPER CLASSES ---

class IntroItem {
  final String image;
  final String title;
  final double rotation;

  IntroItem({required this.image, required this.title, this.rotation = 0.0});
}

class _IntroCard extends StatelessWidget {
  final String imagePath;
  final double rotationAngle;

  const _IntroCard({required this.imagePath, this.rotationAngle = 0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: rotationAngle,
        child: ClipRRect(
          // Optional: Add border radius if your images need rounded corners
          // borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain, // Changed to contain to respect aspect ratio inside page view
            width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
          ),
        ),
      ),
    );
  }
}