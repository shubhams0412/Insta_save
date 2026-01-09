import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/screens/rating_screen.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/services/rating_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  Timer? _autoSwipeTimer;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _startAutoSwipe();
  }

  void _startAutoSwipe() {
    _autoSwipeTimer = Timer(const Duration(seconds: 4), () {
      if (_pageController.hasClients && _pageController.page == 0) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _loadConfig() async {
    if (RemoteConfigService().introConfig == null) {
      await RemoteConfigService().initialize();
    }
    if (mounted) setState(() {});
  }

  // Optimization: Use ValueNotifier to update ONLY the text title, not the whole screen
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);

  // Data Model for the slides
  final List<IntroItem> _items = [
    IntroItem(
      image: 'assets/images/intro_01.png',
      title: "Grab Reels, Stories &\nPosts in just one tap",
    ),
    IntroItem(
      image: 'assets/images/intro_02.png',
      title: "Repost Your Favorite\nInstagram Posts!",
    ),
  ];

  @override
  void dispose() {
    _autoSwipeTimer?.cancel();
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
          // 1. Background Gradient & Decorative Circles
          _buildBackground(),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                // --- SWIPEABLE CARDS ---
                Expanded(
                  flex: 7,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _items.length,
                    onPageChanged: (int page) {
                      _currentPageNotifier.value = page;
                    },
                    itemBuilder: (context, index) {
                      return _IntroCard(
                        imagePath: _items[index].image,
                      );
                    },
                  ),
                ),

                // --- BOTTOM SECTION ---
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Dynamic Title (Listens to page changes)
                        ValueListenableBuilder<int>(
                          valueListenable: _currentPageNotifier,
                          builder: (context, pageIndex, child) {
                            final config = RemoteConfigService().introConfig;
                            String title = _items[pageIndex].title;
                            if (config != null &&
                                pageIndex < config.items.length) {
                              title = config.items[pageIndex].title;
                            }

                            return Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: config?.titleColor ?? Colors.black,
                                fontSize: config?.titleSize ?? 28,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 20),

                        // Dots
                        SmoothPageIndicator(
                          controller: _pageController,
                          count: _items.length,
                          effect: const ScrollingDotsEffect(
                            dotColor: Color(0xFFD1D1D1),
                            activeDotColor: Colors.black,
                            dotHeight: 8,
                            dotWidth: 8,
                            spacing: 8,
                            activeDotScale: 1.2,
                          ),
                        ),

                        const Spacer(),

                        // Button
                        Padding(
                          padding: const EdgeInsets.only(bottom: 30.0),
                          child: ElevatedButton(
                            onPressed: navigateToReviewsScreen,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(220, 56),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                RemoteConfigService().introConfig?.buttonText ??
                                    'Get Started',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x25BB2ECF), // Very soft purple
                Color(0x204F8FFA), // Very soft blue
              ],
            ),
          ),
        ),
        // Decorative Circles (Matching mockup)
      ],
    );
  }

  Future<void> navigateToReviewsScreen() async {
    await RatingService().checkAndShowRating(null, always: true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isIntroSeen', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ReviewsScreen()),
      );
    }
  }
}


class IntroItem {
  final String image;
  final String title;

  IntroItem({required this.image, required this.title});
}

class _IntroCard extends StatelessWidget {
  final String imagePath;

  const _IntroCard({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: double.infinity,
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}
