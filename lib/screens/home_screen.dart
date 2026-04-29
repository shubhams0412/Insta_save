import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_save/services/ad_service.dart';
import 'package:insta_save/services/rating_service.dart';
import 'package:insta_save/services/notification_service.dart';
import 'package:insta_save/services/iap_service.dart';
import 'package:photo_manager/photo_manager.dart';

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
import 'package:insta_save/utils/ui_utils.dart';
import 'package:image_picker/image_picker.dart';

import '../services/instagram_login_webview.dart';
import '../widgets/status_dialog.dart';
import 'tutorial_screen.dart';

enum _CreatorStudioAction {
  transcribeTranslate,
  hookTiming,
  trendyCaptions,
  trendyHashtags,
  downloadAssets,
}

class _CreatorStudioOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final _CreatorStudioAction action;

  const _CreatorStudioOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.action,
  });
}

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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _linkController = TextEditingController();
  late TabController _tabController;
  static const List<_CreatorStudioOption> _creatorStudioOptions = [
    _CreatorStudioOption(
      title: "Transcribe & Translate",
      subtitle: "Convert reel audio into text & translated captions",
      icon: Icons.translate_rounded,
      action: _CreatorStudioAction.transcribeTranslate,
    ),
    _CreatorStudioOption(
      title: "Hook Generator",
      subtitle: "Create scroll-stopping openers for your reels",
      icon: Icons.whatshot_rounded,
      action: _CreatorStudioAction.hookTiming,
    ),
    _CreatorStudioOption(
      title: "Trendy Captions",
      subtitle: "Write engaging captions using current trends",
      icon: Icons.edit_note_rounded,
      action: _CreatorStudioAction.trendyCaptions,
    ),
    _CreatorStudioOption(
      title: "Trendy Hashtags",
      subtitle: "Find trending hashtags to maximize your reach",
      icon: Icons.tag_rounded,
      action: _CreatorStudioAction.trendyHashtags,
    ),
    _CreatorStudioOption(
      title: "Download Images & PDF",
      subtitle: "Save posts and carousels as images or PDF",
      icon: Icons.picture_as_pdf_outlined,
      action: _CreatorStudioAction.downloadAssets,
    ),
  ];

  List<Map<String, dynamic>>? _separatedMedia;
  bool _isLoadingMedia = true;
  bool _isOpeningGallery = false;

  static const String _apiBaseUrl = kReleaseMode
      ? "https://api.instasave.turbofast.io/"
      : "http://13.200.64.163:9081/";

  StreamSubscription? _downloadSubscription;

  static const platform = MethodChannel(
    'com.video.downloader.saver.manager.free.allvideodownloader/widget_actions',
  );

  late AnimationController _creatorStudioController;

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

    _creatorStudioController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
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
      debugPrint("Download Completed - Refreshing Gallery");
      _refreshGalleryDataSilently();
    });

    // Check for Widget Actions
    _initWidgetListener();

    // Request notification permission when user reaches home for the first time
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    bool alreadyAsked = prefs.getBool('isNotificationPermissionAsked') ?? false;

    if (!alreadyAsked) {
      await NotificationService().requestPermissions();
      await prefs.setBool('isNotificationPermissionAsked', true);
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();

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
    _creatorStudioController.dispose();
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
                ValueListenableBuilder<bool>(
                  valueListenable: IAPService().isPremium,
                  builder: (context, isPremium, child) {
                    // Hide spacing if user is premium
                    if (isPremium) {
                      return const SizedBox.shrink();
                    }
                    return const SizedBox(height: 90);
                  },
                ),
              ],
            ),

            // --- UPGRADE TO PRO CARD (Fixed at bottom) ---
            Positioned(bottom: 16, left: 16, right: 16, child: _buildProCard()),

            _buildCreatorStudioButton(),
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
        Constants.appName,
        style: TextStyle(
          fontFamily: "Lobster",
          fontSize: 36,
          color: Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        ValueListenableBuilder<bool>(
          valueListenable: IAPService().isPremium,
          builder: (context, isPremium, child) {
            // Hide the ads icon if user is premium
            if (isPremium) {
              return const SizedBox.shrink();
            }

            return IconButton(
              icon: Image.asset(
                'assets/images/ads.png',
                width: 24,
                height: 24,
              ), // Placeholder for "No Ads"
              onPressed: navigateToSalesPage,
            );
          },
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
                const TutorialScreen(title: "How to Use Select Pics & Repost?"),
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
                  fontSize: 14,
                  color: Colors.black54,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
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
              // Arrow
              _isOpeningGallery
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
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
                Tab(text: "Videos"),
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
                          emptyMessage: "You haven't shared\nany posts yet.",
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
                          emptyMessage: "You haven't shared\nany videos yet.",
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
                          emptyMessage:
                              "You haven't shared\nany device media yet.",
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
    required String emptyMessage,
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
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
                  allMediaPaths: [post.localPath],
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

                if (result['rating'] == true) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      // Show custom rating on 1st, 5th, 9th... for Select Pics & Repost flow
                      RatingService().showCustomRating(
                        RatingService().selectPicsSaveCountKey,
                      );
                    }
                  });
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
            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
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

    return ValueListenableBuilder<bool>(
      valueListenable: IAPService().isPremium,
      builder: (context, isPremium, child) {
        // Hide the pro card if user is premium
        if (isPremium) {
          return const SizedBox.shrink();
        }

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
                            color:
                                homeConfig?.proCardTitleColor ?? Colors.white,
                            fontSize: homeConfig?.proCardTitleSize ?? 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          homeConfig?.proCardSubtitle ??
                              "Unlock unlimited downloads",
                          style: TextStyle(
                            color:
                                homeConfig?.proCardSubtitleColor ??
                                Colors.white,
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
      },
    );
  }

  Color _creatorStudioAccentColor(_CreatorStudioAction action) {
    switch (action) {
      case _CreatorStudioAction.transcribeTranslate:
        return const Color(0xFF00BCD4);
      case _CreatorStudioAction.hookTiming:
        return const Color(0xFFFF9800);
      case _CreatorStudioAction.trendyCaptions:
        return const Color(0xFF4CAF50);
      case _CreatorStudioAction.trendyHashtags:
        return const Color(0xFF2196F3);
      case _CreatorStudioAction.downloadAssets:
        return const Color(0xFF9C27B0);
    }
  }

  void _showCreatorStudioSheet() {
    FocusManager.instance.primaryFocus?.unfocus();
    _creatorStudioController.forward();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CreatorStudioStaggeredSheet(
        options: _creatorStudioOptions,
        onOptionTap: (option) {
          Navigator.pop(context);

          if (!IAPService().isPremiumPlus.value) {
            Navigator.of(context).push(
              createSlideRoute(
                const SalesScreen(showCreatorReel: true),
                direction: SlideFrom.bottom,
              ),
            );
            return;
          }

          if (option.action == _CreatorStudioAction.trendyCaptions ||
              option.action == _CreatorStudioAction.trendyHashtags) {
            _showCreatorStudioOptionsSubSheet(option);
          } else {
            _openCreatorStudioLinkDialog(option);
          }
        },
        accentColor: _creatorStudioAccentColor,
      ),
    ).whenComplete(() => _creatorStudioController.reverse());
  }

  void _showCreatorStudioOptionsSubSheet(_CreatorStudioOption option) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              option.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Choose how you want to provide data",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _SubOptionTile(
              title: "Paste Link",
              subtitle: "Use an Instagram reel link",
              icon: Icons.link_rounded,
              onTap: () {
                Navigator.pop(context);
                _openCreatorStudioLinkDialog(option);
              },
            ),
            const SizedBox(height: 12),
            _SubOptionTile(
              title: "Generate Captions",
              subtitle: "Enter text directly to process",
              icon: Icons.article_outlined,
              onTap: () {
                Navigator.pop(context);
                _openCreatorStudioLinkDialog(option, isParagraph: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorStudioButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: IAPService().isPremium,
      builder: (context, isPremium, _) => Positioned(
        right: 16,
        bottom: isPremium ? 16 : 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: _showCreatorStudioSheet,
              child: Container(
                height: 58,
                padding: const EdgeInsets.only(left: 14, right: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFF3A3A3A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RotationTransition(
                      turns: Tween<double>(begin: 0, end: 0.125).animate(
                        CurvedAnimation(
                          parent: _creatorStudioController,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Creator Studio",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  "NEW",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS ---
  Future<void> _openCreatorStudioLinkDialog(
    _CreatorStudioOption option, {
    bool isParagraph = false,
  }) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return _CreatorStudioDialog(
          option: option,
          initialText: isParagraph ? "" : _linkController.text,
          isParagraph: isParagraph,
        );
      },
    );

    if (result != null && mounted) {
      _handleCreatorStudioLink(option, result, isParagraph: isParagraph);
    }
  }

  void _handleCreatorStudioLink(
    _CreatorStudioOption option,
    String link, {
    bool isParagraph = false,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (isParagraph &&
        (option.action == _CreatorStudioAction.trendyCaptions ||
            option.action == _CreatorStudioAction.trendyHashtags)) {
      _showGroqGenerationSheet(option, link);
      return;
    }
    _linkController.text = link;
    navigateToPreviewScreen(context, _linkController);
  }

  Future<void> _showGroqGenerationSheet(
    _CreatorStudioOption option,
    String text,
  ) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _GroqResultSheet(
        option: option,
        inputText: text,
        apiBaseUrl: _apiBaseUrl,
      ),
    );
  }

  Future<void> pickImageFromGallery() async {
    if (_isOpeningGallery) return;
    setState(() => _isOpeningGallery = true);

    try {
      await AdService().handleSelectPicsAd(() async {
        try {
          PermissionState permission =
              await PhotoManager.requestPermissionExtend();

          if (permission != PermissionState.authorized &&
              permission != PermissionState.limited) {
            debugPrint("Permission not granted: $permission");
            return;
          }

          List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
            type: RequestType.common,
            filterOption: FilterOptionGroup(
              orders: [
                const OrderOption(type: OrderOptionType.createDate, asc: false),
              ],
            ),
          );

          if (albums.isEmpty && permission == PermissionState.limited) {
            albums = await PhotoManager.getAssetPathList(
              type: RequestType.common,
            );
          }

          if (albums.isEmpty) {
            if (permission == PermissionState.limited) {
              await PhotoManager.presentLimited();
              albums = await PhotoManager.getAssetPathList(
                type: RequestType.common,
              );
              if (albums.isEmpty) return;
            } else {
              if (mounted) {
                UIUtils.showSnackBar(
                  context,
                  "No media found in your gallery.",
                );
              }
              return;
            }
          }

          AssetPathEntity selectedAlbum = albums.first;

          List<AssetEntity> assets = await selectedAlbum.getAssetListRange(
            start: 0,
            end: 1000000,
          );

          if (!mounted) return;

          if (mounted) {
            setState(() {
              _isOpeningGallery = false;
            });
          }

          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) {
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.65,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<AssetPathEntity>(
                                    value: selectedAlbum,
                                    icon: const Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.black,
                                    ),
                                    dropdownColor: Colors.white,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: albums.map((e) {
                                      return DropdownMenuItem(
                                        value: e,
                                        child: Text(e.name),
                                      );
                                    }).toList(),
                                    onChanged: (val) async {
                                      if (val == null) return;
                                      selectedAlbum = val;
                                      assets = await selectedAlbum
                                          .getAssetListRange(
                                            start: 0,
                                            end: 1000000,
                                          );
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                              if (permission != PermissionState.authorized) ...[
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.blue.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  onPressed: () async {
                                    await PhotoManager.presentLimited();

                                    permission =
                                        await PhotoManager.requestPermissionExtend();

                                    final reFetched =
                                        await PhotoManager.getAssetPathList(
                                          type: RequestType.common,
                                          filterOption: FilterOptionGroup(
                                            orders: [
                                              const OrderOption(
                                                type:
                                                    OrderOptionType.createDate,
                                                asc: false,
                                              ),
                                            ],
                                          ),
                                        );

                                    if (reFetched.isNotEmpty) {
                                      albums.clear();
                                      albums.addAll(reFetched);
                                      selectedAlbum = albums.first;
                                      assets = await selectedAlbum
                                          .getAssetListRange(
                                            start: 0,
                                            end: 1000000,
                                          );
                                      setState(() {});
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text("Add More"),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(2),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 2,
                                  mainAxisSpacing: 2,
                                ),
                            itemCount: assets.length + 1,
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return GestureDetector(
                                  onTap: () async {
                                    final XFile? file = await ImagePicker()
                                        .pickImage(source: ImageSource.camera);

                                    if (file != null && context.mounted) {
                                      Navigator.pop(context);
                                      _openEditor(file.path);
                                    }
                                  },
                                  child: Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.black54,
                                      size: 30,
                                    ),
                                  ),
                                );
                              }

                              final asset = assets[i - 1];

                              return FutureBuilder<Uint8List?>(
                                future: asset.thumbnailDataWithSize(
                                  const ThumbnailSize(300, 300),
                                ),
                                builder: (_, snap) {
                                  if (!snap.hasData) {
                                    return Container(color: Colors.grey[100]);
                                  }

                                  return GestureDetector(
                                    onTap: () async {
                                      final file = await asset.file;
                                      if (file == null) return;
                                      if (!context.mounted) return;

                                      Navigator.pop(context);
                                      _openEditor(file.path);
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.memory(
                                          snap.data!,
                                          fit: BoxFit.cover,
                                        ),

                                        if (asset.type == AssetType.video)
                                          Align(
                                            alignment: Alignment.bottomRight,
                                            child: Container(
                                              margin: const EdgeInsets.all(4),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.7,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _formatDuration(
                                                  asset.videoDuration,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        } catch (e) {
          debugPrint("❌ Error in pickImageFromGallery: $e");
          if (mounted) {
            UIUtils.showSnackBar(
              context,
              "An error occurred while opening the gallery.",
            );
          }
        } finally {
          if (mounted) setState(() => _isOpeningGallery = false);
        }
      });
    } catch (e) {
      debugPrint("Error initializing gallery flow: $e");
      if (mounted) setState(() => _isOpeningGallery = false);
    }
  }

  void _openEditor(String path) {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditPostScreen(imagePath: path)),
    ).then((result) {
      _refreshGalleryDataSilently();

      if (result is Map && result['home'] == true) {
        if (mounted && result.containsKey('tab')) {
          _tabController.animateTo(result['tab'] as int);
        }

        if (result['rating'] == true) {
          RatingService().showCustomRating(
            RatingService().selectPicsSaveCountKey,
          );
        }
      }
    });
  }

  void pasteInstagramLink() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (data != null && data.text != null && data.text!.isNotEmpty) {
      if (data.text!.contains("instagram.com/")) {
        _linkController.text = data.text!;
      } else {
        UIUtils.showSnackBar(context, "⚠️ Please copy a valid Instagram link");
      }
    } else {
      UIUtils.showSnackBar(
        context,
        "There’s nothing to paste. Please copy a valid link and try again.",
      );
    }
  }

  Future<void> navigateToPreviewScreen(
    BuildContext context,
    TextEditingController linkController,
  ) async {
    AdService().handlePasteLinkAd(() {
      if (!mounted) return;
      _processLinkNavigation(linkController);
    });
  }

  Future<void> _processLinkNavigation(
    TextEditingController linkController,
  ) async {
    String link = linkController.text.trim();

    if (!link.contains("instagram.com/")) {
      if (mounted) {
        UIUtils.showSnackBar(context, "⚠️ Please enter a valid Instagram link");
      }
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        UIUtils.showSnackBar(context, "❌ No Internet Connection");
      }
      return;
    }

    final remoteConfig = RemoteConfigService();
    final bool isLoginFlowEnabled = remoteConfig.isInstaLoginFlowEnabled;

    if (isLoginFlowEnabled) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      bool isLoggedIn = prefs.getBool('isInstagramLoggedIn') ?? false;

      if (!isLoggedIn) {
        bool success = await openInstaLogin(context);
        if (!success) {
          if (mounted) {
            UIUtils.showSnackBar(
              context,
              "⚠️ Login required to download content",
            );
          }
          return;
        }
      }
    }

    if (!mounted) return;

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
            return PopScope(
              canPop: false,
              child: StatusDialog(
                type: DialogType.fetching,
                progress: fakeProgress,
              ),
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

      if (!mounted) return;

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

        if (mounted) {
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

                  if (result['rating'] == true) {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) {
                        RatingService().showNativeRating(
                          RatingService().repostGoHomeCountKey,
                        );
                      }
                    });
                  }
                }
                _refreshGalleryDataSilently();
              });
        }
      } else {
        throw Exception("Server error (${response.statusCode})");
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      UIUtils.showSnackBar(
        context,
        "⌛ The server took too long to respond. Please try again.",
      );
    } on SocketException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      UIUtils.showSnackBar(context, "🌐 Connection Refused: ${e.message}");
    } catch (e) {
      progressTimer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop();
      UIUtils.showSnackBar(context, "❌ Error: $e");
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
      debugPrint("Failed to get device ID: $e");
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
            debugPrint("Thumbnail error: $e");
          }
        }
        separated.add({"type": "video", "data": post, "thumbPath": thumbPath});
      } else {
        separated.add({"type": "image", "data": post});
      }
    }
    return separated;
  }

  String _formatDuration(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}

