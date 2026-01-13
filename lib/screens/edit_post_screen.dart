import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
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
  bool _isVideo = false;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _checkIfVideo();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _checkIfVideo() async {
    final path = widget.imagePath.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi')) {
      setState(() => _isVideo = true);
      _videoController = VideoPlayerController.file(File(widget.imagePath));
      try {
        await _videoController!.initialize();
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      } catch (e) {
        debugPrint('Error initializing video: $e');
      }
    }
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
        Navigator.of(context)
            .push(
              createSlideRoute(
                RepostScreen(
                  imageUrl: devicePost.localPath,
                  username: devicePost.username,
                  initialCaption: devicePost.caption,
                  postUrl: devicePost.postUrl,
                  localImagePath: devicePost.localPath,
                  showDeleteButton: false,
                  showHomeButton: true,
                  thumbnailUrl: devicePost.localPath,
                ),
                direction: SlideFrom.right,
              ),
            )
            .then((result) {
              if (mounted) {
                Navigator.of(context).pop(result);
              }
            });
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop({'home': true, 'tab': 2});
      },
      child: Scaffold(
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
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom > 0
                            ? 20
                            : 0,
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomButton(),
            ],
          ),
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
            onPressed: () =>
                Navigator.of(context).pop({'home': true, 'tab': 2}),
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
        child: _isVideo ? _buildVideoPreview() : _buildImageWidget(),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Container(
        height: 200,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_videoController!),
          GestureDetector(
            onTap: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    return Image.file(
      File(widget.imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Container(
        height: 200,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.broken_image, color: Colors.grey),
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
            textCapitalization:
                TextCapitalization.sentences, // Capitalize first letters
            decoration: const InputDecoration(
              hintText: "Type caption...",
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Next",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
