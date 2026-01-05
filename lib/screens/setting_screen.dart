import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// ✅ Import your app screens
import 'package:insta_save/screens/sales_screen.dart';
import 'package:insta_save/screens/widget_screen.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/webview_screen.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/services/ad_service.dart';
import 'package:insta_save/services/rating_service.dart';

import '_buildStepCard.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Allow pop, but listen to it
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // User is leaving settings screen
          debugPrint("Leaving Settings Screen - Checking Rating Trigger");
          await RatingService().checkAndShowRating(
            RatingService().settingsReturnCountKey,
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.black,
            ),
            onPressed: () {
              // Manual pop also triggers the listener (if implemented correctly)
              // But standard Navigator.pop() triggers it.
              Navigator.of(context).pop();
            },
          ),
          title: const Text(
            'Settings',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Column(
            children: [
              // 1. Premium Banner
              _buildRemoveAdsBanner(context),
              const SizedBox(height: 24),
              // ... rest of the body
              // 2. Appearance Section
              _buildSettingsGroup(
                title: "Appearance",
                children: [
                  _buildTile(
                    iconPath: 'assets/images/st_widgets.png',
                    title: 'Widgets',
                    onTap: () {
                      Navigator.of(context).push(
                        createSlideRoute(
                          const WidgetsScreen(),
                          direction: SlideFrom.right,
                        ),
                      );
                    },
                  ),
                  _buildTile(
                    iconPath: 'assets/images/st_love.png',
                    title: 'Send Love',
                    onTap: () {
                      // TODO: Implement Rating logic or store link
                    },
                  ),
                  _buildTile(
                    iconPath: 'assets/images/st_friend.png',
                    title: 'Tell a Friend',
                    onTap: () {
                      AdService().setPausedForShare(true);
                      Share.share(
                        'Check out InstaSave! Download unlimited reels and posts easily.',
                      );
                    },
                  ),
                  _buildTile(
                    iconPath: 'assets/images/st_suggetion.png',
                    title:
                        'How to use?', // Changed title to match target screen better
                    onTap: () {
                      Navigator.of(context).push(
                        createSlideRoute(
                          const TutorialScreen(),
                          direction: SlideFrom.right,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. Help & Support Section
              _buildSettingsGroup(
                title: "Help & Support",
                children: [
                  _buildTile(
                    iconPath: 'assets/images/st_terms.png',
                    title: 'Terms & Conditions',
                    onTap: () => _openWebView(
                      context,
                      'Terms of Use',
                      RemoteConfigService().termsUrl,
                    ),
                  ),
                  _buildTile(
                    iconPath: 'assets/images/st_privacy.png',
                    title: 'Privacy Policy',
                    onTap: () => _openWebView(
                      context,
                      'Privacy Policy',
                      RemoteConfigService().privacyUrl,
                    ),
                  ),
                  _buildTile(
                    iconPath: 'assets/images/st_contact.png',
                    title: 'Contact Us',
                    onTap: () => _openWebView(
                      context,
                      'Contact Us',
                      RemoteConfigService().contactUsUrl,
                    ),
                  ),
                ],
              ),

              // Bottom Padding for safety
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildRemoveAdsBanner(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          createSlideRoute(const SalesScreen(), direction: SlideFrom.bottom),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF9881F), Color(0xFFE15151)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE15151).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Text(
              'AD',
              style: TextStyle(
                color: Color(0xFFF9881F),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          title: const Text(
            'Remove Ads',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: const Text(
            'Go Premium for no limits',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 10),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50, // Very subtle grey
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, indent: 60, color: Colors.grey.shade200),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile({
    required String iconPath,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Image.asset(
        iconPath,
        width: 32,
        height: 32,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.settings, color: Colors.grey),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
    );
  }

  // --- ACTIONS ---

  void _openWebView(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      createSlideRoute(
        WebViewScreen(title: title, url: url),
        direction: SlideFrom.right,
      ),
    );
  }
}
