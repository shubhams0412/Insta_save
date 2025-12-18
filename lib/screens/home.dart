import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Required for Uint8List

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

// ✅ Corrected Imports (No double slashes)
import 'package:insta_save/screens/preview_screen.dart';
import 'package:insta_save/screens/tutorial_screen.dart';
import 'package:insta_save/screens/all_media_screen.dart';
import 'package:insta_save/screens/edit_post_screen.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/screens/setting_screen.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/download_manager.dart';

import '../widgets/status_dialog.dart';
import '_buildStepCard.dart'; // ✅ Added Manager

class HomeScreen extends StatefulWidget {

  final int initialTabIndex;

  const HomeScreen({super.key, this.initialTabIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();

  List<SavedPost> _savedPosts = [];
  List<Map<String, dynamic>>? _separatedMedia;
  bool _isLoadingMedia = true;

  static const String _releaseBaseUrl = "http://13.200.64.163:9081/";
  static const String _debugBaseUrl = "http://13.200.64.163:9081/";

  String get _apiBaseUrl => kReleaseMode ? _releaseBaseUrl : _debugBaseUrl;

  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(() {
      setState(() {});
    });

    // 1. Initial Load: Show Spinner (TRUE)
    _loadSavedPosts();
    _loadSeparatedMedia(isInitialLoad: true);

    // 2. Download Listener: Silent Refresh (FALSE)
    _downloadSubscription = DownloadManager.instance.onTaskCompleted.listen((_) {
      _loadSavedPosts();
      _loadSeparatedMedia(isInitialLoad: false); // Background update
    });
  }


  @override
  void dispose() {
    // ✅ Cancel the listener to avoid memory leaks
    _downloadSubscription?.cancel();

    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            "InstaSave",
            style: TextStyle(
              fontFamily: "InstaFont",
              fontSize: 28,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings, size: 26, color: Colors.black87),
              onPressed: () {
                navigateToSettingScreen();
              },
            ),
            const SizedBox(width: 16),
          ],
        ),

        // ✅ WRAP BODY IN ANIMATED BUILDER TO LISTEN TO DOWNLOADS
        body: AnimatedBuilder(
          animation: DownloadManager.instance,
          builder: (context, child) {

            // 1. Filter Active Downloads
            final activeImages = DownloadManager.instance.activeTasks
                .where((t) => t.type == 'image').toList();
            final activeVideos = DownloadManager.instance.activeTasks
                .where((t) => t.type == 'video').toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- FIXED TOP CONTENT ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(context).push(createSlideRoute(
                              const TutorialScreen(),
                              direction: SlideFrom.right));
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline,
                                  color: Colors.amber, size: 28),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("How to Repost a Post?",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    Text(
                                        "Discover step-by-step guidance with our guide.",
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _gradientButton(
                              title: "Import from Insta",
                              colors: const [Color(0xFFEE2A7B), Color(0xFF7F2BCB)],
                              icon: Icons.camera_alt_outlined,
                              onTap: () {
                                showTutorialDialog(context);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _gradientButton(
                              title: "Select Pics & Repost",
                              colors: const [Color(0xFF4A90E2), Color(0xFF50E3C2)],
                              icon: Icons.repeat,
                              onTap: () {
                                pickImageFromGallery();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: TextField(
                                controller: _linkController,
                                autofocus: false,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Paste a link here",
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _linkController.text.isEmpty
                              ? GestureDetector(
                            onTap: pasteInstagramLink,
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Row(
                                  children: [
                                    Icon(Icons.link, size: 18, color: Colors.black87),
                                    SizedBox(width: 6),
                                    Text("Paste link", style: TextStyle(color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                          )
                              : GestureDetector(
                            onTap: () {
                              navigateToPreviewScreen(context, _linkController);
                            },
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade200,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_forward, size: 18, color: Colors.black87),
                                    SizedBox(width: 6),
                                    Text("Go", style: TextStyle(color: Colors.black87)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- EXPANDED SCROLLABLE BOTTOM ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          "Reposted Media",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const TabBar(
                        indicatorColor: Colors.black,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(text: "Posts"),
                          Tab(text: "Reels"),
                          Tab(text: "Device Media"),
                        ],
                      ),
                      Expanded(
                        child: _isLoadingMedia
                            ? const Center(
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                        )
                            : TabBarView(
                          children: [
                            // --- POSTS TAB (ACTIVE + SAVED) ---
                            _buildLimitedGrid(
                              activeTasks: activeImages,
                              mediaList: _separatedMedia!
                                  .where((m) =>
                              m['type'] == 'image' &&
                                  (m['data'] as SavedPost).postUrl != "device_media")
                                  .toList(),
                              viewAllTitle: "All Posts",
                            ),

                            // --- REELS TAB (ACTIVE + SAVED) ---
                            _buildLimitedGrid(
                              activeTasks: activeVideos,
                              mediaList: _separatedMedia!
                                  .where((m) =>
                              m['type'] == 'video' &&
                                  (m['data'] as SavedPost).postUrl != "device_media")
                                  .toList(),
                              viewAllTitle: "All Reels",
                            ),

                            // --- DEVICE MEDIA TAB ---
                            _buildLimitedGrid(
                              activeTasks: [],
                              mediaList: _separatedMedia!
                                  .where((m) => (m['data'] as SavedPost).postUrl == "device_media")
                                  .toList(),
                              viewAllTitle: "All Device Media",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLimitedGrid({
    required List<DownloadTask> activeTasks,
    required List<Map<String, dynamic>> mediaList,
    required String viewAllTitle,
  }) {

    // 1. FILTER SAVED LIST
    // If an item is currently in 'activeTasks' (even if 100% done),
    // hide it from the 'mediaList' so we don't see duplicates.
    final filteredMediaList = mediaList.where((media) {
      final savedPost = media['data'] as SavedPost;
      // Return TRUE (keep it) only if it is NOT in the active list
      bool isActive = activeTasks.any((task) => task.localPath == savedPost.localPath);
      return !isActive;
    }).toList();

    // 2. Total Count combines Active + Filtered Saved
    int totalCount = activeTasks.length + filteredMediaList.length;

    if (totalCount == 0) {
      return const Center(child: Text("No media found."));
    }

    int displayCount = totalCount > 6 ? 6 : totalCount;
    bool showViewAll = totalCount > 6;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {

            // RENDER ACTIVE TASKS FIRST (Includes the 100% done ones)
            if (index < activeTasks.length) {
              return _buildDownloadingItem(activeTasks[index]);
            }

            // RENDER SAVED MEDIA (Skipping the ones currently active)
            int savedIndex = index - activeTasks.length;
            return _buildGridItem(filteredMediaList[savedIndex]);
          },
        ),

        // ... [View All Button Code remains the same] ...
        if (showViewAll)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TextButton(
              onPressed: () async {
                await Navigator.of(context).push(createSlideRoute(
                  AllMediaScreen(title: viewAllTitle, mediaList: filteredMediaList), // Use filtered list
                  direction: SlideFrom.right,
                ));
                _loadSavedPosts();
                _loadSeparatedMedia();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("View All", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ✅ NEW: Widget for Downloading Items (Progress Bar)
  Widget _buildDownloadingItem(DownloadTask task) {

    // --- 1. COMPLETED STATE ---
    if (task.isCompleted || task.progress >= 1.0) {

      // Determine what image provider to use
      ImageProvider? imageProvider;

      if (task.type == 'video') {
        // 🎥 FOR VIDEO: Always use the network thumbnail
        // (We can't put an .mp4 file into an Image widget)
        if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty) {
          imageProvider = NetworkImage(task.thumbnailUrl!);
        }
      } else {
        // 📸 FOR IMAGE: Use the high-quality local file
        if (task.localPath != null && File(task.localPath!).existsSync()) {
          imageProvider = FileImage(File(task.localPath!));
        } else if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty) {
          // Fallback to network if local file missing
          imageProvider = NetworkImage(task.thumbnailUrl!);
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. The Image (Thumbnail or Local File)
            if (imageProvider != null)
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
              )
            else
              Container(color: Colors.grey[300]),

            // 2. Play Icon (Only for videos)
            if (task.type == 'video')
              const Center(
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
              ),
          ],
        ),
      );
    }

    // --- 2. DOWNLOADING STATE (Unchanged) ---
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty
              ? Image.network(
            task.thumbnailUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
          )
              : Container(color: Colors.grey[300]),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                value: task.progress,
                color: Colors.white,
                strokeWidth: 3,
                backgroundColor: Colors.white24,
              ),
              const SizedBox(height: 6),
              Text(
                "${(task.progress * 100).toInt()}%",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget for Saved Items (Clickable)
  Widget _buildGridItem(Map<String, dynamic> postMap) {
    final post = postMap['data'] as SavedPost;
    final thumbPath = postMap['thumbPath'] as String?;
    final bool isVideoItem = postMap['type'] == 'video';

    return GestureDetector(
      onTap: () {
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
        ).then((_) {
          _loadSavedPosts();
          _loadSeparatedMedia(isInitialLoad: false);
        });
      },
      child: isVideoItem
          ? _buildReelGridItem(post, thumbPath)
          : _buildImageGridItem(post),
    );
  }

  Widget _buildImageGridItem(SavedPost post) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(post.localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.grey),
      ),
    );
  }

  Widget _buildReelGridItem(SavedPost post, String? thumbPath) {
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

  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditPostScreen(imagePath: image.path),
          ),
        ).then((_) {
          _loadSavedPosts();
          _loadSeparatedMedia();
        });
      }
    }
  }

  void pasteInstagramLink() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      if (data.text!.contains("instagram.com/")) {
        _linkController.text = data.text!;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Please copy a valid Instagram link"),
          ),
        );
      }
    }
  }

  // ✅ UPDATED NAVIGATION: Fetches JSON only, pushes PreviewScreen
  Future<void> navigateToPreviewScreen(
      BuildContext context,
      TextEditingController linkController,
      )
  async {
    String link = linkController.text.trim();

    if (!link.contains("instagram.com/")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please enter a valid Instagram link")),
      );
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No Internet Connection")),
      );
      return;
    }

    double fakeProgress = 0.0;
    Timer? progressTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            // Start the timer ONLY ONCE when dialog opens
            progressTimer ??= Timer.periodic(const Duration(milliseconds: 100), (timer) {
                // Simulate progress up to 90%
                if (fakeProgress < 0.95) {
                  setDialogState(() {
                    fakeProgress += 0.01; // Increment by 5%
                  });
                } else {
                  timer.cancel(); // Stop at 90% while waiting for API
                }
              });

            return StatusDialog(
              type: DialogType.fetching,
              progress: fakeProgress, // ✅ Pass simulated progress
            );
          },
        );
      },
    );

    try {
      final String apiUrl = "${_apiBaseUrl}download_media";
      String deviceId = await _getDeviceId();

      final Map<String, String> params = {
        "instagramURL": link,
        "deviceId": deviceId,
      };

      final response = await http
          .post(Uri.parse(apiUrl), body: params)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Uint8List responseBytes = response.bodyBytes;
        final String utf8Body = utf8.decode(responseBytes);
        final data = jsonDecode(utf8Body);
        final responseData = data["data"];

        if (responseData == null ||
            responseData["postData"] == null ||
            responseData["postData"].isEmpty) {
          throw Exception("No post data available");
        }

        final List<dynamic> postDataList = responseData["postData"];
        final String username = responseData["username"] ?? "unknown";
        final String caption = responseData["caption"] ?? "";

        // Extract URLs
        List<Map<String, String>> mediaItems = [];
        for (var p in postDataList) {
          if (p["link"] != null && p["link"].toString().isNotEmpty) {
            mediaItems.add({
              "url": p["link"],
              "thumbnail": p["thumbnail"] ?? "",
              "type": p["type"] ?? "image",
            });
          }
        }

        if (mediaItems.isEmpty) throw Exception("No media URLs found");

        progressTimer?.cancel();

        if (context.mounted) Navigator.of(context).pop(); // Close Loading

        _linkController.clear();
        FocusManager.instance.primaryFocus?.unfocus();

        // Navigate
        if (context.mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).push(
            createSlideRoute(
              PreviewScreen(
                mediaItems: mediaItems,
                username: username,
                caption: caption,
                postUrl: link,
              ),
              direction: SlideFrom.bottom,
            ),
          ).then((_) {
            FocusManager.instance.primaryFocus?.unfocus();
            // ✅ Refresh when coming back from Preview
            _loadSavedPosts();
            _loadSeparatedMedia(isInitialLoad: false);
          });
        }
      } else {
        throw Exception("Server error (${response.statusCode})");
      }
    } catch (e) {
      progressTimer?.cancel();
      if (context.mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }

  void navigateToSettingScreen() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(createSlideRoute(const SettingsScreen(), direction: SlideFrom.right));
  }

  Future<String> _getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? "unknown_ios_device";
      } else if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (e) {
      print("Failed to get device ID: $e");
    }
    return "unknown_device";
  }

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();

    // Safety clean
    final dynamic savedRaw = prefs.get('savedPosts');
    if (savedRaw is String) {
      await prefs.remove('savedPosts');
    }

    final savedData = prefs.getStringList('savedPosts') ?? [];
    try {
      final List<SavedPost> loadedPosts = savedData.map((json) {
        final Map<String, dynamic> decoded =
        Map<String, dynamic>.from(jsonDecode(json));
        return SavedPost.fromJson(decoded);
      }).toList();

      setState(() {
        _savedPosts = loadedPosts;
      });
    } catch (e) {
      print("❌ Error parsing saved posts: $e");
    }
  }

  Widget _gradientButton({
    required String title,
    required List<Color> colors,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSeparatedMedia() async {
    List<Map<String, dynamic>> separated = [];

    // Use reversed so newest posts appear first
    for (final post in _savedPosts.reversed) {
      final path = post.localPath;

      // Basic check if file exists to avoid ghost items
      if (!File(path).existsSync()) continue;

      if (path.toLowerCase().endsWith(".mp4")) {
        String? thumbPath;
        try {
          // Try generating thumbnail
          thumbPath = await VideoThumbnail.thumbnailFile(
            video: path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            quality: 75,
          );
        } catch (e) {
          print("⚠️ Could not generate thumbnail for $path: $e");
        }

        separated.add({
          "type": "video",
          "data": post,
          "thumbPath": thumbPath, // It's okay if this is null
        });
      } else {
        separated.add({
          "type": "image",
          "data": post,
        });
      }
    }
    return separated;
  }

// ✅ UPDATED: Silent Refresh Logic
// ✅ UPDATED: Silent Refresh Logic
  Future<void> _loadSeparatedMedia({bool isInitialLoad = false}) async {
    // Only show the big spinner on the VERY FIRST load of the app.
    // Otherwise, keep showing the current list while we update in background.
    if (isInitialLoad) {
      setState(() => _isLoadingMedia = true);
    }

    try {
      // Add a tiny delay to let the UI settle if coming back from another screen
      await Future.delayed(const Duration(milliseconds: 50));

      final newData = await _getSeparatedMedia();

      if (mounted) {
        setState(() {
          _separatedMedia = newData;
          _isLoadingMedia = false; // Always turn off spinner when done
        });
      }
    } catch (e) {
      print("Error loading media: $e");
      if (mounted) setState(() => _isLoadingMedia = false);
    }
  }
}