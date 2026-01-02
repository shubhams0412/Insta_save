import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Function to call to show the tutorial dialog ---
Future<void> showTutorialDialog(BuildContext context) async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: <String>{'dontShowTutorialAgain'},
    ),
  );
  final bool dontShowAgain = prefs.getBool('dontShowTutorialAgain') ?? false;

  if (dontShowAgain) {
    _openInstagram();
    return;
  }

  if (context.mounted) {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => const TutorialDialog(),
    );
  }
}

Future<void> _openInstagram() async {
  const instaAppUrl = "instagram://app";
  const instaWebUrl = "https://instagram.com";

  if (await canLaunchUrl(Uri.parse(instaAppUrl))) {
    await launchUrl(Uri.parse(instaAppUrl));
  } else {
    await launchUrl(
      Uri.parse(instaWebUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}

// --- The Main Tutorial Dialog Widget ---
class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);
  bool _dontShowAgain = false;

  // Data for the tutorial steps
  final List<Map<String, String>> _steps = const [
    {
      'image': 'assets/images/tutorial_01.png',
      'step': '01',
      'title': 'Open Instagram',
      'desc': 'Tap "Import from Insta" to go straight to the Instagram app.',
    },
    {
      'image': 'assets/images/tutorial_02.png',
      'step': '02',
      'title': 'Copy Link',
      'desc': 'Find a post. Tap Share (✈️) and select "Copy Link".',
    },
    {
      'image': 'assets/images/tutorial_03.png',
      'step': '03',
      'title': 'Paste Link',
      'desc':
          'Return to Instant Saver. It auto-detects the link, just tap "Allow paste".',
    },
    {
      'image': 'assets/images/tutorial_04.png',
      'step': '04',
      'title': 'Save Media',
      'desc': 'Tap "Save" to download the post or reel to your gallery!',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive height (Max 65% of screen, Min 500px)
    final height = MediaQuery.of(context).size.height * 0.65;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Dialog Content
          Center(
            child: Container(
              height: height,
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Title
                  const Text(
                    "How to save posts & reels\nfrom Instagram?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Carousel
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _steps.length,
                      onPageChanged: (index) {
                        _currentPageNotifier.value = index;
                      },
                      itemBuilder: (context, index) {
                        final item = _steps[index];
                        return _TutorialPage(
                          imagePath: item['image']!,
                          step: item['step']!,
                          title: item['title']!,
                          description: item['desc']!,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Indicators
                  ValueListenableBuilder<int>(
                    valueListenable: _currentPageNotifier,
                    builder: (_, page, __) => _buildPageIndicator(page),
                  ),

                  const SizedBox(height: 16),

                  // Bottom Action Bar
                  _buildBottomBar(),
                ],
              ),
            ),
          ),

          // 2. Dismiss Button (Outside the white box)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: (MediaQuery.of(context).size.height - height) / 2 - 60,
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Dismiss",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int currentPage) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_steps.length, (index) {
        bool isActive = currentPage == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.black : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        // Checkbox
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _dontShowAgain,
            onChanged: (val) => setState(() => _dontShowAgain = val ?? false),
            activeColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "Don't show again",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),

        const Spacer(),

        // "Got it" Button
        ElevatedButton(
          onPressed: () async {
            if (_dontShowAgain) {
              final prefs = await SharedPreferencesWithCache.create(
                cacheOptions: const SharedPreferencesWithCacheOptions(
                  allowList: <String>{'dontShowTutorialAgain'},
                ),
              );
              await prefs.setBool('dontShowTutorialAgain', true);
            }
            if (mounted) {
              Navigator.of(context).pop(); // Close dialog first
              _openInstagram(); // Then open insta
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            "Got it",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// --- Helper for Page Content ---
class _TutorialPage extends StatelessWidget {
  final String imagePath;
  final String step;
  final String title;
  final String description;

  const _TutorialPage({
    required this.imagePath,
    required this.step,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.grey,
                size: 50,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "$step. $title",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
