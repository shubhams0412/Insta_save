import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/models/remote_config_models.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/services/webview_screen.dart';

// Entry point for testing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService().initialize();
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
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    // If service not initialized, try to init (safety check)
    if (RemoteConfigService().salesConfig == null) {
      await RemoteConfigService().initialize();
    }

    if (mounted) {
      setState(() {
        _config = RemoteConfigService().salesConfig;
        _isLoading = false;
      });
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
                                  (f) => _FeatureRow(
                                    text: f['text'],
                                    textSize: _config!.featureSize,
                                    textColor: _config!.featureColor,
                                  ),
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
                                        titleSize: _config!.planSize,
                                        titleColor: _config!.planColor,
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
  final double textSize;
  final Color textColor;

  const _FeatureRow({
    required this.text,
    required this.textSize,
    required this.textColor,
  });

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
              style: TextStyle(
                color: textColor,
                fontSize: textSize,
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
  final double titleSize;
  final Color titleColor;
  final VoidCallback onTap;

  const _PlanCard({
    required this.index,
    required this.isSelected,
    required this.title,
    required this.subtitle,
    required this.price,
    this.originalPrice,
    this.badgeText,
    required this.titleSize,
    required this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient border container
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [
                        Color(0xFFFFCF1F),
                        Color(0xFFF76B17),
                        Color(0xFFFC01CA),
                        Color(0xFF7E0BFD),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFF424242), // Grey color for unselected
                        Color(0xFF424242),
                      ],
                    ),
            ),
            padding: const EdgeInsets.all(2), // Consistent padding
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E), // Fixed dark background
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  // Radio Circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [
                                Color(0xFFFFCF1F),
                                Color(0xFFF76B17),
                                Color(0xFFFC01CA),
                                Color(0xFF7E0BFD),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      border: !isSelected
                          ? Border.all(color: Colors.grey.shade600, width: 2)
                          : null,
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
                        style: TextStyle(
                          color: titleColor,
                          fontSize: titleSize,
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
