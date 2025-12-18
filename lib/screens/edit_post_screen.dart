import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/navigation_helper.dart';

class EditPostScreen extends StatefulWidget {
  final String imagePath;

  const EditPostScreen({super.key, required this.imagePath});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    String rawUsername = _usernameController.text.trim();

    if (rawUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a username")),
      );
      return;
    }

    String rawCaption = _captionController.text.trim();
    if (rawCaption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a caption")),
      );
      return;
    }

    // ✅ Ensure username starts with @
    // Even though we show it visually with prefixText, we need to save it correctly.
    if (!rawUsername.startsWith('@')) {
      rawUsername = '@$rawUsername';
    }

    // 1. Create the Post Object
    final devicePost = SavedPost(
      localPath: widget.imagePath,
      username: rawUsername, // Use the processed username
      caption: rawCaption,
      postUrl: "device_media", // Mark as device media
    );

    // 2. Save to SharedPreferences
    await _savePostToLocal(devicePost);

    // 3. Navigate to RepostScreen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        createSlideRoute(
          RepostScreen(
            imageUrl: devicePost.localPath,
            username: devicePost.username,
            initialCaption: devicePost.caption,
            postUrl: devicePost.postUrl,
            localImagePath: devicePost.localPath,
            showDeleteButton: false, // Allow deleting this new post
            showHomeButton: true,
          ),
          direction: SlideFrom.right,
        ),
      );
    }
  }

  // Helper function to save (Copied logic from HomeScreen to ensure consistency)
  Future<void> _savePostToLocal(SavedPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('savedPosts') ?? [];

    // Check for duplicates based on file path for device media
    bool isDuplicate = existing.any((item) {
      final decoded = jsonDecode(item);
      return decoded['localPath'] == post.localPath;
    });

    if (isDuplicate) {
      existing.removeWhere((item) {
        final decoded = jsonDecode(item);
        return decoded['localPath'] == post.localPath;
      });
    }

    existing.add(jsonEncode(post.toJson()));
    await prefs.setStringList('savedPosts', existing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER (Close Button) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 28, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // --- SCROLLABLE CONTENT ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Image Preview
                    Container(
                      height: 350,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        image: DecorationImage(
                          image: FileImage(File(widget.imagePath)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Username Field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          prefixText: "@", // ✅ Visually adds @ before typing
                          prefixStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.normal
                          ),
                          hintText: "Type username...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Caption Field
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _captionController,
                        maxLines: null, // Allow multiline
                        decoration: const InputDecoration(
                          hintText: "Type caption...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            // --- BOTTOM BUTTON ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveAndNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Next",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}