// ── Specialized Widget for the Creator Studio Dialog to manage its own lifecycle ──
class _CreatorStudioDialog extends StatefulWidget {
  final _CreatorStudioOption option;
  final String initialText;
  final bool isParagraph;

  const _CreatorStudioDialog({
    required this.option,
    required this.initialText,
    this.isParagraph = false,
  });

  @override
  State<_CreatorStudioDialog> createState() => _CreatorStudioDialogState();
}

class _CreatorStudioDialogState extends State<_CreatorStudioDialog> {
  late TextEditingController _dialogController;

  @override
  void initState() {
    super.initState();
    _dialogController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _dialogController.dispose();
    super.dispose();
  }

  void _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? "";
    if (text.contains("instagram.com/")) {
      setState(() {
        _dialogController.text = text;
      });
    } else {
      UIUtils.showSnackBar(context, "⚠️ Please copy a valid Instagram link");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Text(
        widget.option.title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _dialogController,
              autofocus: true,
              maxLines: widget.isParagraph ? 3 : 1,
              minLines: 1,
              keyboardType: widget.isParagraph
                  ? TextInputType.multiline
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: widget.isParagraph
                    ? "Enter your text here"
                    : "Paste a link here",
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: widget.isParagraph
                    ? null
                    : GestureDetector(
                        onTap: _pasteLink,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C6C6C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/pastelink.png',
                                width: 16,
                                height: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Paste link",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            if (widget.option.action ==
                _CreatorStudioAction.downloadAssets) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.red.shade800,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Only image posts can be downloaded as PDF.",
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final link = _dialogController.text.trim();
            if (!widget.isParagraph && !link.contains("instagram.com/")) {
              UIUtils.showSnackBar(
                context,
                "⚠️ Please enter a valid Instagram link",
              );
              return;
            }
            if (widget.isParagraph && link.isEmpty) {
              UIUtils.showSnackBar(context, "⚠️ Please enter some text");
              return;
            }
            Navigator.of(context).pop(link);
          },
          child: const Text("Continue"),
        ),
      ],
    );
  }
}

