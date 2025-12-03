import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  final PageController _pageController = PageController();
  bool _isExpanded = false;

  final List<String> widgetImages = [
    "assets/images/widget_1.png",
    "assets/images/widget_2.png",
    "assets/images/widget_3.png",
    "assets/images/widget_4.png",
  ];

  @override
  Widget build(BuildContext context) {
    // We don't need 'height' variable anymore
    // final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Widgets",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                "Quick access to one of your recent lists, made simple.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),
            const SizedBox(height: 30),

            // --- THIS Expanded SOLVES THE OVERFLOW ---
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Center the content
                children: [
                  // --- Image PageView ---
                  // Use Flexible so PageView doesn't take all the space
                  Flexible(
                    flex: 5, // Give PageView more space
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widgetImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 90),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            // Using a placeholder until you add your assets
                            child: Image.asset(
                              widgetImages[index],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Placeholder in case images are missing
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                      child: Text("Image ${index + 1}")),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Dots indicator ---
                  Flexible(
                    flex: 1, // Give Dots less space
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: widgetImages.length,
                      effect: const ExpandingDotsEffect(
                        dotHeight: 8,
                        dotWidth: 8,
                        spacing: 6,
                        activeDotColor: Colors.black87,
                        dotColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // The SizedBox before the sheet can be removed or kept
            const SizedBox(height: 16),

            // --- Bottom Expandable Sheet ---
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              // Let's use a max-height instead of % to be safer
              height: _isExpanded ? 260 : 60,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    // Make the whole header tappable
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "How to Use?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: Colors.black54,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // This Expanded makes the ListView fill the
                  // remaining space inside the AnimatedContainer
                  if (_isExpanded)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24)
                            .copyWith(bottom: 16), // Add bottom padding
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero, // Remove default padding
                          children: const [
                            Text(
                              "Add widgets to your Home Screen:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "1. From the Home Screen, touch and hold a widget or empty space until your apps jiggle.",
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "2. Tap the Add (+) button in the upper-left corner.",
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "3. Scroll until you find InstaSave.",
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "4. Choose your preferred widget size and press Add Widget.",
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 13),
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
      ),
    );
  }
}