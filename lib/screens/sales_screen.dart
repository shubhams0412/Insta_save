import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/webview_screen.dart';

// You can run this file directly to test the screen
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SalesScreen(),
    );
  }
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // 0 = Annual, 1 = Monthly
  int _selectedPlanIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to white
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black, // Fallback color
      body: Stack(
        children: [
          // 1. Background Image
          // TODO: Replace 'assets/images/sales_background.png' with your asset
          Image.asset(
            'assets/images/sales_background.png',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
            // Show a dark color while image loads or if it fails
            errorBuilder: (context, error, stackTrace) {
              return Container(color: const Color(0xFF1A1A1A)); // Dark fallback
            },
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Spacer to push content down
                        SizedBox(height: MediaQuery.of(context).size.height * 0.15),

                        // Header
                        const Text(
                          'Instant Saver Premium',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No commitment, cancel anytime',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // "What You Get" Section
                        _buildSectionHeader('WHAT YOU GET'),
                        const SizedBox(height: 16),
                        _buildFeatureRow('Download Unlimited Reels'),
                        _buildFeatureRow('Download Stories & Highlights ✨'),
                        _buildFeatureRow('Download Post & Videos'),
                        _buildFeatureRow('No Ads'),
                        _buildFeatureRow('Save Photos & Videos to Gallery'),
                        const SizedBox(height: 20),

                        // "Choose Plan" Section
                        _buildSectionHeader('Choose Plan'),
                        const SizedBox(height: 30), // Extra space for the tag

                        // Annual Plan Option
                        _buildPlanOption(
                          index: 0,
                          title: 'Annunal', // As spelled in the image
                          trialText: '3-day free trial',
                          price: '\$19.99',
                          originalPrice: '\$32.00',
                          tagText: 'Best - \$0.38 / week',
                        ),
                        const SizedBox(height: 20),

                        // Monthly Plan Option
                        _buildPlanOption(
                          index: 1,
                          title: 'Monthly',
                          trialText: '3-day free trial',
                          price: '\$9.99',
                        ),
                        const SizedBox(height: 24),
                        // Continue Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFCF1F), Color(0xFFF76B17),Color(0xFFFC01CA), Color(0xFF7E0BFD)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              // Handle continue tap
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Restore Purchase
                        TextButton(
                          onPressed: () {
                            // Handle restore purchase
                          },
                          child: const Text(
                            'Restore Purchase',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Footer Links
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _footerTextLink('Privacy Policy', () {
                              // This is the new navigation logic
                              Navigator.of(context).push(createSlideRoute(const WebViewScreen(
                                title: 'Privacy Policy',
                                url: 'https://google.com', // <-- Put your real URL here
                              ), direction: SlideFrom.right));
                            }),
                            _footerTextSeparator(),
                            _footerTextLink('Terms of Use', () {
                              // This is the new navigation logic
                              Navigator.of(context).push(createSlideRoute(const WebViewScreen(
                                title: 'Terms of Use',
                                url: 'https://google.com', // <-- Put your real URL here
                              ), direction: SlideFrom.right));
                            }),
                            _footerTextSeparator(),
                            _footerTextLink('Close', () {
                              print("Close tapped!");
                              // Close the sales screen
                              Navigator.of(context).pop();
                            }),
                          ],
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

  // --- Helper Widgets ---

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start, // Align icon to top if text wraps
        children: [
          const Icon(Icons.check, color: Color(0xFF8a878c), size: 20),
          const SizedBox(width: 16),
          // --- FIX STARTS HERE ---
          Expanded( // 1. Wrap Text in Expanded
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // --- FIX ENDS HERE ---
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required int index,
    required String title,
    required String trialText,
    required String price,
    String? originalPrice,
    String? tagText,
  }) {
    bool isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Stack(
        clipBehavior: Clip.none, // Allow tag to overflow
        children: [
          // The main plan container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF8A4DFF) : Colors.grey.shade700,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Custom radio button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFE84DFF) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE84DFF) : Colors.grey.shade500,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 16),

                // Plan details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      trialText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Price details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (originalPrice != null)
                      Text(
                        originalPrice,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // "Best" Tag
          if (tagText != null)
            Positioned(
              top: -14, // Position halfway outside the container
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFCF1F), Color(0xFFF76B17),Color(0xFFFC01CA), Color(0xFF7E0BFD)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tagText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _footerTextLink(String text, VoidCallback onTap) {
    return GestureDetector( // Wrap with GestureDetector
      onTap: onTap, // Assign the function
      child: Text(
        text,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _footerTextSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.0),
      child: Text('|', style: TextStyle(color: Colors.white54, fontSize: 12)),
    );
  }
}