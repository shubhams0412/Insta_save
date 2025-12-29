import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/webview_screen.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:convert';

// Entry point for testing
void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SalesScreen()),
  );
}

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // 0 = Annual, 1 = Monthly
  int _selectedPlanIndex = 0;
  bool _isLoading = true;
  SalesConfig? _config;

  @override
  void initState() {
    super.initState();
    _fetchRemoteConfig();
  }

  Future<void> _fetchRemoteConfig() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default values matching your hardcoded UI
      await remoteConfig.setDefaults({
        "sales_screen_config": jsonEncode({
          "title": {
            "text": "Instant Saver Premium",
            "textSize": 28,
            "textColor": "#FFFFFF",
          },
          "subTitle": {
            "text": "No commitment, cancel anytime",
            "textSize": 16,
            "textColor": "#B3FFFFFF",
          },
          "features": [
            {"text": "Download Unlimited Reels"},
            {"text": "Download Stories & Highlights ✨"},
            {"text": "Download Post & Videos"},
            {"text": "No Ads"},
            {"text": "Save Photos & Videos to Gallery"},
          ],
          "plans": [
            {
              "title": "Annual",
              "subtitle": "3-day free trial",
              "price": "\$19.99",
              "originalPrice": "\$32.00",
              "badgeText": "Best - \$0.38 / week",
            },
            {
              "title": "Monthly",
              "subtitle": "3-day free trial",
              "price": "\$9.99",
            },
          ],
        }),
      });

      await remoteConfig.fetchAndActivate();
      final String jsonString = remoteConfig.getString('sales_screen_config');

      setState(() {
        _config = SalesConfig.fromJson(jsonDecode(jsonString));
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching remote config: $e');
      // Fallback if needed, or just stop loading to show defaults/error state
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to light (white) for dark background
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                // 1. Background Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/sales_background.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2C003E), Colors.black],
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. Content
                SafeArea(
                  child: Column(
                    children: [
                      // Scrollable Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.08,
                              ),

                              // HEADER
                              Text(
                                _config?.titleText ?? 'Instant Saver Premium',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _config?.titleColor ?? Colors.white,
                                  fontSize: _config?.titleSize ?? 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _config?.subTitleText ??
                                    'No commitment, cancel anytime',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      _config?.subTitleColor ?? Colors.white70,
                                  fontSize: _config?.subTitleSize ?? 16,
                                ),
                              ),
                              const SizedBox(height: 30),

                              // FEATURES LIST
                              _buildSectionHeader('WHAT YOU GET'),
                              const SizedBox(height: 16),
                              if (_config != null)
                                ..._config!.features.map(
                                  (f) => _FeatureRow(text: f['text']),
                                ),
                              const SizedBox(height: 30),

                              // PLANS
                              _buildSectionHeader('CHOOSE PLAN'),
                              const SizedBox(height: 30),

                              if (_config != null)
                                ...List.generate(_config!.plans.length, (
                                  index,
                                ) {
                                  final plan = _config!.plans[index];
                                  return Column(
                                    children: [
                                      _PlanCard(
                                        index: index,
                                        isSelected: _selectedPlanIndex == index,
                                        title: plan['title'],
                                        subtitle: plan['subtitle'],
                                        price: plan['price'],
                                        originalPrice: plan['originalPrice'],
                                        badgeText: plan['badgeText'],
                                        onTap: () => setState(
                                          () => _selectedPlanIndex = index,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],
                                  );
                                }),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),

                      // Sticky Bottom Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Continue Button
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFCF1F),
                                    Color(0xFFF76B17),
                                    Color(0xFFFC01CA),
                                    Color(0xFF7E0BFD),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  // TODO: Implement Purchase Logic
                                  print("Selected Plan: $_selectedPlanIndex");
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
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
                            const SizedBox(height: 12),

                            // Restore
                            TextButton(
                              onPressed: () {
                                // TODO: Implement Restore Logic
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Restore Purchase',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Footer Links
                            _FooterLinks(
                              onPrivacyTap: () => _openWebView(
                                context,
                                'Privacy Policy',
                                'https://google.com',
                              ),
                              onTermsTap: () => _openWebView(
                                context,
                                'Terms of Use',
                                'https://google.com',
                              ),
                              onCloseTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _openWebView(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      createSlideRoute(
        WebViewScreen(title: title, url: url),
        direction: SlideFrom.right,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16, // Slightly smaller for elegance
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🔹 Helper Widgets (Extracted for Performance & Readability)
// -----------------------------------------------------------------------------

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, color: Color(0xFF8a878c), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final int index;
  final bool isSelected;
  final String title;
  final String subtitle;
  final String price;
  final String? originalPrice;
  final String? badgeText;
  final VoidCallback onTap;

  const _PlanCard({
    required this.index,
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.price,
    this.originalPrice,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E1E1E) : Colors.black54,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE84DFF)
                    : Colors.grey.shade800,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                // Radio Circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFE84DFF)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE84DFF)
                          : Colors.grey.shade600,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
                ),
                const SizedBox(width: 16),

                // Text Info
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Price Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (originalPrice != null)
                      Text(
                        originalPrice!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // "Best" Badge
          if (badgeText != null)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFCF1F),
                        Color(0xFFF76B17),
                        Color(0xFFFC01CA),
                        Color(0xFF7E0BFD),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;
  final VoidCallback onCloseTap;

  const _FooterLinks({
    required this.onPrivacyTap,
    required this.onTermsTap,
    required this.onCloseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLink("Privacy Policy", onPrivacyTap),
        _buildDivider(),
        _buildLink("Terms of Use", onTermsTap),
        _buildDivider(),
        _buildLink("Close", onCloseTap),
      ],
    );
  }

  Widget _buildLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0), // Hit area padding
        child: Text(
          text,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Text(
      " | ",
      style: TextStyle(color: Colors.white38, fontSize: 12),
    );
  }
}

class SalesConfig {
  final String titleText;
  final double titleSize;
  final Color titleColor;
  final String subTitleText;
  final double subTitleSize;
  final Color subTitleColor;
  final List<Map<String, dynamic>> features;
  final List<Map<String, dynamic>> plans;

  SalesConfig({
    required this.titleText,
    required this.titleSize,
    required this.titleColor,
    required this.subTitleText,
    required this.subTitleSize,
    required this.subTitleColor,
    required this.features,
    required this.plans,
  });

  factory SalesConfig.fromJson(Map<String, dynamic> json) {
    return SalesConfig(
      titleText: json['title']['text'],
      titleSize: json['title']['textSize'].toDouble(),
      titleColor: _parseColor(json['title']['textColor']),
      subTitleText: json['subTitle']['text'],
      subTitleSize: json['subTitle']['textSize'].toDouble(),
      subTitleColor: _parseColor(json['subTitle']['textColor']),
      features: List<Map<String, dynamic>>.from(json['features']),
      plans: List<Map<String, dynamic>>.from(json['plans']),
    );
  }

  static Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // Add opacity if missing
    return Color(int.parse(hex, radix: 16));
  }
}
