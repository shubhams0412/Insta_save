import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insta_save/services/saved_post.dart'; // Adjust path if needed
import 'package:insta_save/services/navigation_helper.dart'; // Adjust path if needed

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

  @override
  void initState() {
    super.initState();
    _currentList = List.from(widget.mediaList);
  }

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

  Future<void> _deleteSelectedItems() async {
    if (_selectedPaths.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Selected?"),
        content: Text("Are you sure you want to delete ${_selectedPaths.length} items?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _performDeletion();
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED DELETION LOGIC
  Future<void> _performDeletion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];

      print("🗑️ Attempting to delete ${_selectedPaths.length} items.");

      // 1. Remove from SharedPreferences
      savedData.removeWhere((itemJson) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(itemJson);
          final String path = decoded['localPath'];

          // Check if this item is selected for deletion
          if (_selectedPaths.contains(path)) {
            // ✅ FIX: Wrap file deletion in its own try-catch.
            // This ensures that even if the file is missing/locked,
            // we STILL remove the entry from the list.
            try {
              final file = File(path);
              if (file.existsSync()) {
                file.deleteSync();
                print("✅ Deleted file: $path");
              }
            } catch (fileError) {
              print("⚠️ File deletion error (ignoring for list update): $fileError");
            }

            return true; // ✅ ALWAYS remove from list if selected
          }
          return false; // Keep in list
        } catch (e) {
          print("⚠️ Error decoding item during delete: $e");
          return false;
        }
      });

      // 2. Save updated list back to Prefs
      await prefs.setStringList('savedPosts', savedData);

      // 3. Update UI
      setState(() {
        _currentList.removeWhere((item) {
          final post = item['data'] as SavedPost;
          return _selectedPaths.contains(post.localPath);
        });
        _selectedPaths.clear();
        if (_currentList.isEmpty) _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Items deleted successfully")),
        );
      }
    } catch (e) {
      print("❌ Critical error during deletion: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isSelectionMode ? "${_selectedPaths.length} Selected" : widget.title,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSelectionMode) ...[
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _selectedPaths.length == _currentList.length ? "Deselect All" : "Select All",
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _selectedPaths.isNotEmpty ? _deleteSelectedItems : null,
            ),
          ] else ...[
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
      ),
      body: _currentList.isEmpty
          ? const Center(child: Text("No Items"))
          : GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        itemCount: _currentList.length,
        itemBuilder: (context, index) {
          final postMap = _currentList[index];
          return _buildGridItem(context, postMap);
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, Map<String, dynamic> postMap) {
    final post = postMap['data'] as SavedPost;
    final thumbPath = postMap['thumbPath'] as String?;
    final bool isVideoItem = postMap['type'] == 'video';

    final bool isSelected = _selectedPaths.contains(post.localPath);

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleItemSelection(post.localPath);
        } else {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).push(
            createSlideRoute(
              RepostScreen(
                imageUrl: post.localPath,
                username: post.username,
                initialCaption: post.caption,
                postUrl: post.postUrl,
                localImagePath: post.localPath,
                showDeleteButton: true,
              ),
              direction: SlideFrom.bottom,
            ),
          );
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleItemSelection(post.localPath);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          isVideoItem
              ? _buildReelItem(post, thumbPath)
              : _buildImageItem(post),

          if (_isSelectionMode) ...[
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
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

  Widget _buildImageItem(SavedPost post) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(post.localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.grey),
      ),
    );
  }

  Widget _buildReelItem(SavedPost post, String? thumbPath) {
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: thumbPath != null
              ? Image.file(File(thumbPath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity)
              : Container(
              color: Colors.grey[300],
              width: double.infinity,
              height: double.infinity),
        ),
        const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
      ],
    );
  }
}