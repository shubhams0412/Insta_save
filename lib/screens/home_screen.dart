import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:insta_save/screens/all_media_screen.dart';
import 'package:insta_save/screens/edit_post_screen.dart';
import 'package:insta_save/screens/preview_screen.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/screens/setting_screen.dart';
import 'package:insta_save/screens/tutorial_screen.dart';
import 'package:insta_save/services/download_manager.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/saved_post.dart';

import '../services/instagram_login_webview.dart';
import '../widgets/status_dialog.dart';
import '_buildStepCard.dart';

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

  // Optimized: Define URL once if they are the same, or keep separate for future proofing
  static const String _apiBaseUrl = "http://13.200.64.163:9081/";

  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(() {
      setState(() {});
    });

    // Initial Load: Show Spinner (true)
    _initGalleryData();

    // Download Finished: Silent Refresh (false)
    _downloadSubscription = DownloadManager.instance.onTaskCompleted.listen((_) async {
      _refreshGalleryDataSilently();
    });
  }
  Future<void> _refreshGalleryDataSilently() async {
    // 1. Fetch raw data from Prefs
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getStringList('savedPosts') ?? [];

    final List<SavedPost> loadedPosts = savedData.map((json) {
      return SavedPost.fromJson(Map<String, dynamic>.from(jsonDecode(json)));
    }).toList();

    // 2. Process thumbnails and separation WITHOUT calling setState yet
    final newData = await _getSeparatedMediaFromList(loadedPosts);

    // 3. Update the UI exactly once
    if (mounted) {
      setState(() {
        _savedPosts = loadedPosts;
        _separatedMedia = newData;
        _isLoadingMedia = false;
      });
    }
  }

  Future<void> _initGalleryData() async {
    await _loadSavedPosts();
    await _loadSeparatedMedia(isInitialLoad: true); // Show spinner first time
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Structure: Clean Scaffolding
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),

        // 2. Logic: Removed global AnimatedBuilder.
        // Only the bottom section listens to downloads now.
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- STATIC TOP SECTION (Won't rebuild on download) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildTutorialCard(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                  _buildLinkInput(),
                  const SizedBox(height: 20),
                ],
              ),
            ),

            // --- DYNAMIC BOTTOM SECTION (Rebuilds on download/tab change) ---
            Expanded(
              child: _buildMediaTabsSection(),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent, // Fixes M3 scroll tint
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
          onPressed: navigateToSettingScreen,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  // --- WIDGET: Tutorial Card ---
  Widget _buildTutorialCard() {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.of(context).push(
            createSlideRoute(const TutorialScreen(), direction: SlideFrom.right));
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("How to Repost a Post?",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Discover step-by-step guidance with our guide.",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Action Buttons (Gradient) ---
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _gradientButton(
            title: "Import from Insta",
            colors: const [Color(0xFFEE2A7B), Color(0xFF7F2BCB)],
            icon: Icons.camera_alt_outlined,
            onTap: () => showTutorialDialog(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _gradientButton(
            title: "Select Pics & Repost",
            colors: const [Color(0xFF4A90E2), Color(0xFF50E3C2)],
            icon: Icons.repeat,
            onTap: pickImageFromGallery,
          ),
        ),
      ],
    );
  }

  // --- WIDGET: Link Input ---
  Widget _buildLinkInput() {
    return Row(
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

        // Optimization: Only rebuild this button when text changes, not the whole screen
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _linkController,
          builder: (context, value, child) {
            final hasText = value.text.isNotEmpty;
            return GestureDetector(
              onTap: hasText
                  ? () => navigateToPreviewScreen(context, _linkController)
                  : pasteInstagramLink,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: hasText ? Colors.blue.shade200 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Row(
                    children: [
                      Icon(
                        hasText ? Icons.arrow_forward : Icons.link,
                        size: 18,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasText ? "Go" : "Paste link",
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- WIDGET: Media Tabs (The part that listens to downloads) ---
  Widget _buildMediaTabsSection() {
    // ✅ DEFINE DATA HERE (FIXES ALL ERRORS)
    final media = _separatedMedia ?? [];

    final activeImages = DownloadManager.instance.activeTasks.where((task) {
      final existsInSaved = media.any((m) {
        final post = m['data'] as SavedPost;
        return post.localPath == task.localPath;
      });
      return task.type == 'image' && !existsInSaved;
    }).toList();

    final activeVideos = DownloadManager.instance.activeTasks.where((task) {
      final existsInSaved = media.any((m) {
        final post = m['data'] as SavedPost;
        return post.localPath == task.localPath;
      });
      return task.type == 'video' && !existsInSaved;
    }).toList();

    return Column(
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
            child: CircularProgressIndicator(color: Colors.black),
          )
              : TabBarView(
            children: [
              // POSTS
              _buildLimitedGrid(
                activeTasks: activeImages,
                mediaList: media
                    .where((m) =>
                m['type'] == 'image' &&
                    (m['data'] as SavedPost).postUrl != "device_media")
                    .toList(),
                viewAllTitle: "All Posts",
              ),

              // REELS
              _buildLimitedGrid(
                activeTasks: activeVideos,
                mediaList: media
                    .where((m) =>
                m['type'] == 'video' &&
                    (m['data'] as SavedPost).postUrl != "device_media")
                    .toList(),
                viewAllTitle: "All Reels",
              ),

              // DEVICE MEDIA
              _buildLimitedGrid(
                activeTasks: const [],
                mediaList: media
                    .where((m) =>
                (m['data'] as SavedPost).postUrl == "device_media")
                    .toList(),
                viewAllTitle: "All Device Media",
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildLimitedGrid({
    required List<DownloadTask> activeTasks,
    required List<Map<String, dynamic>> mediaList,
    required String viewAllTitle,
  }) {
    // 1. DEDUPLICATION
    final filteredMediaList = mediaList.where((media) {
      final savedPost = media['data'] as SavedPost;
      return !activeTasks.any((task) => task.localPath == savedPost.localPath);
    }).toList();

    int totalCount = activeTasks.length + filteredMediaList.length;

    if (totalCount == 0) {
      return const Center(child: Text("No media found."));
    }

    // Determine how many items to show (Max 6)
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
            if (index < activeTasks.length) {
              // Prefix with 'task' to ensure no overlap with file paths
              return KeyedSubtree(
                key: ValueKey("task_${activeTasks[index].id}"),
                child: _buildDownloadingItem(activeTasks[index]),
              );
            }

            int savedIndex = index - activeTasks.length;
            final post = filteredMediaList[savedIndex]['data'] as SavedPost;

            return KeyedSubtree(
              key: ValueKey("saved_${post.localPath}"),
              child: _buildGridItem(filteredMediaList[savedIndex]),
            );
          },
        ),

        if (showViewAll)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TextButton(
              // Inside HomeScreen (usually in the _buildLimitedGrid or similar)
              onPressed: () async {
                // ✅ Catch the returned list from AllMediaScreen
                final updatedMedia = await Navigator.of(context).push(createSlideRoute(
                  AllMediaScreen(title: viewAllTitle, mediaList: filteredMediaList),
                  direction: SlideFrom.right,
                ));

                // ✅ If data was returned, update the home state silently
                if (updatedMedia != null && updatedMedia is List<Map<String, dynamic>>) {
                  setState(() {
                    // We don't call _loadSavedPosts() because it triggers a disk read.
                    // We simply update the local _separatedMedia list.
                    _separatedMedia = updatedMedia;
                  });
                } else {
                  // Fallback: If they deleted something via the RepostScreen inside AllMedia,
                  // run the silent refresh we built earlier.
                  _refreshGalleryDataSilently();
                }
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
                  Text("View All",
                      style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

  Widget _buildDownloadingItem(DownloadTask task) {
    return ValueListenableBuilder<bool>(
      valueListenable: task.isCompleted,
      builder: (context, done, _) {
        if (done) {
          return _buildFinalDownloadedItem(task);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty
                  ? Image.network(
                task.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.grey[300]),
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
                  ValueListenableBuilder<double>(
                    valueListenable: task.progress,
                    builder: (context, progress, _) {
                      return CircularProgressIndicator(
                        value: progress,
                        color: Colors.white,
                        strokeWidth: 3,
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<double>(
                    valueListenable: task.progress,
                    builder: (context, progress, _) {
                      return Text(
                        "${(progress * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }


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
        errorBuilder: (_, __, ___) =>
        const Icon(Icons.error, color: Colors.grey),
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

  // --- ACTIONS ---

  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
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

  void pasteInstagramLink() async {
    final data = await Clipboard.getData('text/plain');
    if (data != null && data.text != null) {
      if (data.text!.contains("instagram.com/")) {
        _linkController.text = data.text!;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Please copy a valid Instagram link")),
        );
      }
    }
  }

  Future<void> navigateToPreviewScreen(
      BuildContext context,
      TextEditingController linkController,
      ) async {
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
    final prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isInstagramLoggedIn') ?? false;

    if (!isLoggedIn) {
      // User is not logged in, open the Login Webview
      bool success = await openInstaLogin(context);
      if (!success) {
        // User cancelled login or failed, so we stop here.
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("⚠️ Login required to download content")),
          );
        }
        return;
      }
      // If success == true, proceed to download!
    }
    double fakeProgress = 0.0;
    Timer? progressTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            progressTimer ??=
                Timer.periodic(const Duration(milliseconds: 100), (timer) {
                  if (fakeProgress < 0.95) {
                    setDialogState(() => fakeProgress += 0.01);
                  } else {
                    timer.cancel();
                  }
                });
            return StatusDialog(
                type: DialogType.fetching, progress: fakeProgress);
          },
        );
      },
    );

    try {
      final String apiUrl = "${_apiBaseUrl}download_media";
      String deviceId = await _getDeviceId();

      final response = await http.post(
        Uri.parse(apiUrl),
        body: {"instagramURL": link, "deviceId": deviceId},
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final responseData = data["data"];

        if (responseData == null ||
            responseData["postData"] == null ||
            responseData["postData"].isEmpty) {
          throw Exception("No post data available");
        }

        final List<dynamic> postDataList = responseData["postData"];
        final String username = responseData["username"] ?? "unknown";
        final String caption = responseData["caption"] ?? "";

        List<Map<String, String>> mediaItems = [];
        for (var p in postDataList) {
          if (p["link"]?.toString().isNotEmpty ?? false) {
            mediaItems.add({
              "url": p["link"],
              "thumbnail": p["thumbnail"] ?? "",
              "type": p["type"] ?? "image",
            });
          }
        }

        if (mediaItems.isEmpty) throw Exception("No media URLs found");

        progressTimer?.cancel();
        if (context.mounted) Navigator.of(context).pop();

        _linkController.clear();
        FocusManager.instance.primaryFocus?.unfocus();

        if (context.mounted) {
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
            _loadSavedPosts();
            _loadSeparatedMedia(isInitialLoad: false);
          });
        }
      } else {
        throw Exception("Server error (${response.statusCode})");
      }
    }on TimeoutException catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close the status dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⌛ The server took too long to respond. Please try again.")),
        );
      }
    } on SocketException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🌐 Connection Refused: ${e.message}")),
        );
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
    Navigator.of(context).push(
        createSlideRoute(const SettingsScreen(), direction: SlideFrom.right));
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

  // --- DATA LOADING ---

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final dynamic savedRaw = prefs.get('savedPosts');
    if (savedRaw is String) await prefs.remove('savedPosts');

    final savedData = prefs.getStringList('savedPosts') ?? [];
    try {
      final List<SavedPost> loadedPosts = savedData.map((json) {
        return SavedPost.fromJson(Map<String, dynamic>.from(jsonDecode(json)));
      }).toList();
      setState(() => _savedPosts = loadedPosts);
    } catch (e) {
      print("❌ Error parsing saved posts: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _getSeparatedMedia() async {
    List<Map<String, dynamic>> separated = [];
    for (final post in _savedPosts.reversed) {
      final path = post.localPath;
      if (!File(path).existsSync()) continue;

      if (path.toLowerCase().endsWith(".mp4")) {
        String? thumbPath;
        try {
          thumbPath = await VideoThumbnail.thumbnailFile(
            video: path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 200,
            quality: 75,
          );
        } catch (e) {
          print("Thumbnail error: $e");
        }
        separated.add(
            {"type": "video", "data": post, "thumbPath": thumbPath});
      } else {
        separated.add({"type": "image", "data": post});
      }
    }
    return separated;
  }

  Future<void> _loadSeparatedMedia({bool isInitialLoad = false}) async {
    if (isInitialLoad && _separatedMedia == null) {
      setState(() => _isLoadingMedia = true);
    }

    final newData = await _getSeparatedMedia();

    if (!mounted) return;

    setState(() {
      if (_separatedMedia == null || isInitialLoad) {
        // First time
        _separatedMedia = newData;
      } else {
        // 🔥 APPEND ONLY NEW ITEMS
        final existingPaths = _separatedMedia!
            .map((e) => (e['data'] as SavedPost).localPath)
            .toSet();

        final onlyNewItems = newData.where((e) {
          final post = e['data'] as SavedPost;
          return !existingPaths.contains(post.localPath);
        }).toList();

        _separatedMedia!.insertAll(0, onlyNewItems); // newest on top
      }

      _isLoadingMedia = false;
    });
  }

  Widget _buildFinalDownloadedItem(DownloadTask task) {
    ImageProvider? imageProvider;

    if (task.type == 'video') {
      if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty) {
        imageProvider = NetworkImage(task.thumbnailUrl!);
      }
    } else {
      if (task.localPath != null && File(task.localPath!).existsSync()) {
        imageProvider = FileImage(File(task.localPath!));
      } else if (task.thumbnailUrl != null && task.thumbnailUrl!.isNotEmpty) {
        imageProvider = NetworkImage(task.thumbnailUrl!);
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageProvider != null)
            Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[300]),
            )
          else
            Container(color: Colors.grey[300]),

          if (task.type == 'video')
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getSeparatedMediaFromList(List<SavedPost> posts) async {
    List<Map<String, dynamic>> separated = [];

    for (final post in posts.reversed) {
      final path = post.localPath;
      if (!File(path).existsSync()) continue;

      if (path.toLowerCase().endsWith(".mp4")) {
        // FIX: Check if we already have this thumbnail in current state to avoid re-generating
        String? existingThumb = _separatedMedia?.firstWhere(
              (m) => (m['data'] as SavedPost).localPath == path,
          orElse: () => {},
        )['thumbPath'];

        String? thumbPath = existingThumb;

        if (thumbPath == null) {
          try {
            thumbPath = await VideoThumbnail.thumbnailFile(
              video: path,
              imageFormat: ImageFormat.JPEG,
              maxHeight: 200,
              quality: 75,
            );
          } catch (e) { print("Thumbnail error: $e"); }
        }
        separated.add({"type": "video", "data": post, "thumbPath": thumbPath});
      } else {
        separated.add({"type": "image", "data": post});
      }
    }
    return separated;
  }


}