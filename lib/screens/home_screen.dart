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
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_save/services/ad_service.dart'; // Import this
import 'package:insta_save/services/rating_service.dart';

import 'package:insta_save/screens/all_media_screen.dart';
import 'package:insta_save/screens/edit_post_screen.dart';
import 'package:insta_save/screens/preview_screen.dart';
import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/screens/setting_screen.dart';
import 'package:insta_save/services/download_manager.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/saved_post.dart';
import 'package:insta_save/services/remote_config_service.dart';
import 'package:insta_save/screens/sales_screen.dart';
import 'package:insta_save/utils/constants.dart';

import '../services/instagram_login_webview.dart';
import '../widgets/status_dialog.dart';
import '_buildStepCard.dart';

class HomeScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool silentLoad;

  const HomeScreen({
    super.key,
    this.initialTabIndex = 0,
    this.silentLoad = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _linkController = TextEditingController();
  late TabController _tabController;

  List<Map<String, dynamic>>? _separatedMedia;
  bool _isLoadingMedia = true;
  bool _isLoggedIn = false;

  static const String _apiBaseUrl = kReleaseMode
      ? "https://api.instasave.turbofast.io/" // TODO: Replace with actual release URL
      : "http://13.200.64.163:9081/";

  StreamSubscription? _downloadSubscription;

  static const platform = MethodChannel(
    'com.video.downloader.saver.manager.free.allvideodownloader/widget_actions',
  );

  @override
  void initState() {
    super.initState();
    _linkController.addListener(() {
      setState(() {});
    });

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );

    // Register Lifecycle Observer
    WidgetsBinding.instance.addObserver(this);

    // Check local clipboard for text
    _checkClipboardAndPaste();

    // Initial check for clipboard
    _checkClipboardAndPaste();

    // Initial Load: Show Spinner (true) only if NOT silentLoad
    if (widget.silentLoad) {
      _isLoadingMedia = false; // Start with content
      _refreshGalleryDataSilently();
    } else {
      _initGalleryData(); // Show spinner
    }

    // Download Finished: Silent Refresh (false)
    _downloadSubscription = DownloadManager.instance.onTaskCompleted.listen((
      _,
    ) async {
      debugPrint("Download Completed - Checking Rating Trigger");
      // 3. On success import of each media save "every 1st, 3rd, 5th, and so on"
      await RatingService().checkAndShowRating(
        RatingService().mediaSaveCountKey,
      );
      _refreshGalleryDataSilently();
    });

    // Check for Widget Actions
    _initWidgetListener();

    // Check Instagram login status
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: <String>{'isInstagramLoggedIn'},
      ),
    );
    if (mounted) {
      setState(() {
        _isLoggedIn = prefs.getBool('isInstagramLoggedIn') ?? false;
      });
    }
  }

  void _initWidgetListener() {
    // 1. Listen for active events (if app is running)
    platform.setMethodCallHandler((call) async {
      if (call.method == "onWidgetAction") {
        final action = call.arguments as String?;
        _handleWidgetAction(action);
      }
    });

    // 2. Check for initial action (if app was launched from widget)
    platform.invokeMethod('checkWidgetAction').then((value) {
      if (value != null && value is String) {
        _handleWidgetAction(value);
      }
    });
  }

  void _handleWidgetAction(String? action) {
    if (action == "ACTION_WIDGET_OPEN_INSTA") {
      // Open Instagram App
      _openInstagram();
    } else if (action == "ACTION_WIDGET_OPEN_GALLERY") {
      // Open Gallery
      Future.delayed(const Duration(milliseconds: 500), () {
        pickImageFromGallery();
      });
    }
  }

  Future<void> _openInstagram() async {
    const url = 'instagram://app'; // Try deep link first
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web link
        await launchUrl(
          Uri.parse("https://instagram.com/"),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Could not open Instagram: $e");
      // Last resort fallback
      await launchUrl(
        Uri.parse("https://instagram.com/"),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboardAndPaste();
    }
  }

  Future<void> _checkClipboardAndPaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData != null && clipboardData.text != null) {
        String text = clipboardData.text!.trim();
        // Basic Instagram link validation
        if (text.contains("instagram.com/")) {
          // Overwrite if the new link is different from the current one
          if (_linkController.text.trim() != text) {
            setState(() {
              _linkController.text = text;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Clipboard access error: $e");
    }
  }

  Future<void> _refreshGalleryDataSilently() async {
    // 1. Fetch raw data from Prefs
    // 1. Initialize with an allowList (more performant and ProGuard friendly)
    final SharedPreferencesWithCache prefs =
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: <String>{
              'savedPosts',
            }, // List all keys you intend to use
          ),
        );

    // 2. Fetch data directly from the cache (Synchronous after initialization)
    final List<String> savedData = prefs.getStringList('savedPosts') ?? [];

    final List<SavedPost> loadedPosts = savedData.map((json) {
      return SavedPost.fromJson(Map<String, dynamic>.from(jsonDecode(json)));
    }).toList();

    // 2. Load and Separate Media (Atomic Replace)
    // We pass the full list to reuse existing thumbnails where possible
    final newData = await _getSeparatedMediaFromList(loadedPosts);

    // 3. Update the UI
    if (mounted) {
      setState(() {
        _separatedMedia = newData;
        _isLoadingMedia = false;
      });
    }
  }

  Future<void> _initGalleryData() async {
    _refreshGalleryDataSilently();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _downloadSubscription?.cancel();
    _linkController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Structure: Clean Scaffolding
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),

      // 2. Logic: Removed global AnimatedBuilder.
      // Only the bottom section listens to downloads now.
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- STATIC TOP SECTION (Won't rebuild on download) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildActionButtons(),
                      const SizedBox(height: 10),
                      _buildTutorialCard(),
                      const SizedBox(height: 20),
                      _buildLinkInput(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                // --- DYNAMIC BOTTOM SECTION (Rebuilds on download/tab change) ---
                Expanded(child: _buildMediaTabsSection()),

                // Space for PRO card
                const SizedBox(height: 90),
              ],
            ),

            // --- UPGRADE TO PRO CARD (Fixed at bottom) ---
            Positioned(bottom: 16, left: 16, right: 16, child: _buildProCard()),
          ],
        ),
      ),
      bottomNavigationBar: null,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        Constants.AppName,
        style: TextStyle(
          fontFamily: "Lobster",
          fontSize: 36,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        IconButton(
          icon: Image.asset(
            'assets/images/ads.png',
            width: 24,
            height: 24,
          ), // Placeholder for "No Ads"
          onPressed: navigateToSalesPage,
        ),
        IconButton(
          icon: Image.asset(
            'assets/images/Settings.png',
            width: 24,
            height: 24,
          ),
          onPressed: navigateToSettingScreen,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // --- WIDGET: Tutorial Card ---
  Widget _buildTutorialCard() {
    return Column(
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).push(
              createSlideRoute(
                const TutorialScreen(
                  title: "How to Use Select Pics & Repost?",
                  steps: TutorialScreen.selectPicsSteps,
                ),
                direction: SlideFrom.right,
              ),
            );
          },
          child: Row(
            children: [
              const Icon(Icons.info_outlined, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              const Text(
                "How to Use Select Pics & Repost?",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- WIDGET: Action Buttons (Gradient) ---
  Widget _buildActionButtons() {
    return GestureDetector(
      onTap: pickImageFromGallery,
      child: Container(
        height: 85,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/pic_repost_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51), // 0.2 opacity
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/pics_repost.png',
                    width: 30,
                    height: 30,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              // Text section
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Select Pics & Repost",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Tap to choose images",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET: Link Input ---
  Widget _buildLinkInput() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _linkController,
              autofocus: false,
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Paste a link here",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _linkController,
              builder: (context, value, child) {
                final hasText = value.text.isNotEmpty;
                if (hasText) {
                  return GestureDetector(
                    onTap: () =>
                        navigateToPreviewScreen(context, _linkController),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Go",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onTap: pasteInstagramLink,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C6C6C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/pastelink.png',
                          width: 18,
                          height: 18,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Paste link",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Media Tabs (The part that listens to downloads) ---
  Widget _buildMediaTabsSection() {
    return AnimatedBuilder(
      animation: DownloadManager.instance,
      builder: (context, _) {
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
                "My Saved Collection",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.black,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
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
                      controller: _tabController,
                      children: [
                        // POSTS
                        _buildLimitedGrid(
                          activeTasks: activeImages,
                          mediaList: media
                              .where(
                                (m) =>
                                    m['type'] == 'image' &&
                                    (m['data'] as SavedPost).postUrl !=
                                        "device_media",
                              )
                              .toList(),
                          viewAllTitle: "All Posts",
                        ),

                        // REELS
                        _buildLimitedGrid(
                          activeTasks: activeVideos,
                          mediaList: media
                              .where(
                                (m) =>
                                    m['type'] == 'video' &&
                                    (m['data'] as SavedPost).postUrl !=
                                        "device_media",
                              )
                              .toList(),
                          viewAllTitle: "All Reels",
                        ),

                        // DEVICE MEDIA
                        _buildLimitedGrid(
                          activeTasks: const [],
                          mediaList: media
                              .where(
                                (m) =>
                                    (m['data'] as SavedPost).postUrl ==
                                    "device_media",
                              )
                              .toList(),
                          viewAllTitle: "All Device Media",
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/placeholder.png', width: 50, height: 50),
            const SizedBox(height: 14),
            const Text(
              "You haven't shared\nany posts yet.",
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
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    createSlideRoute(
                      AllMediaScreen(
                        title: viewAllTitle,
                        mediaList: filteredMediaList,
                      ),
                      direction: SlideFrom.right,
                    ),
                  );
                  _refreshGalleryDataSilently();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "View All",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
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
                  thumbnailUrl: thumbPath ?? "",
                ),
                direction: SlideFrom.bottom,
              ),
            )
            .then((result) {
              if (result is Map && result['home'] == true) {
                if (mounted && result.containsKey('tab')) {
                  _tabController.animateTo(result['tab'] as int);
                }
              }
              // Reload silently regardless of deletion for consistency
              _refreshGalleryDataSilently();
            });
      },
      child: isVideoItem
          ? _buildReelGridItem(post, thumbPath)
          : _buildImageGridItem(post),
    );
  }

  Widget _buildImageGridItem(SavedPost post) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(post.localPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.error, color: Colors.grey),
          ),
          _buildUsernameOverlay(post.username),
        ],
      ),
    );
  }

  Widget _buildReelGridItem(SavedPost post, String? thumbPath) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          thumbPath != null
              ? Image.file(
                  File(thumbPath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : Container(
                  color: Colors.grey[300],
                  width: double.infinity,
                  height: double.infinity,
                ),
          _buildUsernameOverlay(post.username),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameOverlay(String username) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        child: Text(
          "@${username.replaceAll('@', '')}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildProCard() {
    final homeConfig = RemoteConfigService().homeConfig;

    return GestureDetector(
      onTap: navigateToSalesPage,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9500), Color(0xFFFF4B2B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/crown.png',
                    width: 32,
                    height: 32,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homeConfig?.proCardTitle ?? "Upgrade to PRO",
                      style: TextStyle(
                        color: homeConfig?.proCardTitleColor ?? Colors.white,
                        fontSize: homeConfig?.proCardTitleSize ?? 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      homeConfig?.proCardSubtitle ??
                          "Unlock unlimited downloads",
                      style: TextStyle(
                        color: homeConfig?.proCardSubtitleColor ?? Colors.white,
                        fontSize: homeConfig?.proCardSubtitleSize ?? 16,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACTIONS ---

  Future<void> pickImageFromGallery() async {
    // Wrap with Ad Logic: "Select Pics & Repost" (Odd occurrences)
    AdService().handleSelectPicsAd(() async {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null && mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(
          context,
          createSlideRoute(
            EditPostScreen(imagePath: image.path),
            direction: SlideFrom.bottom,
          ),
        ).then((result) {
          if (result is Map && result['home'] == true) {
            if (mounted && result.containsKey('tab')) {
              _tabController.animateTo(result['tab'] as int);
            }
          }
          _refreshGalleryDataSilently();
        });
      }
    });
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

  Future<void> navigateToPreviewScreen(
    BuildContext context,
    TextEditingController linkController,
  ) async {
    // "Show an ad each time when the user clicks Paste Link and proceeds with Go"
    AdService().handlePasteLinkAd(() {
      _processLinkNavigation(linkController);
    });
  }

  Future<void> _processLinkNavigation(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("❌ No Internet Connection")));
      return;
    }

    // Check Firebase Remote Config flag for login flow
    final remoteConfig = RemoteConfigService();
    final bool isLoginFlowEnabled = remoteConfig.isInstaLoginFlowEnabled;

    if (isLoginFlowEnabled) {
      // Original behavior: Check login status and show login if needed
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'isInstagramLoggedIn'},
        ),
      );
      bool isLoggedIn = prefs.getBool('isInstagramLoggedIn') ?? false;

      if (!isLoggedIn) {
        // User is not logged in, open the Login Webview
        bool success = await openInstaLogin(context);
        if (!success) {
          // User cancelled login or failed, so we stop here.
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⚠️ Login required to download content"),
              ),
            );
          }
          return;
        }
        // Refresh login status after successful login
        _checkLoginStatus();
        // If success == true, proceed to download!
      }
    }
    // If login flow is disabled, skip login check and proceed directly to API call

    double fakeProgress = 0.0;
    Timer? progressTimer;
    bool dialogMounted = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            progressTimer ??= Timer.periodic(
              const Duration(milliseconds: 100),
              (timer) {
                if (!dialogMounted) {
                  timer.cancel();
                  return;
                }
                if (fakeProgress < 0.95) {
                  setDialogState(() => fakeProgress += 0.01);
                } else {
                  timer.cancel();
                }
              },
            );
            return StatusDialog(
              type: DialogType.fetching,
              progress: fakeProgress,
            );
          },
        );
      },
    ).then((_) {
      dialogMounted = false;
      progressTimer?.cancel();
    });

    try {
      final String apiUrl = "${_apiBaseUrl}download_media";
      String deviceId = await _getDeviceId();

      final response = await http
          .post(
            Uri.parse(apiUrl),
            body: {"instagramURL": link, "deviceId": deviceId},
          )
          .timeout(const Duration(seconds: 120));

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
          Navigator.of(context)
              .push(
                createSlideRoute(
                  PreviewScreen(
                    mediaItems: mediaItems,
                    username: username,
                    caption: caption,
                    postUrl: link,
                  ),
                  direction: SlideFrom.bottom,
                ),
              )
              .then((result) {
                FocusManager.instance.primaryFocus?.unfocus();
                if (result is Map && result['home'] == true) {
                  if (mounted && result.containsKey('tab')) {
                    _tabController.animateTo(result['tab'] as int);
                  }
                }
                _refreshGalleryDataSilently();
              });
        }
      } else {
        throw Exception("Server error (${response.statusCode})");
      }
    } on TimeoutException catch (_) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close the status dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "⌛ The server took too long to respond. Please try again.",
            ),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Error: $e")));
    }
  }

  void navigateToSettingScreen() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(
      createSlideRoute(const SettingsScreen(), direction: SlideFrom.right),
    );
  }

  void navigateToSalesPage() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).push(createSlideRoute(const SalesScreen(), direction: SlideFrom.bottom));
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
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
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

  Future<List<Map<String, dynamic>>> _getSeparatedMediaFromList(
    List<SavedPost> posts,
  ) async {
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
          } catch (e) {
            print("Thumbnail error: $e");
          }
        }
        separated.add({"type": "video", "data": post, "thumbPath": thumbPath});
      } else {
        separated.add({"type": "image", "data": post});
      }
    }
    return separated;
  }
}
