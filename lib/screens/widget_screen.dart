import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class WidgetsScreen extends StatefulWidget {
  const WidgetsScreen({super.key});

  @override
  State<WidgetsScreen> createState() => _WidgetsScreenState();
}

class _WidgetsScreenState extends State<WidgetsScreen> {
  // ✅ 1. Use viewportFraction to control image size naturally
  final PageController _pageController = PageController(viewportFraction: 0.55);
  bool _isExpanded = false;

  final List<String> _widgetImages = [
    "assets/images/widget_1.png",
    "assets/images/widget_2.png",
    "assets/images/widget_3.png",
    "assets/images/widget_4.png",
  ];

  final List<String> _steps = [
    "From the Home Screen, touch and hold a widget or empty space until your apps jiggle.",
    "Tap the Add (+) button in the upper-left corner.",
    "Scroll until you find InstaSave.",
    "Choose your preferred widget size and press Add Widget.",
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Widgets",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Subtitle
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "Quick access to one of your recent lists, made simple.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
            ),

            const SizedBox(height: 20),

            // Carousel Section
            Expanded(
              child: _buildCarousel(),
            ),

            const SizedBox(height: 20),

            // Bottom Instructions Sheet
            _buildInstructionsSheet(),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCarousel() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Images
        SizedBox(
          height: 300, // Fixed height for carousel area
          child: PageView.builder(
            controller: _pageController,
            itemCount: _widgetImages.length,
            // PadEnds false ensures the first item starts in center if wanted,
            // but with viewportFraction it centers automatically.
            itemBuilder: (context, index) {
              // Add simple scale animation (Optional polish)
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          _widgetImages[index],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.grey.shade200,
                            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 30),

        // Indicators
        SmoothPageIndicator(
          controller: _pageController,
          count: _widgetImages.length,
          effect: const ExpandingDotsEffect(
            dotHeight: 8,
            dotWidth: 8,
            spacing: 6,
            activeDotColor: Colors.black,
            dotColor: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionsSheet() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.fastOutSlowIn,
      // Adjust heights based on content
      height: _isExpanded ? 320 : 70,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Always visible)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "How to Use?",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: Colors.black54,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Content (Hidden when collapsed)
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isExpanded ? 1.0 : 0.0,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${index + 1}. ",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _steps[index],
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}