class _SubOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SubOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black87, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorStudioStaggeredSheet extends StatefulWidget {
  final List<_CreatorStudioOption> options;
  final Function(_CreatorStudioOption) onOptionTap;
  final Color Function(_CreatorStudioAction) accentColor;

  const _CreatorStudioStaggeredSheet({
    required this.options,
    required this.onOptionTap,
    required this.accentColor,
  });

  @override
  State<_CreatorStudioStaggeredSheet> createState() =>
      _CreatorStudioStaggeredSheetState();
}

class _CreatorStudioStaggeredSheetState
    extends State<_CreatorStudioStaggeredSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  "Creator Studio",
                  style: TextStyle(
                    fontSize: 22,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "NEW",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "AI-powered tools for your reels",
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
            const SizedBox(height: 24),
            ...List.generate(widget.options.length, (index) {
              final option = widget.options[index];
              final color = widget.accentColor(option.action);

              final animation = CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  (index / widget.options.length) * 0.5,
                  ((index + 1) / widget.options.length) * 0.5 + 0.5,
                  curve: Curves.easeOutBack,
                ),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Opacity(
                    opacity: animation.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        (1 - animation.value.clamp(0.0, 1.0)) * 20,
                      ),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _StudioOptionRowTile(
                    option: option,
                    color: color,
                    onTap: () => widget.onOptionTap(option),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StudioOptionRowTile extends StatelessWidget {
  final _CreatorStudioOption option;
  final Color color;
  final VoidCallback onTap;

  const _StudioOptionRowTile({
    required this.option,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(option.icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroqResultSheet extends StatefulWidget {
  final _CreatorStudioOption option;
  final String inputText;
  final String apiBaseUrl;

  const _GroqResultSheet({
    required this.option,
    required this.inputText,
    required this.apiBaseUrl,
  });

  @override
  State<_GroqResultSheet> createState() => _GroqResultSheetState();
}

class _GroqResultSheetState extends State<_GroqResultSheet> {
  bool _isLoading = true;
  dynamic _generatedResult; // Can be String or List<String>
  String? _error;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _generateContent();
  }

  Future<void> _generateContent() async {
    try {
      final endpoint =
          widget.option.action == _CreatorStudioAction.trendyCaptions
          ? "groq_caption"
          : "groq_hashtags";

      final response = await http.post(
        Uri.parse("${widget.apiBaseUrl}$endpoint"),
        body: {'text': widget.inputText},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 200) {
          setState(() {
            _generatedResult =
                widget.option.action == _CreatorStudioAction.trendyCaptions
                ? List<String>.from(data['data']['captions'])
                : List<String>.from(data['data']['hashtags']);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = "Error: ${data['code']}";
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = "Server error: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to generate: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isListData = _generatedResult is List;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Promt",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Text(
                      widget.inputText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.option.action == _CreatorStudioAction.trendyCaptions
                        ? "Generated Captions"
                        : "Generated Hashtags",
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "AI is crafting your ${widget.option.action == _CreatorStudioAction.trendyCaptions ? 'variants' : 'hashtags'}...",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_error != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isListData)
                    ...() {
                      final list = _generatedResult as List;
                      final visibleItems = _showAll
                          ? list
                          : list.take(4).toList();
                      return [
                        ...visibleItems.asMap().entries.map((entry) {
                          final variant = entry.value.toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      20,
                                      48,
                                      16,
                                    ),
                                    child: SelectableText(
                                      variant,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: IconButton(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: variant),
                                        );
                                        UIUtils.showSnackBar(
                                          context,
                                          "Copied successfully!",
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 18,
                                        color: Colors.black45,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        if (!_showAll && list.length > 4)
                          GestureDetector(
                            onTap: () => setState(() => _showAll = true),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Show more",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.black54,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ];
                    }()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withValues(alpha: 0.05),
                            Colors.blue.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: SelectableText(
                        _generatedResult?.toString() ?? "",
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // if (!_isLoading && _generatedResult != null)
                  //   SizedBox(
                  //     width: double.infinity,
                  //     height: 54,
                  //     child: ElevatedButton.icon(
                  //       onPressed: () {
                  //         final textToCopy = _generatedResult is List
                  //             ? (_generatedResult as List).join("\n\n")
                  //             : _generatedResult.toString();
                  //         Clipboard.setData(ClipboardData(text: textToCopy));
                  //         UIUtils.showSnackBar(context, "All content copied!");
                  //       },
                  //       icon: const Icon(Icons.copy_all_rounded),
                  //       label: const Text(
                  //         "Copy All Hashtags",
                  //         style: TextStyle(
                  //           fontSize: 16,
                  //           fontWeight: FontWeight.w700,
                  //         ),
                  //       ),
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: Colors.black,
                  //         foregroundColor: Colors.white,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(16),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
