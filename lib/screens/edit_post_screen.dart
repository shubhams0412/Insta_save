import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditPostScreen extends StatefulWidget {
  final String imagePath;

  const EditPostScreen({super.key, required this.imagePath});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _saveAndNext() async {
    // 1. Validation
    String rawUsername = _usernameController.text.trim();
    if (rawUsername.isEmpty) {
      _showSnackBar("Please enter a username");
      return;
    }

    String rawCaption = _captionController.text.trim();
    if (rawCaption.isEmpty) {
      _showSnackBar("Please enter a caption");
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 2. Format Username
      if (!rawUsername.startsWith('@')) {
        rawUsername = '@$rawUsername';
      }

      // 3. Create Object
      final devicePost = SavedPost(
        localPath: widget.imagePath,
        username: rawUsername,
        caption: rawCaption,
        postUrl: "device_media",
      );

      // 4. Save Locally
      await _savePostToLocal(devicePost);

      // 5. Navigate
      if (mounted) {
        Navigator.of(context).pushReplacement(
          createSlideRoute(
            RepostScreen(
              imageUrl: devicePost.localPath,
              username: devicePost.username,
              initialCaption: devicePost.caption,
              postUrl: devicePost.postUrl,
              localImagePath: devicePost.localPath,
              showDeleteButton: true, // Changed to true so user can manage it later
              showHomeButton: true,
            ),
            direction: SlideFrom.right,
          ),
        );
      }
    } catch (e) {
      _showSnackBar("Error saving post: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePostToLocal(SavedPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('savedPosts') ?? [];

    // Remove duplicates based on path
    existing.removeWhere((item) {
      try {
        final decoded = jsonDecode(item);
        return decoded['localPath'] == post.localPath;
      } catch (e) {
        return false;
      }
    });

    // Add new (Reversed order usually happens in Home, but appending here is fine)
    existing.add(jsonEncode(post.toJson()));
    await prefs.setStringList('savedPosts', existing);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Ensures the keyboard pushes the layout up, but we control how
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildImagePreview(),
                    const SizedBox(height: 30),
                    _buildForm(),
                    // Add extra padding at bottom so keyboard doesn't hide last field
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0),
                  ],
                ),
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Invisible icon to balance the row if needed, or just spacers
          const SizedBox(width: 48),
          const Text(
            "Edit Info",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 28, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 350, // Max height, but allows smaller if image is landscape
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(widget.imagePath),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        // Username Input
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next, // Moves to caption
            decoration: const InputDecoration(
              prefixText: "@",
              prefixStyle: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              hintText: "Type username...",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Caption Input
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _captionController,
            maxLines: 5,
            minLines: 3, // Makes it look like a text area
            textCapitalization: TextCapitalization.sentences, // Capitalize first letters
            decoration: const InputDecoration(
              hintText: "Type caption...",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveAndNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Next",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white)
            ],
          ),
        ),
      ),
    );
  }
}