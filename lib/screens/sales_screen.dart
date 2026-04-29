import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/models/remote_config_models.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/services/webview_screen.dart';
import 'package:insta_save/services/iap_service.dart';
import 'package:insta_save/utils/ui_utils.dart';

// Entry point for testing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RemoteConfigService().initialize();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: SalesScreen()),
  );
}

class SalesScreen extends StatefulWidget {
  final bool showCreatorReel;
  const SalesScreen({super.key, this.showCreatorReel = false});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _isLoading = true;
  SalesConfig? _config;
  late bool _isCreatorReelSelected;

  @override
  void initState() {
    super.initState();
    _isCreatorReelSelected = widget.showCreatorReel;
    _loadConfig();
    IAPService().isPremium.addListener(_onPremiumChanged);
    IAPService().isPremiumPlus.addListener(_onPremiumChanged);
  }

  @override
  void dispose() {
    IAPService().isPremium.removeListener(_onPremiumChanged);
    IAPService().isPremiumPlus.removeListener(_onPremiumChanged);
    super.dispose();
  }

  void _onPremiumChanged() {
    if (mounted) {
      if ((!_isCreatorReelSelected && IAPService().isPremium.value) ||
          (_isCreatorReelSelected && IAPService().isPremiumPlus.value)) {
        Navigator.of(context).pop();
      }
    }
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

  String _getOriginalPrice() {
    final priceStr = IAPService().getWeeklyPrice();
    final priceVal = IAPService().getWeeklyPriceValue();
    final fallback = _config?.plans.first['originalPrice'] ?? '';

    if (_config == null || _config!.plans.isEmpty) return fallback;

    final plan = _config!.plans.first;
    // Check if savePercentage exists and is valid
    if (!plan.containsKey('savePercentage')) return fallback;

    final savePercent = plan['savePercentage'];
    if (savePercent is! num) return fallback;

    // Avoid division by zero or negative
    if (savePercent >= 100) return fallback;

    // Calculate Original = Price * 100 / (100 - Save%)
    double originalVal = priceVal * 100 / (100 - savePercent);

    // Heuristic to match the format of priceStr
    // Find the number in the string (support comma or dot decimal)
    final match = RegExp(r'(\d+([.,]\d+)?)').firstMatch(priceStr);
    if (match != null) {
      String numberPart = match.group(1)!;

      String newNumberPart;
      if (numberPart.contains(',')) {
        // Assume comma decimal
        int decimals = numberPart.contains(',')
            ? numberPart.split(',')[1].length
            : 2;
        newNumberPart = originalVal
            .toStringAsFixed(decimals)
            .replaceAll('.', ',');
      } else if (numberPart.contains('.')) {
        // Dot decimal
        int decimals = numberPart.split('.')[1].length;
        newNumberPart = originalVal.toStringAsFixed(decimals);
      } else {
        // No decimal
        newNumberPart = originalVal.toStringAsFixed(0);
      }

      return priceStr.replaceFirst(numberPart, newNumberPart);
    }

    return fallback;
  }

  IconData _getIconForFeature(String text) {
    final lower = text.toLowerCase();

    // Creator Reel
    if (lower.contains('caption')) {
      return Icons.edit_note;
    }
    if (lower.contains('hook')) {
      return Icons.whatshot;
    }
    if (lower.contains('hashtag')) {
      return Icons.tag;
    }
    if (lower.contains('transcribe') ||
        lower.contains('translate') ||
        lower.contains('audio')) {
      return Icons.translate;
    }

    // Premium features
    if (lower.contains('ad-free') ||
        lower.contains('no ad') ||
        lower.contains('remove ad')) {
      return Icons.block;
    }
    if (lower.contains('repost') || lower.contains('unlimited')) {
      return Icons.repeat;
    }
    if (lower.contains('stor') || lower.contains('highlight')) {
      return Icons.amp_stories;
    }
    if (lower.contains('photo') || lower.contains('video')) {
      return Icons.photo_library;
    }
    if (lower.contains('gallery')) {
      return Icons.collections;
    }

    return Icons.check_circle_outline;
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
                          padding: const EdgeInsets.only(
                            left: 24.0,
                            right: 24.0,
                            top: 200.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // TABS
                              Container(
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(25),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _isCreatorReelSelected = false,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !_isCreatorReelSelected
                                                ? const Color(0xFF6C63FF)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          child: const Text(
                                            "Remove Ads",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => _isCreatorReelSelected = true,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _isCreatorReelSelected
                                                ? const Color(0xFF6C63FF)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          child: const Text(
                                            "Creator Reel",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // HEADER
                              Text(
                                _isCreatorReelSelected
                                    ? 'Creator Studio Pro'
                                    : (_config?.titleText ??
                                          'Video Downloader Premium'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _config?.titleColor ?? Colors.white,
                                  fontSize: _config?.titleSize ?? 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _config?.subTitleText ??
                                    'No commitment, cancel anytime',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      _config?.subTitleColor ?? Colors.white70,
                                  fontSize: _config?.subTitleSize ?? 18,
                                ),
                              ),
                              const SizedBox(height: 40),

                              // FEATURES LIST
                              _buildSectionHeader(
                                _config?.featuresTitle ?? 'WHAT YOU GET',
                                color: _config?.featuresTitleColor,
                                fontSize: _config?.featuresTitleSize,
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                        0.85,
                                  ),
                                  child: IntrinsicWidth(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children:
                                          (_isCreatorReelSelected
                                                  ? [
                                                      {
                                                        'text':
                                                            'Generate Trendy Captions',
                                                      },
                                                      {
                                                        'text':
                                                            'AI Hook Generation',
                                                      },
                                                      {
                                                        'text':
                                                            'Trending Hashtags',
                                                      },
                                                      {
                                                        'text':
                                                            'Transcribe & Translate Audio',
                                                      },
                                                    ]
                                                  : (_config?.features ?? []))
                                              .map(
                                                (f) => _FeatureRow(
                                                  text: f['text'],
                                                  icon: _getIconForFeature(
                                                    f['text'],
                                                  ),
                                                  textSize:
                                                      _config?.featureSize ??
                                                      14,
                                                  textColor:
                                                      _config?.featureColor ??
                                                      Colors.white,
                                                ),
                                              )
                                              .toList(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),

                              // PLAN
                              if (_config != null && _config!.plans.isNotEmpty)
                                _PlanCard(
                                  index: 0,
                                  isSelected: true,
                                  title: _isCreatorReelSelected
                                      ? 'Creator Pro Plan'
                                      : _config!.plans[0]['title'],
                                  subtitle: _isCreatorReelSelected
                                      ? IAPService().getCreatorReelTrialText()
                                      : IAPService().getTrialText(),
                                  price: _isCreatorReelSelected
                                      ? IAPService().getCreatorReelPrice()
                                      : IAPService().getWeeklyPrice(),
                                  originalPrice: _isCreatorReelSelected
                                      ? null
                                      : _getOriginalPrice(),
                                  badgeText: _isCreatorReelSelected
                                      ? 'AI Powered'
                                      : _config!.plans[0]['badgeText'],
                                  titleSize: _config!.planSize,
                                  titleColor: _config!.planColor,
                                  priceColor: _config!.priceColor,
                                  originalPriceColor:
                                      _config!.originalPriceColor,
                                  onTap: () {},
                                ),

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
                                  if (_isCreatorReelSelected) {
                                    IAPService().buyCreatorReel();
                                  } else {
                                    IAPService().buyWeekly();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  _config?.continueButtonText ?? 'Continue',
                                  style: TextStyle(
                                    color:
                                        _config?.continueButtonTextColor ??
                                        Colors.white,
                                    fontSize:
                                        _config?.continueButtonTextSize ?? 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Restore
                            TextButton(
                              onPressed: () async {
                                // Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                );

                                // Attempt to restore purchases
                                final restored = await IAPService()
                                    .restorePurchases();

                                // Close loading dialog
                                if (context.mounted) {
                                  Navigator.of(context).pop();

                                  // Show appropriate feedback
                                  if (restored) {
                                    UIUtils.showSnackBar(
                                      context,
                                      '✅ Purchase restored successfully!',
                                    );
                                  } else {
                                    UIUtils.showSnackBar(
                                      context,
                                      'No previous purchases found to restore.',
                                    );
                                  }
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white,
                                      width: 0.5, // Adjust thickness here
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _config?.restoreText ?? 'Restore Purchase',
                                  style: TextStyle(
                                    color:
                                        _config?.restoreTextColor ??
                                        Colors.white,
                                    fontSize: _config?.restoreTextSize ?? 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Footer Links
                            _FooterLinks(
                              privacyText:
                                  _config?.privacyText ?? 'Privacy Policy',
                              termsText: _config?.termsText ?? 'Terms of Use',
                              closeText: _config?.closeText ?? 'Close',
                              textSize: _config?.footerTextSize ?? 12.0,
                              textColor:
                                  _config?.footerTextColor ?? Colors.white38,
                              onPrivacyTap: () => _openWebView(
                                context,
                                _config?.privacyText ?? 'Privacy Policy',
                                RemoteConfigService().privacyUrl,
                              ),
                              onTermsTap: () => _openWebView(
                                context,
                                _config?.termsText ?? 'Terms of Use',
                                RemoteConfigService().termsUrl,
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

  Widget _buildSectionHeader(String title, {Color? color, double? fontSize}) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: color ?? Colors.white,
        fontSize: fontSize ?? 16, // Slightly smaller for elegance
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
  final IconData? icon;

  const _FeatureRow({
    required this.text,
    required this.textSize,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.check_circle_outline,
            color: const Color(0xFF8a878c),
            size: 20,
          ),
          const SizedBox(width: 12),
          Flexible(
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
  final Color priceColor;
  final Color originalPriceColor;
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
    required this.priceColor,
    required this.originalPriceColor,
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
                        style: TextStyle(
                          color: priceColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (originalPrice != null)
                        Text(
                          originalPrice!,
                          style: TextStyle(
                            color: originalPriceColor,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: originalPriceColor,
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
  final String privacyText;
  final String termsText;
  final String closeText;
  final double textSize;
  final Color textColor;
  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;
  final VoidCallback onCloseTap;

  const _FooterLinks({
    required this.privacyText,
    required this.termsText,
    required this.closeText,
    required this.textSize,
    required this.textColor,
    required this.onPrivacyTap,
    required this.onTermsTap,
    required this.onCloseTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLink(privacyText, onPrivacyTap),
        _buildDivider(),
        _buildLink(termsText, onTermsTap),
        _buildDivider(),
        _buildLink(closeText, onCloseTap),
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
          style: TextStyle(color: textColor, fontSize: textSize),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Text(
      " | ",
      style: TextStyle(color: textColor, fontSize: textSize),
    );
  }
}
