import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/utils/ui_utils.dart';

class AllMediaScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> mediaList;

  const AllMediaScreen({
    super.key,
    required this.title,
    required this.mediaList,
  });

  @override
  State<AllMediaScreen> createState() => _AllMediaScreenState();
}

class _AllMediaScreenState extends State<AllMediaScreen> {
  late List<Map<String, dynamic>> _currentList;
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _currentList = List.from(widget.mediaList);
  }

  // --- LOGIC: Selection ---

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedPaths.clear();
    });
  }

  void _toggleItemSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
      // Auto-exit selection mode if nothing is left
      if (_selectedPaths.isEmpty && _isSelectionMode) {
        // Optional: Uncomment next line if you want to exit mode when empty
        // _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedPaths.length == _currentList.length) {
        _selectedPaths.clear();
      } else {
        _selectedPaths.clear();
        for (var item in _currentList) {
          final post = item['data'] as SavedPost;
          _selectedPaths.add(post.localPath);
        }
      }
    });
  }

  // --- LOGIC: Deletion ---

  Future<void> _showDeleteConfirmation() async {
    if (_selectedPaths.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "Delete Items?",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          "Are you sure you want to delete ${_selectedPaths.length} items?",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "No",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeletion();
            },
            child: const Text(
              "Yes",
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletion() async {
    setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];

      // 1. Filter and Delete in one pass
      final List<String> updatedData = [];

      for (var itemJson in savedData) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(itemJson);
          final String path = decoded['localPath'];

          if (_selectedPaths.contains(path)) {
            // Attempt to delete physical file
            final file = File(path);
            if (file.existsSync()) {
              try {
                file.deleteSync();
              } catch (e) {
                debugPrint("⚠️ Could not delete physical file: $e");
              }
            } else {
              debugPrint("ℹ️ File already missing from storage: $path");
            }
            // Even if file is missing, we proceed to remove it from our database
          } else {
            // Keep this item
            updatedData.add(itemJson);
          }
        } catch (e) {
          updatedData.add(itemJson);
        }
      }

      // 2. Save Updated List
      await prefs.setStringList('savedPosts', updatedData);

      // 3. Update UI
      if (mounted) {
        setState(() {
          _currentList.removeWhere((item) {
            final post = item['data'] as SavedPost;
            return _selectedPaths.contains(post.localPath);
          });
          _selectedPaths.clear();
          _isSelectionMode = false;
          _isDeleting = false;
        });

        UIUtils.showSnackBar(context, 'Items deleted successfully');
      }
    } catch (e) {
      debugPrint("❌ Critical delete error: $e");
      if (mounted) {
        setState(() => _isDeleting = false);
        UIUtils.showSnackBar(context, "Error: $e");
      }
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    // Intercept Back Button to cancel selection mode first
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _toggleSelectionMode();
        } else {
          // ✅ Return the updated list here as well (for physical back button)
          Navigator.pop(context, _currentList);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _isDeleting
            ? const Center(
                child: CircularProgressIndicator(color: Colors.black),
              )
            : _currentList.isEmpty
            ? _buildEmptyState()
            : _buildGrid(),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.grey,
          size: 20,
        ),
        onPressed: () {
          if (_isSelectionMode) {
            _toggleSelectionMode();
          } else {
            Navigator.pop(context, _currentList);
          }
        },
      ),
      title: Text(
        _isSelectionMode ? "${_selectedPaths.length} Selected" : widget.title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      actions: [
        if (_isSelectionMode) ...[
          TextButton(
            onPressed: _toggleSelectAll,
            child: Text(
              _selectedPaths.length == _currentList.length
                  ? "Deselect All"
                  : "Select All",
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _selectedPaths.isNotEmpty
                ? _showDeleteConfirmation
                : null,
          ),
        ] else if (_currentList.isNotEmpty) ...[
          TextButton(
            onPressed: _toggleSelectionMode,
            child: const Text(
              "Select",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/placeholder.png', width: 50, height: 50),
          const SizedBox(height: 14),
          const Text(
            "You haven't shared\nany media yet.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        // 1.0 makes items square. Change to 0.7 if you prefer tall rectangles.
        childAspectRatio: 1.0,
      ),
      itemCount: _currentList.length,
      itemBuilder: (context, index) {
        final postMap = _currentList[index];
        final post = postMap['data'] as SavedPost;

        return MediaGridItem(
          post: post,
          thumbPath: postMap['thumbPath'] as String?,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedPaths.contains(post.localPath),
          isVideo: postMap['type'] == 'video',
          onTap: () async {
            if (_isSelectionMode) {
              _toggleItemSelection(post.localPath);
            } else {
              FocusManager.instance.primaryFocus?.unfocus();
              final result = await Navigator.of(context).push(
                createSlideRoute(
                  RepostScreen(
                    imageUrl: post.localPath,
                    username: post.username,
                    initialCaption: post.caption,
                    postUrl: post.postUrl,
                    localImagePath: post.localPath,
                    showDeleteButton: true,
                    thumbnailUrl: postMap['thumbPath'] as String,
                  ),
                  direction: SlideFrom.bottom,
                ),
              );

              if (!context.mounted) return;

              // If result is Map and has home flag, pop back to home with the result
              if (result is Map && result['home'] == true) {
                Navigator.of(context).pop(result);
              } else if (result == true) {
                // If item was deleted, remove from list
                setState(() {
                  _currentList.removeWhere((item) {
                    final p = item['data'] as SavedPost;
                    return p.localPath == post.localPath;
                  });
                });
              }
            }
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode();
              _toggleItemSelection(post.localPath);
            }
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// 🔹 Helper Widget: Media Grid Item (Extracted for performance)
// -----------------------------------------------------------------------------
class MediaGridItem extends StatelessWidget {
  final SavedPost post;
  final String? thumbPath;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isVideo;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const MediaGridItem({
    super.key,
    required this.post,
    this.thumbPath,
    required this.isSelectionMode,
    required this.isSelected,
    required this.isVideo,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image/Video Thumb
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildThumbnail(),
          ),

          // Username Overlay
          _buildUsernameOverlay(post.username),

          // 2. Selection Overlay
          if (isSelectionMode) ...[
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? Colors.blue : Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsernameOverlay(String username) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
            ),
          ),
          child: Text(
            "@${username.replaceAll('@', '')}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (isVideo) {
      return Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          thumbPath != null
              ? Image.file(
                  File(thumbPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[300]),
                )
              : Container(color: Colors.grey[300]),
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
        ],
      );
    } else {
      return Image.file(
        File(post.localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
  }
}
