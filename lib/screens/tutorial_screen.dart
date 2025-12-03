import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Main function to run this file directly for testing ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DemoScreen(),
    );
  }
}

// --- This is just a demo screen to launch the dialog ---
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  // Show the dialog as soon as the screen loads
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to show the dialog after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showTutorialDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is the screen "behind" the dialog
    return Scaffold(
      appBar: AppBar(
        title: const Text("Instant Saver"),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: const Center(
        child: Text("This is the main app content."),
      ),
    );
  }
}

// --- Function to call to show the tutorial dialog ---
Future<void> showTutorialDialog(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final bool dontShowAgain = prefs.getBool('dontShowTutorialAgain') ?? false;

  if (dontShowAgain) {
    // ✅ If the user opted not to show again, directly open Instagram
    const instaAppUrl = "instagram://app";
    const instaWebUrl = "https://instagram.com";
    if (await canLaunchUrl(Uri.parse(instaAppUrl))) {
      await launchUrl(Uri.parse(instaAppUrl));
    } else {
      await launchUrl(Uri.parse(instaWebUrl), mode: LaunchMode.externalApplication);
    }
    return; // Don't show dialog
  }

  // ✅ Otherwise, show the tutorial dialog
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const TutorialDialog();
    },
  );
}

// --- The Main Tutorial Dialog Widget ---
class TutorialDialog extends StatefulWidget {
  const TutorialDialog({super.key});

  @override
  State<TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;

  @override
  void initState() {
    super.initState();
    // Listen for page changes to update the dot indicator
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Makes the dim background visible
      body: Stack(
        children: [
          // --- 1. The Main Dialog Card ---
          Center(
            child: Container(
              // Use MediaQuery to make it responsive
              height: MediaQuery.of(context).size.height * 0.61,
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(20.0),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // PageView for swipable content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      children: const [
                        // --- Page 1 ---
                        _TutorialPage(
                          imagePath: 'assets/images/tutorial_01.png',
                          step: '01',
                          title: 'Open the Instagram',
                          description:
                          'Tap on "Import from Insta" — it will take you straight to the Instagram app.',
                        ),
                        // --- Page 2 ---
                        _TutorialPage(
                          imagePath: 'assets/images/tutorial_02.png',
                          step: '02',
                          title: 'Copy the Instagram Post/Reel Link',
                          description:
                          'Find the post or reel you want to save. Tap the share button ( ✈️ ) and then tap "Copy Link".',
                        ),
                        // --- Page 3 ---
                        _TutorialPage(
                          imagePath: 'assets/images/tutorial_03.png',
                          step: '03',
                          title: 'Paste the Link into Instant Saver',
                          description:
                          'Come back to the "Instant Saver". It usually auto-detects the copied link, and then just tap "Allow paste".',
                        ),
                        // --- Page 4 ---
                        _TutorialPage(
                          imagePath: 'assets/images/tutorial_04.png',
                          step: '04',
                          title: 'Save to Your Phone',
                          description:
                          'Tap on "Save", and the post or reel will be downloaded to your gallery!',
                        ),
                      ],

                    ),

                  ),
                  const SizedBox(height: 16),
                  // Dot Indicator
                  _buildPageIndicator(),
                  const SizedBox(height: 16),

                  // Bottom Bar (Checkbox + Button)
                  _buildBottomBar(),
                ],
              ),
            ),
          ),

          // --- 2. The "Dismiss" Button ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              // Adjust padding to position it below the dialog
              padding: EdgeInsets.only(
                bottom: (MediaQuery.of(context).size.height * 0.13) - 20,
              ),
              child: TextButton(
                onPressed: () {
                  // Save _dontShowAgain preference here
                  Navigator.of(context).pop();
                },
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

  // --- Helper Widgets ---

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 10 : 8,
          height: _currentPage == index ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index
                ? Colors.black
                : Colors.grey.shade300,
          ),
        );
      }),
    );
  }

  Widget _buildBottomBar() {
    return Row(
      children: [
        // Checkbox
        Checkbox(
          value: _dontShowAgain,
          onChanged: (bool? value) {
            setState(() {
              _dontShowAgain = value ?? false;
            });
          },
          activeColor: Colors.black,
        ),
        Text(
          "Don't show again",
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const Spacer(),
        // "Got it" Button
        ElevatedButton(
          onPressed: () async {
            if (_dontShowAgain) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dontShowTutorialAgain', true);
            }

            openInstagram();
            Navigator.of(context).pop();
          },

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text("Got it", style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
  // ✅ Instagram Open Function
  void openInstagram() async {
    const instaAppUrl = "instagram://app";
    const instaWebUrl = "https://instagram.com";

    if (await canLaunchUrl(Uri.parse(instaAppUrl))) {
      await launchUrl(Uri.parse(instaAppUrl));
    } else {
      await launchUrl(Uri.parse(instaWebUrl), mode: LaunchMode.externalApplication);
    }
  }
}

// --- Widget for the content of each tutorial page ---
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Image Container
        Expanded(
          child: Container(
            // 2. REMOVED fixed height: 250
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image_not_supported_outlined,
                  color: Colors.grey,
                  size: 50,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Step Title
        Text(
          "$step. $title",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Description
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}