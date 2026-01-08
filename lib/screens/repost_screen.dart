import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_save/services/ad_service.dart'; // Import this
import 'package:insta_save/services/rating_service.dart';
import 'package:insta_save/services/notification_service.dart';
import 'package:insta_save/utils/constants.dart';

class RepostScreen extends StatefulWidget {
  final String imageUrl;
  final String username;
  final String initialCaption;
  final String postUrl;
  final String localImagePath;
  final bool showDeleteButton;
  final bool showHomeButton;
  final String thumbnailUrl;

  const RepostScreen({
    super.key,
    required this.imageUrl,
    required this.username,
    required this.initialCaption,
    required this.postUrl,
    required this.localImagePath,
    required this.thumbnailUrl,
    this.showDeleteButton = false,
    this.showHomeButton = false,
  });

  @override
  State<RepostScreen> createState() => _RepostScreenState();
}

class _RepostScreenState extends State<RepostScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _captionController;

  static const MethodChannel _mediaStoreChannel = MethodChannel('media_store');
  static const MethodChannel _instaChannel = MethodChannel('insta_share');

  // Tag State
  final List<bool> _alignmentSelections = [true, false, false, false];
  Alignment _tagAlignment = Alignment.bottomLeft;
  bool _isTagVisible = true;

  // Tag Style
  Color _tagBackgroundColor = Colors.white;
  double _tagBackgroundOpacity = 1.0;
  Color _tagTextColor = Colors.black;
  double _tagTextOpacity = 1.0;
  Color _tagIconColor = Colors.black;
  double _tagIconOpacity = 1.0;

  // Media State
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  double _imageAspectRatio = 1.0;
  bool _isLoadingImage = true;
  bool _isReposting = false;
  bool _didOpenInstagram = false; // Flag to track if we launched Instagram

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captionController = TextEditingController(text: widget.initialCaption);
    _captionController.addListener(() {
      if (mounted) setState(() {});
    });
    _checkIfVideo();
    _loadImageAspectRatio();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captionController.dispose();
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _videoController!.pause();
    } else if (state == AppLifecycleState.resumed) {
      _videoController!.play();

      // Removed: Trigger at Step 1 instead of Step 6
      if (_didOpenInstagram) {
        debugPrint("Returned from Instagram");
        _didOpenInstagram = false; // Reset
      }
    }
  }

  // --- LOGIC: Media Initialization ---

  void _checkIfVideo() async {
    if (widget.localImagePath.toLowerCase().endsWith('.mp4')) {
      _isVideo = true;
      _videoController = VideoPlayerController.file(
        File(widget.localImagePath),
      );

      try {
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _imageAspectRatio = _videoController!.value.aspectRatio;
            _isLoadingImage = false;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
          _videoController!.addListener(_videoListener);
        }
      } catch (e) {
        debugPrint("Error initializing video: $e");
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null) return;
    setState(() {});
  }

  Future<void> _loadImageAspectRatio() async {
    final String pathToCheck = _isVideo
        ? widget.thumbnailUrl
        : widget.localImagePath;

    // Handle Network Image
    if (pathToCheck.startsWith('http')) {
      final Image image = Image.network(pathToCheck);
      final ImageStream stream = image.image.resolve(
        const ImageConfiguration(),
      );
      stream.addListener(
        ImageStreamListener(
          (ImageInfo info, bool _) {
            if (mounted) {
              setState(() {
                _imageAspectRatio = info.image.width / info.image.height;
                _isLoadingImage = false;
              });
            }
          },
          onError: (_, __) {
            if (mounted) setState(() => _isLoadingImage = false);
          },
        ),
      );
      return;
    }

    // Handle Local File
    final file = File(pathToCheck);
    if (!file.existsSync()) {
      setState(() => _isLoadingImage = false);
      return;
    }

    final Image image = Image.file(file);
    final ImageStream stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (mounted) {
            setState(() {
              _imageAspectRatio = info.image.width / info.image.height;
              _isLoadingImage = false;
            });
          }
        },
        onError: (_, __) {
          if (mounted) setState(() => _isLoadingImage = false);
        },
      ),
    );
  }

  // --- LOGIC: FFmpeg Font Preparation ---

  Future<String> _prepareFontFile() async {
    final cacheDir = await getTemporaryDirectory();
    final fontFile = File('${cacheDir.path}/roboto_bold.ttf');

    // Copy font from assets to local storage so FFmpeg can access it
    if (!await fontFile.exists()) {
      final byteData = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      await fontFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return fontFile.path;
  }

  // --- LOGIC: FFmpeg Rendering ---

  Future<File> renderVideoWithCustomStyle() async {
    final fontPath = await _prepareFontFile();
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/repost_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final cleanName = widget.username.replaceAll('@', '').trim();

    String toHex(Color c) =>
        c.value.toRadixString(16).padLeft(8, '0').substring(2);

    final textColor = toHex(_tagTextColor);
    final bgColor = toHex(_tagBackgroundColor);

    final textOpacity = _tagTextOpacity.toStringAsFixed(2);
    final bgOpacity = _tagBackgroundOpacity.toStringAsFixed(2);

    // 🔖 Unicode icon
    final tagText = "@$cleanName";

    // Alignment → FFmpeg position
    String x = "20";
    String y = "20";

    if (_tagAlignment == Alignment.bottomLeft) {
      x = "20";
      y = "h-th-30";
    } else if (_tagAlignment == Alignment.bottomRight) {
      x = "w-tw-20";
      y = "h-th-30";
    } else if (_tagAlignment == Alignment.topRight) {
      x = "w-tw-20";
      y = "30";
    } else {
      x = "20";
      y = "30";
    }

    final command =
        '-y -i "${widget.localImagePath}" '
        '-vf "drawtext='
        'fontfile=${fontPath}:'
        'text=${tagText}:'
        'x=${x}:'
        'y=${y}:'
        'fontsize=38:'
        'fontcolor=0x${textColor}@${textOpacity}:'
        'box=1:'
        'boxcolor=0x${bgColor}@${bgOpacity}:'
        'boxborderw=14" '
        '-c:v libx264 -preset ultrafast -pix_fmt yuv420p '
        '"$outputPath"';

    debugPrint("🎬 FFmpeg CMD:\n$command");

    final session = await FFmpegKit.execute(command);
    final rc = await session.getReturnCode();

    if (ReturnCode.isSuccess(rc)) {
      return File(outputPath);
    } else {
      final logs = await session.getAllLogsAsString();
      debugPrint("❌ FFmpeg Error:\n$logs");
      throw Exception("FFmpeg render failed");
    }
  }

  // --- LOGIC: Render Image with Tag ---

  Future<File> renderImageWithTag() async {
    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/repost_${DateTime.now().millisecondsSinceEpoch}.jpg';

    // Load the image
    final imageFile = File(widget.localImagePath);
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception("Failed to decode image");
    }

    final cleanName = widget.username.replaceAll('@', '').trim();
    final tagText = "@$cleanName";

    // Calculate positions based on alignment
    int x, y;
    final padding = 20;
    final fontSize = (image.height / 28).round();
    final textWidth = tagText.length * (fontSize * 0.6).round();
    final textHeight = fontSize + 8;

    if (_tagAlignment == Alignment.bottomLeft) {
      x = padding;
      y = image.height - textHeight - padding;
    } else if (_tagAlignment == Alignment.bottomRight) {
      x = image.width - textWidth - padding;
      y = image.height - textHeight - padding;
    } else if (_tagAlignment == Alignment.topRight) {
      x = image.width - textWidth - padding;
      y = padding;
    } else {
      x = padding;
      y = padding;
    }

    // Draw background rectangle
    final bgColor = img.ColorRgba8(
      _tagBackgroundColor.red,
      _tagBackgroundColor.green,
      _tagBackgroundColor.blue,
      (_tagBackgroundOpacity * 255).toInt(),
    );

    img.fillRect(
      image,
      x1: x - 8,
      y1: y - 4,
      x2: x + textWidth + 8,
      y2: y + textHeight + 4,
      color: bgColor,
    );

    // Draw text
    final textColor = img.ColorRgba8(
      _tagTextColor.red,
      _tagTextColor.green,
      _tagTextColor.blue,
      (_tagTextOpacity * 255).toInt(),
    );

    img.drawString(
      image,
      tagText,
      font: img.arial48,
      x: x,
      y: y,
      color: textColor,
    );

    // Save the modified image
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(img.encodeJpg(image));

    return outputFile;
  }

  // --- LOGIC: Handle Repost (Share Video Only) ---

  Future<void> _handleRepostAction() async {
    // 1. Taps on the repost -> rating review popup is displayed once
    await RatingService().checkAndShowRating(null, always: true);

    // Set flag to track return (optional now but kept for state consistency)
    _didOpenInstagram = true;

    // 2. Proceed to Preparing the post (FFmpeg/Image processing) / Ad flow

    // "Show an ad when reposting images at the 2nd, 4th, 6th, etc." (Even occurrences)
    AdService().handleRepostAd(() async {
      if (_isReposting) return;
      setState(() => _isReposting = true);

      try {
        String pathToSend = widget.localImagePath;

        if (_isTagVisible) {
          if (_isVideo) {
            final renderedFile = await renderVideoWithCustomStyle();
            pathToSend = renderedFile.path;
          } else {
            final renderedFile = await renderImageWithTag();
            pathToSend = renderedFile.path;
          }
        }

        // Determine media type
        final String mediaType = _isVideo ? 'video' : 'image';

        // Save to MediaStore
        final String? uriString = await _mediaStoreChannel.invokeMethod<String>(
          'saveMedia',
          {'path': pathToSend, 'mediaType': mediaType},
        );

        if (uriString != null) {
          await _instaChannel.invokeMethod('repostToInstagram', {
            'uri': uriString,
            'mediaType': mediaType,
          });
        }
      } on PlatformException catch (e) {
        debugPrint("Native Error: ${e.message}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Platform Error: ${e.message}")));
      } catch (e) {
        debugPrint("General Error: $e");
      } finally {
        if (mounted)
          setState(() => _isReposting = false); // ✅ Always stops spinner
      }
    }); // End Ad Block
  }

  // --- LOGIC: UI Helpers ---

  void _openTagEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return TagEditorSheet(
          username: widget.username,
          initialBgColor: _tagBackgroundColor,
          initialBgOpacity: _tagBackgroundOpacity,
          initialTextColor: _tagTextColor,
          initialTextOpacity: _tagTextOpacity,
          initialIconColor: _tagIconColor,
          initialIconOpacity: _tagIconOpacity,
          onUpdate: (bgColor, bgOp, textColor, textOp, iconColor, iconOp) {
            setState(() {
              _tagBackgroundColor = bgColor;
              _tagBackgroundOpacity = bgOp;
              _tagTextColor = textColor;
              _tagTextOpacity = textOp;
              _tagIconColor = iconColor;
              _tagIconOpacity = iconOp;
            });
          },
        );
      },
    );
  }

  Future<void> _showDeleteDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          Constants.AppName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          "Are you sure you want to delete this media from my collection?",
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
              _deletePostFromList();
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

  Future<void> _deletePostFromList() async {
    // 1. Stop playback immediately
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }

    try {
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'savedPosts'},
        ),
      );
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];
      savedData.removeWhere((item) {
        final Map<String, dynamic> decoded = jsonDecode(item);
        return decoded['localPath'] == widget.localImagePath;
      });
      await prefs.setStringList('savedPosts', savedData);

      if (mounted) {
        // Pop back to previous screen - it will handle the reload
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    int targetTab = _isVideo ? 1 : 0;
    if (widget.postUrl == "device_media") {
      targetTab = 2;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop({'home': true, 'tab': targetTab});
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(targetTab),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaPreview(),
              _buildToolbar(),
              _buildCaptionSection(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        bottomNavigationBar: _buildRepostButton(),
      ),
    );
  }

  AppBar _buildAppBar(int targetTab) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leadingWidth: widget.showHomeButton ? 100 : 56,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.grey),
            onPressed: () =>
                Navigator.of(context).pop({'home': true, 'tab': targetTab}),
          ),
          if (widget.showHomeButton)
            IconButton(
              icon: Image.asset(
                'assets/images/home.png',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                // Return to home and signal to show rating
                Navigator.of(context).pop({
                  'home': true,
                  'tab': targetTab,
                  'rating': true,
                });
              },
            ),
        ],
      ),
      title: Text(
        widget.username,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        if (widget.showDeleteButton)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _showDeleteDialog,
          ),
      ],
    );
  }

  Widget _buildMediaPreview() {
    return AspectRatio(
      aspectRatio: _imageAspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo &&
              _videoController != null &&
              _videoController!.value.isInitialized) ...[
            VideoPlayer(_videoController!),
            _PlayPauseOverlay(controller: _videoController!),
          ] else
            Builder(
              builder: (context) {
                // Determine the correct path to show
                final path = _isVideo
                    ? widget.thumbnailUrl
                    : widget.localImagePath;

                if (path.isEmpty) {
                  return Container(color: Colors.grey[300]);
                }

                if (path.startsWith('http')) {
                  return CachedNetworkImage(
                    imageUrl: path,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Container(color: Colors.grey[300]),
                  );
                } else {
                  return Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: Colors.grey[300]),
                  );
                }
              },
            ),
          if (_isTagVisible)
            Align(
              alignment: _tagAlignment,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: GestureDetector(
                  onTap: () async {
                    final username = widget.username.replaceAll('@', '').trim();
                    final url = 'https://www.instagram.com/$username/';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _tagBackgroundColor.withOpacity(
                        _tagBackgroundOpacity,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 16,
                          color: _tagIconColor.withOpacity(_tagIconOpacity),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "@${widget.username.replaceAll('@', '').trim()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _tagTextColor.withOpacity(_tagTextOpacity),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_isReposting)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text("Preparing...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              // 1. Position Selectors (L, R, T, B, @)
              _buildPositionSelector('L', 0, Alignment.bottomLeft),
              const SizedBox(width: 12),
              _buildPositionSelector('R', 1, Alignment.bottomRight),
              const SizedBox(width: 12),
              _buildPositionSelector('TL', 2, Alignment.topLeft),
              const SizedBox(width: 12),
              _buildPositionSelector('TR', 3, Alignment.topRight),
              const SizedBox(width: 12),
              // Visibility Toggle (@)
              GestureDetector(
                onTap: () => setState(() => _isTagVisible = !_isTagVisible),
                child: Text(
                  '@',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: _isTagVisible ? Colors.black : Colors.grey,
                  ),
                ),
              ),
              const Spacer(),

              // 2. Dark/Light & Color Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_tagBackgroundColor == Colors.black) {
                            _tagBackgroundColor = Colors.white;
                            _tagTextColor = Colors.black;
                            _tagIconColor = Colors.black;
                          } else {
                            _tagBackgroundColor = Colors.black;
                            _tagTextColor = Colors.white;
                            _tagIconColor = Colors.white;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: _tagBackgroundColor == Colors.black
                                ? Colors.black
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _tagBackgroundColor == Colors.black
                                ? "Dark"
                                : "Light",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 20,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _openTagEditor,
                      child: Image.asset(
                        'assets/images/colorpicker.png',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPositionSelector(String label, int index, Alignment alignment) {
    bool isSelected = _tagAlignment == alignment;
    return GestureDetector(
      onTap: () {
        setState(() {
          for (int i = 0; i < _alignmentSelections.length; i++) {
            _alignmentSelections[i] = (i == index);
          }
          _tagAlignment = alignment;
          _isTagVisible = true;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _captionController,
                maxLines: 2,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  hintText: "Enter caption...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (_captionController.text.isNotEmpty) {
                  Clipboard.setData(
                    ClipboardData(text: _captionController.text),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Caption copied to clipboard"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF636363),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_all_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "Copy",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepostButton() {
    int targetTab = _isVideo ? 1 : 0;
    if (widget.postUrl == "device_media") {
      targetTab = 2;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: Row(
        children: [
          // 1. Save Button
          Expanded(
            child: GestureDetector(
              onTap: () async {
                if (widget.showDeleteButton) {
                  // Entry from Collection (Home Screen Tab Bar): Show Toast
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Already saved to your In-App Collection"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  // Entry from New Download: Show Notification
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Saved to your In-App Collection"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                if (mounted) {
                  Navigator.of(context).pop({'home': true, 'tab': targetTab});
                }
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, color: Colors.black, size: 22),
                    SizedBox(width: 8),
                    Text(
                      "Save",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 2. Repost Button
          Expanded(
            child: GestureDetector(
              onTap: _isReposting ? null : _handleRepostAction,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: _isReposting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.repeat_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Repost",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayPauseOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  const _PlayPauseOverlay({required this.controller});

  @override
  State<_PlayPauseOverlay> createState() => _PlayPauseOverlayState();
}

class _PlayPauseOverlayState extends State<_PlayPauseOverlay> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (widget.controller.value.isPlaying) {
            widget.controller.pause();
          } else {
            widget.controller.play();
          }
        });
      },
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity: widget.controller.value.isPlaying ? 0.0 : 1.0,
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
    );
  }
}

// -----------------------------------------------------------------------------
// 🔹 Helper Widget: Tag Editor Sheet
// -----------------------------------------------------------------------------
class TagEditorSheet extends StatefulWidget {
  final String username;
  final Color initialBgColor;
  final double initialBgOpacity;
  final Color initialTextColor;
  final double initialTextOpacity;
  final Color initialIconColor;
  final double initialIconOpacity;
  final Function(Color, double, Color, double, Color, double) onUpdate;

  const TagEditorSheet({
    super.key,
    required this.username,
    required this.initialBgColor,
    required this.initialBgOpacity,
    required this.initialTextColor,
    required this.initialTextOpacity,
    required this.initialIconColor,
    required this.initialIconOpacity,
    required this.onUpdate,
  });

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  int _selectedTab = 0; // 0=Icon, 1=Text, 2=Background

  late Color bgColor;
  late double bgOp;
  late Color textColor;
  late double textOp;
  late Color iconColor;
  late double iconOp;

  @override
  void initState() {
    super.initState();
    bgColor = widget.initialBgColor;
    bgOp = widget.initialBgOpacity;
    textColor = widget.initialTextColor;
    textOp = widget.initialTextOpacity;
    iconColor = widget.initialIconColor;
    iconOp = widget.initialIconOpacity;
  }

  Color get currentColor =>
      _selectedTab == 0 ? iconColor : (_selectedTab == 1 ? textColor : bgColor);
  double get currentOp =>
      _selectedTab == 0 ? iconOp : (_selectedTab == 1 ? textOp : bgOp);

  void _updateColor(Color c) {
    setState(() {
      if (_selectedTab == 0)
        iconColor = c;
      else if (_selectedTab == 1)
        textColor = c;
      else
        bgColor = c;
    });
    _notifyParent();
  }

  void _updateOpacity(double val) {
    setState(() {
      if (_selectedTab == 0)
        iconOp = val;
      else if (_selectedTab == 1)
        textOp = val;
      else
        bgOp = val;
    });
    _notifyParent();
  }

  void _notifyParent() {
    widget.onUpdate(bgColor, bgOp, textColor, textOp, iconColor, iconOp);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniPreview(),
              IconButton(
                icon: const Icon(Icons.check, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab("Icon", 0),
              _buildTab("Text", 1),
              _buildTab("Background", 2),
            ],
          ),
          const Divider(height: 30),
          const Text("Color", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildColorCircle(Colors.black),
                _buildColorCircle(Colors.white),
                _buildColorCircle(const Color(0xFFF44336)),
                _buildColorCircle(const Color(0xFFE91E63)),
                _buildColorCircle(const Color(0xFF2196F3)),
                _buildColorCircle(const Color(0xFF4CAF50)),
                _buildColorCircle(const Color(0xFFFFC107)),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Pick a color'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: currentColor,
                            onColorChanged: _updateColor,
                            enableAlpha: false,
                            paletteType: PaletteType.hsvWithHue,
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Done'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Opacity",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text("${(currentOp * 100).toInt()}%"),
            ],
          ),
          Slider(
            value: currentOp,
            min: 0.0,
            max: 1.0,
            activeColor: Colors.black,
            onChanged: _updateOpacity,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(bgOp),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 16,
            color: iconColor.withOpacity(iconOp),
          ),
          const SizedBox(width: 4),
          Text(
            widget.username,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: textColor.withOpacity(textOp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    bool isSelected = index == _selectedTab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
          Container(
            height: 2,
            width: 40,
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    bool isSelected = color.value == currentColor.value;
    return GestureDetector(
      onTap: () => _updateColor(color),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black, width: 2)
              : Border.all(color: Colors.grey.shade300),
        ),
      ),
    );
  }
}
