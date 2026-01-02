import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:insta_save/services/navigation_helper.dart';

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
        title: const Text("Delete Items?"),
        content: Text(
          "Are you sure you want to delete ${_selectedPaths.length} items?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performDeletion();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeletion() async {
    setState(() => _isDeleting = true);

    try {
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'savedPosts'},
        ),
      );
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];

      // 1. Filter and Delete in one pass
      final List<String> updatedData = [];

      for (var itemJson in savedData) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(itemJson);
          final String path = decoded['localPath'];

          if (_selectedPaths.contains(path)) {
            // Delete actual file
            try {
              final file = File(path);
              if (file.existsSync()) file.deleteSync();
            } catch (e) {
              debugPrint("⚠️ File delete error: $e");
            }
          } else {
            // Keep this item
            updatedData.add(itemJson);
          }
        } catch (e) {
          // If JSON is corrupt, maybe don't keep it, or keep it safe.
          // Here we keep it to prevent accidental data loss of good items.
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Items deleted successfully")),
        );
      }
    } catch (e) {
      debugPrint("❌ Critical delete error: $e");
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    // Intercept Back Button to cancel selection mode first
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvoked: (didPop) {
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
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
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
          Icon(
            Icons.perm_media_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text("No media found", style: TextStyle(color: Colors.grey.shade500)),
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
          onTap: () {
            if (_isSelectionMode) {
              _toggleItemSelection(post.localPath);
            } else {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.of(context)
                  .push(
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
                  )
                  .then((deleted) async {
                    // If item was deleted, remove from list
                    if (deleted == true) {
                      setState(() {
                        _currentList.removeWhere((item) {
                          final p = item['data'] as SavedPost;
                          return p.localPath == post.localPath;
                        });
                      });
                    }
                  });
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
            borderRadius: BorderRadius.circular(12),
            child: _buildThumbnail(),
          ),

          // 2. Selection Overlay
          if (isSelectionMode) ...[
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
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
