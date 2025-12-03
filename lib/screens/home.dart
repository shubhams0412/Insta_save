import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:insta_save/screens/preview_screen.dart';
import 'package:insta_save/screens/tutorial_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '_buildStepCard.dart';
import 'all_media_screen.dart';
import 'edit_post_screen.dart';
import 'repost_screen.dart';
import 'setting_screen.dart';
import '../utils/saved_post.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:insta_save/utils/navigation_helper.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _linkController = TextEditingController();

  List<SavedPost> _savedPosts = [];
  List<Map<String, dynamic>>? _separatedMedia;
  bool _isLoadingMedia = true;

  static const String _releaseBaseUrl = "http://13.200.64.163:9081/"; // Replace with actual release domain if different
  static const String _debugBaseUrl = "http://13.200.64.163:9081/";

  String get _apiBaseUrl => kReleaseMode ? _releaseBaseUrl : _debugBaseUrl;


  @override
  void initState() {
    super.initState();
    _linkController.addListener(() {
      setState(() {});
    });

    _initGalleryData();
  }

  Future<void> _initGalleryData() async {
    await _loadSavedPosts();
    await _loadSeparatedMedia();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
            // IconButton(
            //   icon: const Icon(Icons.do_not_disturb_on_outlined,
            //       size: 26, color: Colors.black87),
            //   onPressed: () {},
            // ),
            // const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.settings, size: 26, color: Colors.black87),
              onPressed: () {
                navigateToSettingScreen();
              },
            ),
            const SizedBox(width: 16),
          ],
        ),
        // ✅ CHANGED: Removed SingleChildScrollView. Using Column to separate fixed top and scrolling bottom.
        body: Column(
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
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Row(
                              children: [
                                Icon(Icons.link,
                                    size: 18, color: Colors.black87),
                                SizedBox(width: 6),
                                Text("Paste link",
                                    style:
                                    TextStyle(color: Colors.black87)),
                              ],
                            ),
                          ),
                        ),
                      )
                          : GestureDetector(
                        onTap: () {
                          navigateToPreviewScreen(
                              context, _linkController);
                        },
                        child: Container(
                          height: 48,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward,
                                    size: 18, color: Colors.black87),
                                SizedBox(width: 6),
                                Text("Go",
                                    style:
                                    TextStyle(color: Colors.black87)),
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
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 3),
                    )
                        : TabBarView(
                      children: [
                        // --- POSTS TAB ---
                        _buildLimitedGrid(
                          _separatedMedia!
                              .where((m) =>
                          m['type'] == 'image' &&
                              (m['data'] as SavedPost).postUrl !=
                                  "device_media")
                              .toList(),
                          "All Posts",
                        ),

                        // --- REELS TAB ---
                        _buildLimitedGrid(
                          _separatedMedia!
                              .where((m) =>
                          m['type'] == 'video' &&
                              (m['data'] as SavedPost).postUrl !=
                                  "device_media")
                              .toList(),
                          "All Reels",
                        ),

                        // --- DEVICE MEDIA TAB ---
                        _buildLimitedGrid(
                          _separatedMedia!
                              .where((m) =>
                          (m['data'] as SavedPost).postUrl ==
                              "device_media")
                              .toList(),
                          "All Device Media",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Builds a limited grid (Max 6 items) + View All Button
  Widget _buildLimitedGrid(
      List<Map<String, dynamic>> mediaList, String viewAllTitle) {
    if (mediaList.isEmpty) {
      return const Center(child: Text("No media found."));
    }

    // Determine how many items to show (max 6)
    int displayCount = mediaList.length > 6 ? 6 : mediaList.length;
    bool showViewAll = mediaList.length > 6;

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Disable grid scroll
          shrinkWrap: true, // Take only needed space
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, // ✅ 3 Items per row
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final postMap = mediaList[index];
            return _buildGridItem(postMap);
          },
        ),

        // ✅ View All Button (Displayed if > 6 items)
        if (showViewAll)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: TextButton(
              onPressed: () {
                // Navigate to new screen with ALL items
                Navigator.of(context).push(createSlideRoute(
                  AllMediaScreen(title: viewAllTitle, mediaList: mediaList),
                  direction: SlideFrom.right,
                ));
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
        // Add some bottom padding so it's not stuck to edge
        const SizedBox(height: 20),
      ],
    );
  }

  // Helper to build individual grid item
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
        );
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

  // ... (Rest of your existing methods like pickImageFromGallery, etc.) ...
  Future<void> pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      print("Image selected: ${image.path}");

      if (mounted) {
        // Dismiss keyboard if open
        FocusManager.instance.primaryFocus?.unfocus();

        // Navigate to the new Edit Screen
        // We use .then() to refresh the gallery grid when the user comes back
        Navigator.of(context).push(createSlideRoute(EditPostScreen(imagePath: image.path),direction: SlideFrom.bottom),
        ).then((_) {
          // ✅ Refresh data when user returns from Edit/Repost screen
          _loadSavedPosts();
          _loadSeparatedMedia();
        });
      }
    } else {
      print("No image selected.");
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

    // Check internet
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ No Internet Connection")),
      );
      return;
    }

    // 🌀 Show a blocking loader dialog
    showDialog(
      context: context,
      barrierDismissible: false, // ⛔ Prevent user interaction
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: Colors.black,
        ),
      ),
    );

    try {
      final String apiUrl = "${_apiBaseUrl}download_media";
      String deviceId = await _getDeviceId();

      final Map<String, String> params = {
        "instagramURL": link,
        "deviceId": deviceId,
      };

      final response = await http.post(Uri.parse(apiUrl), body: params).timeout(const Duration(seconds: 90));

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

        // ✅ Collect all post URLs
        final List<String> mediaUrls = postDataList
            .map<String>((p) => p["link"] ?? "")
            .where((url) => url.isNotEmpty)
            .toList();

        if (mediaUrls.isEmpty) throw Exception("No media URLs found");

        // ✅ Download all media sequentially
        List<String> localPaths = [];
        int index = 0;
        for (final url in mediaUrls) {
          final path = await _downloadAndSaveToGallery(url, index);
          if (path != null) localPaths.add(path);
          index++;
        }

        // ✅ Close the loader before navigation
        if (context.mounted) Navigator.of(context).pop();

        if (localPaths.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Failed to download media")),
          );
          return;
        }

        // ✅ Save post locally (first item)
        final postObj = SavedPost(
          localPath: localPaths.first,
          username: username,
          caption: caption,
          postUrl: link,
        );
        await _savePostToLocal(postObj);

        // ✅ Navigate to PreviewScreen
        if (context.mounted) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).push(
            createSlideRoute(
              PreviewScreen(
                mediaPaths: localPaths,
                username: username,
                caption: caption,
                postUrl: link,
              ),
              direction: SlideFrom.bottom,
            ),
          );

        }
      } else {
        throw Exception("Server error (${response.statusCode})");
      }
    } catch (e) {
      // ✅ Close loader if still open
      if (context.mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
    await _loadSavedPosts();
    await _loadSeparatedMedia();
  }

  Future<String?> _downloadAndSaveToGallery(String mediaUrl, int index) async {
    try {
      print("⬇️ Downloading media from: $mediaUrl");

      final response = await http.get(Uri.parse(mediaUrl));

      if (response.statusCode != 200) {
        print("❌ Download failed with code: ${response.statusCode}");
        throw Exception("Download failed");
      }

      final bytes = response.bodyBytes;
      String baseName = _sanitizeFileName(mediaUrl);

      final String uniqueFileName;
      if (baseName.contains('.')) {
        final parts = baseName.split('.');
        final ext = parts.last;
        final name = parts.sublist(0, parts.length - 1).join('.');
        uniqueFileName = "${name}_$index.$ext";
      } else {
        uniqueFileName = "${baseName}_$index.jpg";
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/$uniqueFileName";
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      print("✅ File written to temp: $filePath");

      final result = await SaverGallery.saveFile(
        filePath: filePath,
        fileName: uniqueFileName,
        skipIfExists: false,
        androidRelativePath: 'Pictures/InstaSave',
      );

      print(
        "🧾 Gallery result: success=${result.isSuccess}, error=${result.errorMessage}",
      );

      if (result.isSuccess) return file.path;
      return null;
    } catch (e) {
      print("❌ Error saving to gallery: $e");
      return null;
    }
  }

  void navigateToSettingScreen() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).push(createSlideRoute(const SettingsScreen(), direction: SlideFrom.right));
  }

  String _sanitizeFileName(String url) {
    final uri = Uri.parse(url);
    String? rawName = uri.queryParameters['filename'];
    rawName ??= uri.pathSegments.isNotEmpty
        ? uri.pathSegments.last
        : 'insta_media';
    rawName = rawName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
    if (!rawName.contains('.')) {
      rawName += '.jpg';
    }
    return rawName;
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

  Future<void> _savePostToLocal(SavedPost post) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('savedPosts') ?? [];

    bool isDuplicate = false;
    if (post.postUrl == "device_media") {
      isDuplicate = existing.any((item) {
        final decoded = jsonDecode(item);
        return decoded['localPath'] == post.localPath;
      });
    } else {
      isDuplicate = existing.any((item) {
        final decoded = jsonDecode(item);
        return decoded['postUrl'] == post.postUrl;
      });
    }

    if (isDuplicate) {
      print("⚠️ Duplicate post skipped: ${post.localPath}");
      return;
    }

    existing.add(jsonEncode(post.toJson()));
    await prefs.setStringList('savedPosts', existing);
    await _loadSavedPosts();
    await _loadSeparatedMedia();
  }

  Future<void> _loadSavedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final dynamic savedRaw = prefs.get('savedPosts');
    if (savedRaw is String) {
      print("🧹 Clearing old savedPosts format");
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

    for (final post in _savedPosts) {
      final path = post.localPath.toLowerCase();

      if (path.endsWith(".mp4")) {
        final thumbPath = await VideoThumbnail.thumbnailFile(
          video: post.localPath,
          imageFormat: ImageFormat.JPEG,
          maxHeight: 200,
          quality: 75,
        );

        separated.add({
          "type": "video",
          "data": post,
          "thumbPath": thumbPath,
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

  Future<void> _loadSeparatedMedia() async {
    setState(() => _isLoadingMedia = true);
    await Future.delayed(const Duration(milliseconds: 300));
    _separatedMedia = await _getSeparatedMedia();
    setState(() => _isLoadingMedia = false);
  }
}