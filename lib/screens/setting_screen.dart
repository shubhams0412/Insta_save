import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:insta_save/screens/_buildStepCard.dart';
import 'package:insta_save/screens/sales_screen.dart';
import 'package:insta_save/utils/navigation_helper.dart';
import 'package:insta_save/utils/webview_screen.dart';
import 'package:insta_save/screens/widget_screen.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings UI Demo',
      debugShowCheckedModeBanner: false,
      home: const SettingsScreen(),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold, // <-- Added this
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. "Remove Ads" Banner
            _buildRemoveAdsBanner(context),
            const SizedBox(height: 24),

            // 2. "Appearance" Section
            _buildSectionHeader('Appearance'),
            const SizedBox(height: 20),
            _buildListCard(
              children: [
                _buildListTile(
                  Image.asset(
                    'assets/images/st_widgets.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Widgets',
                      () {
                    // This is the action for Widgets
                    print("Widgets tapped!");
                    // You could navigate here:
                    //  Navigator.push(context, MaterialPageRoute(builder: (context) => const WidgetsScreen()));
                    Navigator.of(context).push(createSlideRoute(const WidgetsScreen(), direction: SlideFrom.right));
                      },
                ),
                _buildListTile(
                  Image.asset(
                    'assets/images/st_love.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Send Love',
                      () {
                    // This is the action for Widgets
                    print("Widgets tapped!");
                    // You could navigate here:
                    // Navigator.push(context, MaterialPageRoute(builder: (context) => const WidgetsScreen()));
                  },
                ),
                _buildListTile(
                  Image.asset(
                    'assets/images/st_friend.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Tell a Friend',
                      () {
                    // This is the action for Widgets
                    print("Widgets tapped!");
                    Share.share(
                      'Check out this awesome app! https://www.yourappstorelink.com',
                      subject: 'Look what I found!', // Optional: This is good for emails
                    );
                  },
                ),
                _buildListTile(
                  Image.asset(
                    'assets/images/st_suggetion.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Give a Suggestion',
                      () {
                    // This is the action for Widgets
                    print("Widgets tapped!");
                    Navigator.of(context).push(createSlideRoute(const TutorialScreen(), direction: SlideFrom.right));
                      },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 3. "Permission" Section
            // _buildSectionHeader('Permission'),
            // const SizedBox(height: 12),
            // _buildListCard(
            //   children: [
            //     _buildPermissionTile(),
            //   ],
            // ),
            //const SizedBox(height: 24),

            // 4. "Help & Support" Section
            _buildSectionHeader('Help & Support'),
            const SizedBox(height: 12),
            _buildListCard(
              children: [
                _buildListTile(
                  Image.asset(
                    'assets/images/st_terms.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Terms & Conditions',
                      () {
                        Navigator.of(context).push(createSlideRoute(const WebViewScreen(
                          title: 'Terms of Use',
                          url: 'https://google.com', // <-- Put your real URL here
                        ), direction: SlideFrom.right));
                  },
                ),
                _buildListTile(
                  Image.asset(
                    'assets/images/st_privacy.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Privacy Policy',
                      () {
                        Navigator.of(context).push(createSlideRoute(const WebViewScreen(
                          title: 'Privacy Policy',
                          url: 'https://google.com', // <-- Put your real URL here
                        ), direction: SlideFrom.right));
                  },
                ),
                _buildListTile(
                  Image.asset(
                    'assets/images/st_contact.png', // <-- Change to your asset path
                    width: 35,  // Set a width to match the old icon size
                    height: 35, // Set a height to match the old icon size
                  ),
                  'Contact Us',
                      () {
                        Navigator.of(context).push(createSlideRoute(const WebViewScreen(
                          title: 'Contact Us',
                          url: 'https://google.com', // <-- Put your real URL here
                        ), direction: SlideFrom.right));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for the top "Remove Ads" banner
  Widget _buildRemoveAdsBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF9881F), Color(0xFFE15151)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
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
              fontSize: 12,
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
          'Lorem ipsum dummy text industry',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: () {
          Navigator.of(context).push(createSlideRoute(const SalesScreen(), direction: SlideFrom.right));
        },
      ),
    );
  }

  // Helper widget for section headers (e.g., "Appearance")
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Helper widget for the white, rounded-corner list containers
  Widget _buildListCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      // Use ClipRRect to make sure the ListTile ripples don't go outside the rounded corners
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ListView.separated(
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            // Indent the divider to align with the text
            indent: 56,
          ),
          // We're inside a SingleChildScrollView, so these are needed
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
        ),
      ),
    );
  }

  // Helper widget for a standard list tile with icon, text, and arrow
// Add 'VoidCallback onTap' as a new parameter
  Widget _buildListTile(Widget leadingWidget, String title, VoidCallback onTap) {
    return ListTile(
      leading: leadingWidget,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),

      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 20,
      ),
      onTap: onTap, // <-- Assign the parameter here
    );
  }

  // Specific helper for the "Paste from Other Apps" tile
  // Widget _buildPermissionTile() {
  //   return ListTile(
  //     // This tile doesn't have an icon, so we use title spacing
  //     leading: const SizedBox(width: 0),
  //     title: const Text(
  //       'Paste from Other Apps:',
  //       style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
  //     ),
  //     trailing: Row(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         const Icon(Icons.circle, color: Colors.green, size: 8),
  //         const SizedBox(width: 6),
  //         Text(
  //           'Allowed',
  //           style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
  //         ),
  //         const SizedBox(width: 8),
  //         Icon(
  //           Icons.arrow_forward_ios,
  //           color: Colors.grey.shade400,
  //           size: 16,
  //         ),
  //       ],
  //     ),
  //     onTap: () {
  //       // Handle permission tap
  //     },
  //   );
  // }
}