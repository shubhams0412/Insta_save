import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:social_sharing_plus/social_sharing_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:insta_save/services/ad_service.dart'; // Import this
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:insta_save/utils/constants.dart';
import 'package:insta_save/utils/ui_utils.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum _ReelOptionAction {
  originalCaption,
  transcribeTranslate,
  hookTiming,
  trendyCaptions,
  trendyHashtags,
  exportPdf,
  downloadAssets,
}

class _ReelCreationOption {
  final String title;
  final IconData icon;
  final _ReelOptionAction action;
  final bool isPro;

  const _ReelCreationOption({
    required this.title,
    required this.icon,
    required this.action,
    this.isPro = true,
  });
}

class _ReelReportData {
  final String username;
  final String title;
  final String originalCaption;
  final String currentCaption;
  final String trendyCaption;
  final String transcript;
  final String translated;
  final String detectedLanguage;
  final String hookText;
  final double hookStart;
  final double hookEnd;
  final List<String> hashtags;
  final List<String> keywords;
  final Uint8List? thumbnailBytes;

  const _ReelReportData({
    required this.username,
    required this.title,
    required this.originalCaption,
    required this.currentCaption,
    required this.trendyCaption,
    required this.transcript,
    required this.translated,
    required this.detectedLanguage,
    required this.hookText,
    required this.hookStart,
    required this.hookEnd,
    required this.hashtags,
    required this.keywords,
    required this.thumbnailBytes,
  });
}

class RepostScreen extends StatefulWidget {
  final String imageUrl;
  final String username;
  final String initialCaption;
  final String postUrl;
  final String localImagePath;
  final List<String> allMediaPaths;
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
    this.allMediaPaths = const [],
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

  static const String _apiBaseUrl = kReleaseMode
      ? "https://api.instasave.turbofast.io/"
      : "http://13.200.64.163:9081/";

  // ── Local Cache Helper ────────────────────────────────────
  Future<String?> _getFromCache(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_${widget.imageUrl}_$type';
    return prefs.getString(key);
  }

  Future<void> _saveToCache(String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_${widget.imageUrl}_$type';
    await prefs.setString(key, jsonEncode(data));
  }

  // ──────────────────────────────────────────────────────────
  static const List<_ReelCreationOption> _reelCreationOptions = [
    _ReelCreationOption(
      title: 'Original\nCaption',
      icon: Icons.notes_rounded,
      action: _ReelOptionAction.originalCaption,
      isPro: false,
    ),
    _ReelCreationOption(
      title: 'Transcribe &\nTranslate',
      icon: Icons.translate_rounded,
      action: _ReelOptionAction.transcribeTranslate,
    ),
    _ReelCreationOption(
      title: 'Hook\nGenerator',
      icon: Icons.whatshot_rounded,
      action: _ReelOptionAction.hookTiming,
    ),
    _ReelCreationOption(
      title: 'Trendy\nCaptions',
      icon: Icons.edit_note_rounded,
      action: _ReelOptionAction.trendyCaptions,
    ),
    _ReelCreationOption(
      title: 'Trendy\nHashtags',
      icon: Icons.tag_rounded,
      action: _ReelOptionAction.trendyHashtags,
    ),
    _ReelCreationOption(
      title: 'Export\nPDF',
      icon: Icons.picture_as_pdf_outlined,
      action: _ReelOptionAction.exportPdf,
    ),
    _ReelCreationOption(
      title: 'Download\nImages & PDF',
      icon: Icons.download_rounded,
      action: _ReelOptionAction.downloadAssets,
    ),
  ];

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

      // Navigate to HomeScreen when returning from Instagram
      if (_didOpenInstagram && mounted) {
        debugPrint("Returned from Instagram - Navigating to HomeScreen");
        _didOpenInstagram = false; // Reset

        // Determine target tab
        int targetTab = _isVideo ? 1 : 0;
        if (widget.postUrl == "device_media") {
          targetTab = 2;
        }

        // Navigate to HomeScreen
        Navigator.of(context).pop({'home': true, 'tab': targetTab});
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
              });
            }
          },
          onError: (_, __) {
            // Error handling
          },
        ),
      );
      return;
    }

    // Handle Local File
    final file = File(pathToCheck);
    if (!file.existsSync()) {
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
            });
          }
        },
        onError: (_, __) {
          // Error handling
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
        c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);

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
        'fontfile=$fontPath:'
        'text=$tagText:'
        'x=$x:'
        'y=$y:'
        'fontsize=38:'
        'fontcolor=0x$textColor@$textOpacity:'
        'box=1:'
        'boxcolor=0x$bgColor@$bgOpacity:'
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
      (_tagBackgroundColor.r * 255).round(),
      (_tagBackgroundColor.g * 255).round(),
      (_tagBackgroundColor.b * 255).round(),
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
      (_tagTextColor.r * 255).round(),
      (_tagTextColor.g * 255).round(),
      (_tagTextColor.b * 255).round(),
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
    // Set flag to track return (optional now but kept for state consistency)
    _didOpenInstagram = true;

    // Proceed to Preparing the post (FFmpeg/Image processing) / Ad flow

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
          try {
            await _instaChannel.invokeMethod('repostToInstagram', {
              'uri': uriString,
              'mediaType': mediaType,
            });
          } catch (e) {
            debugPrint(
              "Instagram not found or share failed, opening share sheet: $e",
            );
            // Fallback: Use share_plus to open generic share sheet
            await Share.shareXFiles([
              XFile(pathToSend),
            ], text: _captionController.text);
          }
          // Navigation will happen in didChangeAppLifecycleState when user returns from Instagram
        }
      } on PlatformException catch (e) {
        debugPrint("Native Error: ${e.message}");
        if (mounted) {
          UIUtils.showSnackBar(context, "Platform Error: ${e.message}");
        }
      } catch (e) {
        debugPrint("General Error: $e");
      } finally {
        if (mounted) {
          setState(() => _isReposting = false); // ✅ Always stops spinner
        }
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
          Constants.appName,
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

  Future<void> _handleReelOptionTap(_ReelCreationOption option) async {
    switch (option.action) {
      // ── 1. Original Caption ─────────────────────────────────
      case _ReelOptionAction.originalCaption:
        final caption = widget.initialCaption.trim();
        if (caption.isEmpty) {
          UIUtils.showSnackBar(context, 'No original caption available');
          return;
        }
        await Clipboard.setData(ClipboardData(text: caption));
        if (mounted) UIUtils.showSnackBar(context, 'Original caption copied ✓');
        break;

      // ── 2. Transcribe & Translate ────────────────────────────
      case _ReelOptionAction.transcribeTranslate:
        if (!_isVideo) {
          UIUtils.showSnackBar(
            context,
            'Transcription is only for video reels',
          );
          return;
        }
        await _showTranscribeSheet();
        break;

      // ── 3. Hook Timing ──────────────────────────────────────
      case _ReelOptionAction.hookTiming:
        if (!_isVideo) {
          UIUtils.showSnackBar(
            context,
            'Hook extraction is only for video reels',
          );
          return;
        }
        await _showHookSheet();
        break;

      // ── 4. Trendy Captions ──────────────────────────────────
      case _ReelOptionAction.trendyCaptions:
        final src = _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : widget.initialCaption.trim();
        // Removed src.isEmpty validation since AI now uses the image/video content!
        await _showTrendyCaptionsSheet(src);
        break;

      // ── 5. Trendy Hashtags ──────────────────────────────────
      case _ReelOptionAction.trendyHashtags:
        final src = _captionController.text.trim().isNotEmpty
            ? _captionController.text.trim()
            : widget.initialCaption.trim();
        // Removed src.isEmpty validation since AI now uses the image/video content!
        await _showTrendyHashtagsSheet(src);
        break;

      // ── 6. Export as PDF ────────────────────────────────────
      case _ReelOptionAction.exportPdf:
        _showExportPdfSheet();
        break;

      // ── 7. Download Post Images/PDF ─────────────────────────
      case _ReelOptionAction.downloadAssets:
        _showDownloadAssetsSheet();
        break;
    }
  }

  Future<bool> _hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  // ── API helper (file upload) ────────────────────────────────
  Future<Map<String, dynamic>> _postFileApi(
    String path,
    String localFilePath, {
    Map<String, String> extraFields = const {},
  }) async {
    final uri = Uri.parse('$_apiBaseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    req.files.add(
      await http.MultipartFile.fromPath('video_file', localFilePath),
    );
    req.fields.addAll(extraFields);
    final streamed = await req.send().timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  // ── 2. Transcribe sheet + ML Kit translation ────────────────────
  Future<void> _showTranscribeSheet() async {
    final videoPath = widget.localImagePath.isNotEmpty
        ? widget.localImagePath
        : widget.imageUrl;

    if (!File(videoPath).existsSync()) {
      UIUtils.showSnackBar(context, 'Video file not found on device');
      return;
    }

    // ── Check Cache ──
    final cachedJson = await _getFromCache('transcribe');
    if (!mounted) return;
    if (cachedJson != null) {
      final data = jsonDecode(cachedJson);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _TranscriptSheet(
            transcript: data['transcript'],
            translated: data['translated'],
            detectedLanguage: data['detected_language'],
          ),
        );
      }
      return;
    }
    // ─────────────────

    if (!await _hasInternet()) {
      if (mounted) {
        UIUtils.showSnackBar(
          context,
          'No internet connection. Please try again when online.',
        );
      }
      return;
    }

    _showLoadingOverlay('Uploading & Transcribing reel…\nPlease wait a moment');

    String transcript = '';
    String translated = '';
    String detectedLang = 'en';
    String? errorMsg;

    try {
      final res = await _postFileApi('transcribe', videoPath);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      transcript = (data['transcript'] as String? ?? '').trim();
      final translatedVal = (data['translated'] as String? ?? '').trim();
      detectedLang = data['detected_language'] as String? ?? 'en';
      translated = translatedVal.isNotEmpty ? translatedVal : transcript;
      if (transcript.isEmpty) {
        errorMsg = 'Could not transcribe this reel. Please try again shortly.';
      }
      if (transcript.isNotEmpty) {
        await _saveToCache('transcribe', {
          'transcript': transcript,
          'translated': translated,
          'detected_language': detectedLang,
        });
      }
    } catch (e) {
      errorMsg = 'Transcription failed: $e';
    } finally {
      if (mounted) _hideLoadingOverlay();
    }

    if (!mounted) return;
    if (errorMsg != null) {
      UIUtils.showSnackBar(context, errorMsg);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => _TranscriptSheet(
        transcript: transcript,
        translated: translated,
        detectedLanguage: detectedLang,
      ),
    );
  }

  // ── 3. Hook sheet ───────────────────────────────────────────
  Future<void> _showHookSheet() async {
    final videoPath = widget.localImagePath.isNotEmpty
        ? widget.localImagePath
        : widget.imageUrl;

    if (!File(videoPath).existsSync()) {
      UIUtils.showSnackBar(context, 'Video file not found on device');
      return;
    }

    // ── Check Cache ──
    final cachedJson = await _getFromCache('hook');
    if (!mounted) return;
    if (cachedJson != null) {
      final data = jsonDecode(cachedJson);
      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _HookSheet(
            hookText: data['hook_text'],
            startTime: data['start_time'],
            endTime: data['end_time'],
          ),
        );
      }
      return;
    }
    // ─────────────────

    if (!await _hasInternet()) {
      if (mounted) {
        UIUtils.showSnackBar(
          context,
          'No internet connection. Please try again when online.',
        );
      }
      return;
    }

    _showLoadingOverlay('Uploading & Analyzing Hook…\nPlease wait a moment');

    String hookText = '';
    double startTime = 0;
    double endTime = 0;
    String? errorMsg;

    try {
      final res = await _postFileApi('extract_hook', videoPath);
      final data = res['data'] as Map<String, dynamic>? ?? {};
      hookText = (data['hook_text'] as String? ?? '').trim();
      startTime = (data['start_time'] as num? ?? 0).toDouble();
      endTime = (data['end_time'] as num? ?? 0).toDouble();
      if (hookText.isEmpty) errorMsg = 'Could not identify a hook in this reel';
      await _saveToCache('hook', {
        'hook_text': hookText,
        'start_time': startTime,
        'end_time': endTime,
      });
    } catch (e) {
      errorMsg = 'Hook extraction failed: $e';
    } finally {
      if (mounted) _hideLoadingOverlay();
    }

    if (!mounted) return;
    if (errorMsg != null) {
      UIUtils.showSnackBar(context, errorMsg);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HookSheet(
        hookText: hookText,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  // ── 4. Trendy Captions sheet ────────────────────────────────
  Future<void> _showTrendyCaptionsSheet(String originalCaption) async {
    // ── Check Cache ──
    final cachedJson = await _getFromCache('caption');
    if (!mounted) return;
    if (cachedJson != null) {
      final data = jsonDecode(cachedJson);
      final mediaPath = widget.localImagePath.isNotEmpty
          ? widget.localImagePath
          : widget.imageUrl;

      Future<String?> fetchCaption() async {
        final res = await _postFileApi(
          'trendy_captions',
          mediaPath,
          extraFields: {'caption': originalCaption},
        );
        final innerData = res['data'] as Map<String, dynamic>? ?? {};
        final caps = (innerData['captions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        return caps.isNotEmpty ? caps.first : null;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _TrendyCaptionsSheet(
            initialCaption: data['caption'],
            fetchCaption: fetchCaption,
            onUse: (c) {
              _captionController.text = c;
              Clipboard.setData(ClipboardData(text: c));
              Navigator.of(context).pop();
              UIUtils.showSnackBar(context, 'Caption applied ✓');
            },
          ),
        );
      }
      return;
    }
    // ─────────────────

    if (!await _hasInternet()) {
      if (mounted) {
        UIUtils.showSnackBar(
          context,
          'No internet connection. Please try again when online.',
        );
      }
      return;
    }

    _showLoadingOverlay('Generating Trendy Caption…\nPlease wait a moment');

    final mediaPath = widget.localImagePath.isNotEmpty
        ? widget.localImagePath
        : widget.imageUrl;

    Future<String?> fetchCaption() async {
      final res = await _postFileApi(
        'trendy_captions',
        mediaPath,
        extraFields: {'caption': originalCaption},
      );
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final captions = (data['captions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      final result = captions.isNotEmpty ? captions.first : null;
      if (result != null) await _saveToCache('caption', {'caption': result});
      return result;
    }

    String? caption;
    String? errorMsg;
    try {
      caption = await fetchCaption();
      if (caption == null) errorMsg = 'Could not generate caption';
    } catch (e) {
      errorMsg = 'Caption generation failed: $e';
    } finally {
      if (mounted) _hideLoadingOverlay();
    }

    if (!mounted) return;
    if (errorMsg != null) {
      UIUtils.showSnackBar(context, errorMsg);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TrendyCaptionsSheet(
        initialCaption: caption!,
        fetchCaption: fetchCaption,
        onUse: (c) {
          _captionController.text = c;
          Clipboard.setData(ClipboardData(text: c));
          Navigator.of(context).pop();
          UIUtils.showSnackBar(context, 'Caption applied ✓');
        },
      ),
    );
  }

  // ── 5. Trendy Hashtags sheet ────────────────────────────────
  Future<void> _showTrendyHashtagsSheet(String caption) async {
    if (_isAiBusy) return;
    setState(() => _isAiBusy = true);

    // ── Check Cache ──
    final cachedJson = await _getFromCache('hashtags');
    if (!mounted) {
      _isAiBusy = false;
      return;
    }
    if (cachedJson != null) {
      final data = jsonDecode(cachedJson);
      final picks = (data['picks'] as List? ?? []).cast<String>();
      if (picks.isNotEmpty) {
        _isAiBusy = false;
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => _TrendyHashtagsSheet(trendyPicks: picks),
        );
        return;
      }
      // If empty, continue to fetch fresh ones instead of silent return
    }
    // ─────────────────

    if (!await _hasInternet()) {
      setState(() => _isAiBusy = false);
      if (mounted) {
        UIUtils.showSnackBar(
          context,
          'No internet connection. Please try again when online.',
        );
      }
      return;
    }

    _showLoadingOverlay('Generating Trending Hashtags…\nPlease wait a moment');

    final mediaPath = widget.localImagePath.isNotEmpty
        ? widget.localImagePath
        : widget.imageUrl;

    List<String> picks = [];
    String? errorMsg;
    try {
      final res = await _postFileApi(
        'trendy_hashtags',
        mediaPath,
        extraFields: {'caption': caption},
      );
      final data = res['data'] as Map<String, dynamic>? ?? {};
      picks = [
        ...(data['high_reach'] as List<dynamic>? ?? []).map(
          (e) => e.toString(),
        ),
        ...(data['mid_reach'] as List<dynamic>? ?? []).map((e) => e.toString()),
        ...(data['niche_reach'] as List<dynamic>? ?? []).map(
          (e) => e.toString(),
        ),
      ];
      await _saveToCache('hashtags', {'picks': picks});
      if (picks.isEmpty) errorMsg = 'Could not generate hashtags';
    } catch (e) {
      errorMsg = 'Hashtag generation failed: $e';
    } finally {
      setState(() => _isAiBusy = false);
      if (mounted) _hideLoadingOverlay();
    }

    if (!mounted) return;
    if (errorMsg != null) {
      UIUtils.showSnackBar(context, errorMsg);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _TrendyHashtagsSheet(trendyPicks: picks),
    );
  }

  // ── 6. Export as PDF ────────────────────────────────────────
  void _showExportPdfSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportPdfSheet(
        thumbnailPath: widget.localImagePath,
        thumbnailUrl: widget.thumbnailUrl,
        onDownload: _exportAsPdf,
      ),
    );
  }

  void _showDownloadAssetsSheet() {
    final paths =
        (widget.allMediaPaths.isNotEmpty
                ? widget.allMediaPaths
                : [widget.localImagePath])
            .where((path) {
              final p = path.toLowerCase();
              return !p.endsWith('.mp4') && !p.endsWith('.mov');
            })
            .toList();

    if (paths.isEmpty) {
      UIUtils.showSnackBar(
        context,
        'No downloadable images available for this post.',
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadAssetsSheet(
        allMediaPaths: paths,
        username: widget.username,
        onDownload: (selectedPaths) async {
          // Show a simple selection dialog for format
          final format = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Choose Format',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: const Text(
                'How would you like to save the selected items?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'images'),
                  child: const Text('As Images'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'pdf'),
                  child: const Text('As one PDF'),
                ),
              ],
            ),
          );

          if (format == null) return;

          if (format == 'images') {
            await _saveMultipleImages(selectedPaths);
          } else {
            await _saveImagesAsPdf(selectedPaths);
          }
        },
      ),
    );
  }

  Future<void> _saveMultipleImages(List<String> paths) async {
    int count = 0;
    for (final path in paths) {
      try {
        final String? uriString = await _mediaStoreChannel.invokeMethod<String>(
          'saveMedia',
          {'path': path, 'mediaType': 'image'},
        );
        if (uriString != null) count++;
      } catch (e) {
        debugPrint('Failed to save image $path: $e');
      }
    }

    if (mounted) {
      UIUtils.showSnackBar(context, '$count images saved to gallery ✓');
    }
  }

  Future<void> _saveImagesAsPdf(List<String> paths) async {
    try {
      UIUtils.showSnackBar(context, 'Generating PDF…');
      final doc = pw.Document();

      for (final path in paths) {
        final bytes = await File(path).readAsBytes();
        final image = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            },
          ),
        );
      }

      final pdfBytes = await doc.save();
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'insta_images_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      final String? uriString = await _mediaStoreChannel.invokeMethod<String>(
        'saveMedia',
        {'path': file.path, 'mediaType': 'pdf'},
      );

      if (mounted) {
        if (uriString != null) {
          UIUtils.showSnackBar(context, 'PDF saved to gallery ✓');
        } else {
          UIUtils.showSnackBar(context, 'Failed to save PDF');
        }
      }
    } catch (e) {
      debugPrint('PDF generation failed: $e');
      if (mounted) {
        UIUtils.showSnackBar(context, 'PDF generation failed');
      }
    }
  }

  Future<void> _exportAsPdf([String? shareTarget]) async {
    try {
      UIUtils.showSnackBar(context, 'Preparing PDF…');
      final report = await _loadReelReportData();
      final pdfBytes = await _buildReelReportPdf(report);
      final date = DateTime.now();
      final dateStr = '${date.day}-${date.month}-${date.year}';
      final username = widget.username.replaceAll('@', '').trim();
      final filename =
          '${username.isEmpty ? 'reel' : username}_report_$dateStr.pdf';

      if (shareTarget == 'download') {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        if (!mounted) return;
        final String? uri = await _mediaStoreChannel.invokeMethod<String>(
          'saveMedia',
          {'path': file.path, 'mediaType': 'pdf'},
        );
        if (mounted) {
          UIUtils.showSnackBar(
            context,
            uri != null ? 'PDF saved to Downloads ✓' : 'Failed to save PDF',
          );
        }
        return;
      }

      if (shareTarget == 'share') {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        if (!mounted) return;
        await Share.shareXFiles([XFile(file.path)], subject: filename);
        return;
      }

      if (shareTarget != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);

        if (!mounted) return;

        switch (shareTarget) {
          case 'whatsapp':
            await SocialSharingPlus.shareToSocialMedia(
              SocialPlatform.whatsapp,
              '',
              media: file.path,
            );
          case 'instagram':
            try {
              await _instaChannel.invokeMethod('shareFileToApp', {
                'path': file.path,
                'packageName': 'com.instagram.android',
                'mimeType': 'application/pdf',
              });
            } catch (_) {
              await Share.shareXFiles([XFile(file.path)]);
            }
          case 'drive':
            try {
              await _instaChannel.invokeMethod('shareFileToApp', {
                'path': file.path,
                'packageName': 'com.google.android.apps.docs',
                'mimeType': 'application/pdf',
                'subject': filename,
              });
            } catch (_) {
              await Share.shareXFiles([XFile(file.path)], subject: filename);
            }
          case 'mail':
            try {
              await _instaChannel.invokeMethod('shareFileToApp', {
                'path': file.path,
                'packageName': 'com.google.android.gm',
                'mimeType': 'application/pdf',
                'subject': 'Reel Report - ${widget.username}',
                'body': 'Please find the attached reel report.',
              });
            } catch (_) {
              await Share.shareXFiles(
                [XFile(file.path)],
                subject: 'Reel Report - ${widget.username}',
                text: 'Please find the attached reel report.',
              );
            }
          default:
            await Share.shareXFiles([XFile(file.path)]);
        }
        return;
      }

      // Calculate total pages for display
      final int totalPages =
          1 +
          (report.hookText.isNotEmpty ? 1 : 0) +
          (report.transcript.isNotEmpty ? 1 : 0) +
          (report.trendyCaption.isNotEmpty ? 1 : 0) +
          (report.keywords.isNotEmpty ? 1 : 0) +
          (report.hashtags.isNotEmpty ? 1 : 0);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _ReelReportPreviewScreen(
            pdfBytes: pdfBytes,
            filename: filename,
            title: report.title,
            subtitle:
                '$totalPages ${totalPages == 1 ? 'page' : 'pages'} · creator deliverable',
          ),
        ),
      );
    } catch (e) {
      debugPrint('PDF export failed: $e');
      if (mounted) {
        UIUtils.showSnackBar(context, 'PDF export failed. Please try again.');
      }
    }
  }

  Future<_ReelReportData> _loadReelReportData() async {
    Map<String, dynamic> decodeCache(String? jsonString) {
      if (jsonString == null || jsonString.trim().isEmpty) {
        return <String, dynamic>{};
      }
      try {
        final decoded = jsonDecode(jsonString);
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    final cached = await Future.wait([
      _getFromCache('transcribe'),
      _getFromCache('hook'),
      _getFromCache('caption'),
      _getFromCache('hashtags'),
    ]);

    final transcribeData = decodeCache(cached[0]);
    final hookData = decodeCache(cached[1]);
    final captionData = decodeCache(cached[2]);
    final hashtagData = decodeCache(cached[3]);

    final originalCaption = widget.initialCaption.trim();
    final currentCaption = _captionController.text.trim();
    final trendyCaption = (captionData['caption'] as String? ?? '').trim();
    final transcript = (transcribeData['transcript'] as String? ?? '').trim();
    final translated = (transcribeData['translated'] as String? ?? '').trim();
    final detectedLanguage =
        (transcribeData['detected_language'] as String? ?? 'unknown').trim();
    final hookText = (hookData['hook_text'] as String? ?? '').trim();
    final hookStart = (hookData['start_time'] as num? ?? 0).toDouble();
    final hookEnd = (hookData['end_time'] as num? ?? 0).toDouble();

    final cachedHashtags = (hashtagData['picks'] as List? ?? [])
        .map((item) => item.toString().trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    final hashtags = cachedHashtags;

    final reportText = [
      originalCaption,
      currentCaption,
      trendyCaption,
      transcript,
      translated,
      hookText,
      hashtags.join(' '),
    ].join(' ');

    return _ReelReportData(
      username: widget.username,
      title: _buildReportTitle(originalCaption, currentCaption),
      originalCaption: originalCaption,
      currentCaption: currentCaption,
      trendyCaption: trendyCaption,
      transcript: transcript,
      translated: translated,
      detectedLanguage: detectedLanguage.isEmpty ? 'unknown' : detectedLanguage,
      hookText: hookText,
      hookStart: hookStart,
      hookEnd: hookEnd,
      hashtags: hashtags,
      keywords: _extractKeywords(reportText),
      thumbnailBytes: await _loadReportThumbnailBytes(),
    );
  }

  String _buildReportTitle(String originalCaption, String currentCaption) {
    final source = currentCaption.isNotEmpty ? currentCaption : originalCaption;
    final words = source
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'#\w+'), '')
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().length > 2)
        .take(4)
        .join(' ');

    if (words.isNotEmpty) {
      return 'Reel Report - $words';
    }

    final cleanUser = widget.username.replaceAll('@', '').trim();
    return cleanUser.isEmpty ? 'Reel Report' : 'Reel Report - @$cleanUser';
  }

  List<String> _extractKeywords(String text) {
    const stopWords = {
      'about',
      'after',
      'again',
      'also',
      'and',
      'are',
      'because',
      'been',
      'but',
      'can',
      'for',
      'from',
      'have',
      'here',
      'into',
      'just',
      'like',
      'more',
      'not',
      'our',
      'out',
      'that',
      'the',
      'this',
      'was',
      'what',
      'when',
      'with',
      'your',
    };

    final counts = <String, int>{};
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r'https?://\S+'), ' ')
        .split(RegExp(r'[^a-z0-9#]+'))
        .where((word) => word.length > 3 && !stopWords.contains(word));

    for (final word in words) {
      final cleaned = word.startsWith('#') ? word.substring(1) : word;
      if (cleaned.length <= 3) continue;
      counts[cleaned] = (counts[cleaned] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((entry) => entry.key).toList();
  }

  Future<Uint8List?> _loadReportThumbnailBytes() async {
    final candidates = [
      if (widget.thumbnailUrl.isNotEmpty) widget.thumbnailUrl,
      if (widget.localImagePath.isNotEmpty) widget.localImagePath,
      if (widget.imageUrl.isNotEmpty) widget.imageUrl,
    ];

    for (final candidate in candidates) {
      final ext = candidate.toLowerCase();
      if (ext.endsWith('.mp4') ||
          ext.endsWith('.mov') ||
          ext.contains('.mp4?') ||
          ext.contains('.mov?')) {
        continue;
      }

      try {
        if (candidate.startsWith('http')) {
          final response = await http
              .get(Uri.parse(candidate))
              .timeout(const Duration(seconds: 8));
          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            return response.bodyBytes;
          }
          continue;
        }

        final file = File(candidate);
        if (file.existsSync()) {
          return await file.readAsBytes();
        }
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  Future<List<pw.Font>> _loadPdfFallbackFonts() async {
    final fonts = <pw.Font>[];

    Future<void> addFont(Future<pw.Font> Function() loader) async {
      try {
        fonts.add(await loader());
      } catch (e) {
        debugPrint('PDF fallback font load skipped: $e');
      }
    }

    await addFont(PdfGoogleFonts.notoSansRegular);
    await addFont(PdfGoogleFonts.notoSansDevanagariRegular);
    await addFont(PdfGoogleFonts.notoSansGujaratiRegular);
    await addFont(PdfGoogleFonts.notoSansArabicRegular);
    await addFont(PdfGoogleFonts.notoSansBengaliRegular);
    await addFont(PdfGoogleFonts.notoSansTamilRegular);
    await addFont(PdfGoogleFonts.notoSansTeluguRegular);
    await addFont(PdfGoogleFonts.notoColorEmojiRegular);

    return fonts;
  }

  String _sanitizePdfText(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final isAscii = rune >= 0x20 && rune <= 0x7E;
      final isLatinExtended = rune >= 0x00A0 && rune <= 0x024F;
      final isCommonPunctuation =
          rune == 0x2013 ||
          rune == 0x2014 ||
          rune == 0x2018 ||
          rune == 0x2019 ||
          rune == 0x201C ||
          rune == 0x201D ||
          rune == 0x2022 ||
          rune == 0x2026 ||
          rune == 0x00B7;

      if (isAscii || isLatinExtended || isCommonPunctuation) {
        buffer.writeCharCode(rune);
      } else if (rune == 0x0A || rune == 0x0D || rune == 0x09) {
        buffer.writeCharCode(rune);
      } else {
        buffer.write(' ');
      }
    }

    return buffer.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  String _stripPdfEmoji(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final isEmojiOrPictograph =
          (rune >= 0x1F000 && rune <= 0x1FAFF) ||
          (rune >= 0x2600 && rune <= 0x27BF) ||
          rune == 0xFE0F;
      if (!isEmojiOrPictograph) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  Future<Uint8List> _buildReelReportPdf(_ReelReportData report) async {
    final doc = pw.Document();

    // ── Determine which sections to include ──
    final bool hasHook = report.hookText.isNotEmpty;
    final bool hasTranscript = report.transcript.isNotEmpty;
    final bool hasCaptions = report.trendyCaption.isNotEmpty;
    final bool hasKeywords = report.keywords.isNotEmpty;
    final bool hasHashtags = report.hashtags.isNotEmpty;

    // Total pages = Intro (1) + Hook (0/1) + Transcript (0/1) + Captions (0/1) + Keywords (0/1) + Hashtags (0/1)
    final int totalPagesCount =
        1 +
        (hasHook ? 1 : 0) +
        (hasTranscript ? 1 : 0) +
        (hasCaptions ? 1 : 0) +
        (hasKeywords ? 1 : 0) +
        (hasHashtags ? 1 : 0);

    int currentPageIndex = 1;

    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final scriptFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Lobster-Regular.ttf'),
    );
    final fallbackFonts = await _loadPdfFallbackFonts();
    final canRenderExtendedText = fallbackFonts.isNotEmpty;
    final baseTheme = pw.ThemeData.withFont(
      base: boldFont,
      bold: boldFont,
      italic: scriptFont,
      boldItalic: scriptFont,
      fontFallback: fallbackFonts,
    );

    const pageFormat = PdfPageFormat.a4;
    const bg = PdfColor.fromInt(0xFFF2EFE6);
    const ink = PdfColor.fromInt(0xFF161616);
    const muted = PdfColor.fromInt(0xFF74706A);
    const line = PdfColor.fromInt(0xFFE0D8C8);
    const salmon = PdfColor.fromInt(0xFFFF8D84);
    final pageWidth = pageFormat.width;
    final pageHeight = pageFormat.height;
    final pageContentWidth = pageWidth - 60;
    final cardContentWidth = pageContentWidth - 44;

    String pdfText(String value) =>
        canRenderExtendedText ? _stripPdfEmoji(value) : _sanitizePdfText(value);

    String safe(String value, String fallback) {
      final text = value.trim().isEmpty ? fallback : value.trim();
      return pdfText(text);
    }

    String time(double seconds) {
      final minutes = seconds ~/ 60;
      final secs = (seconds % 60).round().toString().padLeft(2, '0');
      return '$minutes:$secs';
    }

    pw.Widget label(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: ink,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
        ),
        child: pw.Text(
          text,
          style: const pw.TextStyle(
            color: PdfColors.white,
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
      );
    }

    pw.Widget scriptTitle(String text, {double size = 20}) {
      return pw.Text(
        pdfText(text),
        style: pw.TextStyle(
          font: scriptFont,
          fontSize: size,
          color: ink,
          fontWeight: pw.FontWeight.normal,
        ),
      );
    }

    pw.Widget pageShell({
      required int page,
      required int totalPages,
      required pw.Widget child,
      bool dark = false,
    }) {
      return pw.SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: pw.Container(
          color: bg,
          padding: const pw.EdgeInsets.all(30),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  width: pageContentWidth,
                  padding: const pw.EdgeInsets.all(22),
                  decoration: pw.BoxDecoration(
                    color: dark ? ink : PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                    border: pw.Border.all(
                      color: dark ? ink : line,
                      width: dark ? 0 : 1,
                    ),
                  ),
                  child: child,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated with ${Constants.appName} · Pro',
                    style: const pw.TextStyle(fontSize: 8, color: muted),
                  ),
                  pw.Text(
                    '$page / $totalPages',
                    style: const pw.TextStyle(fontSize: 8, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    pw.Widget statCard(String label, String value) {
      return pw.Container(
        width: 220,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: ink, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7, color: muted),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              pdfText(value),
              style: pw.TextStyle(font: scriptFont, fontSize: 18),
            ),
          ],
        ),
      );
    }

    pw.Widget borderedText(String title, String text) {
      return pw.Container(
        width: cardContentWidth,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ink, width: 0.8),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: muted),
            ),
            pw.SizedBox(height: 7),
            pw.Text(
              safe(
                text,
                'No local data saved yet. Generate this item from the reel first.',
              ),
              style: const pw.TextStyle(fontSize: 11, height: 1.45),
            ),
          ],
        ),
      );
    }

    pw.Widget hashtagWrap(List<String> tags) {
      final items = tags.isEmpty
          ? ['No local hashtags saved yet']
          : tags.take(24).toList();
      return pw.Wrap(
        spacing: 6,
        runSpacing: 6,
        children: items
            .map(
              (tag) => pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: ink, width: 0.8),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(12),
                  ),
                ),
                child: pw.Text(
                  pdfText(tag),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            )
            .toList(),
      );
    }

    pw.Widget keywordTable() {
      final keywords = report.keywords.isEmpty
          ? ['caption', 'reel', 'creator']
          : report.keywords.take(6).toList();
      return pw.Table(
        border: pw.TableBorder.all(color: line, width: 0.7),
        columnWidths: const {
          0: pw.FlexColumnWidth(2),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: ink),
            children: ['KEYWORD', 'SOURCE', 'INTENT']
                .map(
                  (text) => pw.Padding(
                    padding: const pw.EdgeInsets.all(7),
                    child: pw.Text(
                      text,
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 8,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          ...keywords.map(
            (keyword) => pw.TableRow(
              children:
                  [
                        keyword,
                        report.hashtags.any(
                              (tag) => tag.toLowerCase().contains(
                                keyword.toLowerCase(),
                              ),
                            )
                            ? 'Hashtag'
                            : 'Caption',
                        'Social',
                      ]
                      .map(
                        (text) => pw.Padding(
                          padding: const pw.EdgeInsets.all(7),
                          child: pw.Text(
                            pdfText(text),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      );
    }

    pw.Widget reportHeader(String title) {
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              scriptTitle(title, size: 18),
              pw.SizedBox(height: 2),
              pw.Text(
                pdfText(
                  'By ${report.username.isEmpty ? '@creator' : report.username} · ${DateTime.now().month}/${DateTime.now().year}',
                ),
                style: const pw.TextStyle(fontSize: 9, color: muted),
              ),
            ],
          ),
          pw.Text(
            'creator deliverable',
            style: const pw.TextStyle(fontSize: 9, color: muted),
          ),
        ],
      );
    }

    // --- Page 1: Title & Overview ---
    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          theme: baseTheme,
        ),
        build: (_) => pageShell(
          page: currentPageIndex++,
          totalPages: totalPagesCount,
          dark: true,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              label('REEL REPORT · 2026'),
              pw.SizedBox(height: 34),
              pw.Text(
                'Reel report.',
                style: pw.TextStyle(
                  font: scriptFont,
                  fontSize: 40,
                  color: PdfColors.white,
                ),
              ),
              pw.Text(
                safe(
                  report.title.replaceFirst('Reel Report - ', ''),
                  'Creator insights.',
                ),
                style: pw.TextStyle(
                  font: scriptFont,
                  fontSize: 32,
                  color: salmon,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                pdfText(
                  'By ${report.username.isEmpty ? '@creator' : report.username} · local AI report',
                ),
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.white),
              ),
              if (report.thumbnailBytes != null) ...[
                pw.SizedBox(height: 24),
                pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: pw.Image(
                    pw.MemoryImage(report.thumbnailBytes!),
                    height: 190,
                    width: cardContentWidth,
                    fit: pw.BoxFit.cover,
                  ),
                ),
              ],
              pw.Spacer(),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (hasHook)
                    statCard(
                      'Hook timing',
                      '${time(report.hookStart)} - ${time(report.hookEnd)}',
                    ),
                  if (hasTranscript)
                    statCard(
                      'Transcript words',
                      report.transcript.split(RegExp(r'\s+')).length.toString(),
                    ),
                  statCard(
                    'Caption words',
                    [
                          report.currentCaption,
                          report.trendyCaption,
                          report.originalCaption,
                        ]
                        .firstWhere(
                          (c) => c.trim().isNotEmpty,
                          orElse: () => '',
                        )
                        .split(RegExp(r'\s+'))
                        .where((word) => word.trim().isNotEmpty)
                        .length
                        .toString(),
                  ),
                  if (hasHashtags)
                    statCard('Hashtags', report.hashtags.length.toString()),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // --- Page 2: Hook ---
    if (hasHook) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            theme: baseTheme,
          ),
          build: (_) => pageShell(
            page: currentPageIndex++,
            totalPages: totalPagesCount,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                reportHeader(report.title),
                pw.SizedBox(height: 24),
                label('01 · THE HOOK'),
                pw.SizedBox(height: 18),
                scriptTitle(
                  '${time(report.hookStart)} - ${time(report.hookEnd)}',
                  size: 26,
                ),
                pw.SizedBox(height: 12),
                pw.Container(
                  width: cardContentWidth,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: const pw.BoxDecoration(
                    color: ink,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Text(
                    pdfText(report.hookText),
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
                pw.SizedBox(height: 24),
                scriptTitle('Why it works', size: 18),
                pw.SizedBox(height: 10),
                ...[
                  'Places the strongest line in the first seconds of the reel.',
                  'Gives editors a precise timing window to reuse or highlight.',
                  'Connects the hook with caption and hashtag strategy below.',
                ].map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Bullet(
                      text: item,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Page 3: Transcription ---
    if (hasTranscript) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            theme: baseTheme,
          ),
          build: (_) => pageShell(
            page: currentPageIndex++,
            totalPages: totalPagesCount,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                reportHeader(report.title),
                pw.SizedBox(height: 22),
                label('02 · TRANSCRIPTION'),
                pw.SizedBox(height: 14),
                borderedText('Original transcript', report.transcript),
                pw.SizedBox(height: 18),
                scriptTitle('Translations', size: 18),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Detected language: ${safe(report.detectedLanguage, 'unknown')}',
                  style: const pw.TextStyle(fontSize: 9, color: muted),
                ),
                pw.SizedBox(height: 8),
                borderedText('Saved translation', report.translated),
              ],
            ),
          ),
        ),
      );
    }

    // --- Page 4: Trendy Captions ---
    if (hasCaptions) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            theme: baseTheme,
          ),
          build: (_) => pageShell(
            page: currentPageIndex++,
            totalPages: totalPagesCount,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                reportHeader(report.title),
                pw.SizedBox(height: 22),
                label('03 · TRENDY CAPTIONS'),
                pw.SizedBox(height: 14),
                scriptTitle('Original caption', size: 18),
                pw.SizedBox(height: 8),
                borderedText('Fetched caption', report.originalCaption),
                pw.SizedBox(height: 16),
                scriptTitle('Selected caption', size: 18),
                pw.SizedBox(height: 8),
                borderedText(
                  'Caption currently on edit screen',
                  safe(report.currentCaption, report.trendyCaption),
                ),
                pw.SizedBox(height: 16),
                borderedText('Generated Trendy Caption', report.trendyCaption),
              ],
            ),
          ),
        ),
      );
    }

    // --- Page 5: Keywords ---
    if (hasKeywords) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            theme: baseTheme,
          ),
          build: (_) => pageShell(
            page: currentPageIndex++,
            totalPages: totalPagesCount,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                reportHeader(report.title),
                pw.SizedBox(height: 22),
                label('04 · KEYWORDS'),
                pw.SizedBox(height: 14),
                scriptTitle('Primary keywords', size: 18),
                pw.SizedBox(height: 10),
                keywordTable(),
                pw.SizedBox(height: 20),
                scriptTitle('Long-tail opportunities', size: 18),
                pw.SizedBox(height: 10),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      (report.keywords.isEmpty
                              ? [
                                  'reel ideas',
                                  'creator caption',
                                  'instagram growth',
                                ]
                              : report.keywords
                                    .take(5)
                                    .map((keyword) => '$keyword reel ideas'))
                          .map(
                            (keyword) => pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: ink, width: 0.8),
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(14),
                                ),
                              ),
                              child: pw.Text(
                                keyword,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Page 6: Hashtags ---
    if (hasHashtags) {
      doc.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            theme: baseTheme,
          ),
          build: (_) => pageShell(
            page: currentPageIndex++,
            totalPages: totalPagesCount,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                reportHeader(report.title),
                pw.SizedBox(height: 22),
                label('05 · HASHTAGS + POSTING PLAN'),
                pw.SizedBox(height: 14),
                scriptTitle('Trending hashtags', size: 18),
                pw.SizedBox(height: 10),
                hashtagWrap(report.hashtags),
                pw.SizedBox(height: 22),
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: statCard('Best time', 'Tue · 7-9pm IST'),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: statCard(
                        'CTA ideas',
                        report.hookText.isEmpty ? '3' : '5',
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 22),
                scriptTitle('CTA ideas', size: 18),
                pw.SizedBox(height: 10),
                ...[
                  'Save this post for your next reel plan.',
                  'Comment the keyword if you want the full itinerary.',
                  'Tag someone who needs this creator breakdown.',
                ].map(
                  (item) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Bullet(
                      text: item,
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                pw.Spacer(),
                pw.Divider(color: line),
                pw.Text(
                  'insta.save/pro · built from locally saved reel analysis',
                  style: const pw.TextStyle(fontSize: 8, color: muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return doc.save();
  }

  Future<void> _deletePostFromList() async {
    // 1. Stop playback and remove from UI immediately to avoid "Bad state" errors
    if (_videoController != null) {
      final oldController = _videoController;
      // Remove listener immediately so it doesn't trigger setState during cleanup
      oldController?.removeListener(_videoListener);
      setState(() {
        _videoController = null;
      });
      try {
        await oldController?.pause();
        await oldController?.dispose();
      } catch (e) {
        debugPrint("Silent error during controller disposal: $e");
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
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
        // Prevent back if currently processing
        if (_isReposting) return;
        Navigator.of(context).pop({'home': true, 'tab': targetTab});
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: _buildAppBar(targetTab),
            body: SingleChildScrollView(
              controller: _repostScrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaPreview(),
                  _buildToolbar(),
                  _buildCaptionSection(),
                  _buildCreateFromReelSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            bottomNavigationBar: _buildRepostButton(),
          ),
          if (_isReposting)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        "Preparing...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () {
              Navigator.of(context).pop();

              // if (_isReposting) return;
              // Navigator.of(context).pop({'home': true, 'tab': targetTab});
            },
          ),
          if (widget.showHomeButton)
            IconButton(
              icon: Image.asset(
                'assets/images/home.png',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                if (_isReposting) return;
                // Return to home and signal to show rating
                Navigator.of(
                  context,
                ).pop({'home': true, 'tab': targetTab, 'rating': true});
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
        GestureDetector(
          onTap: _scrollToCreateFromReel,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8, top: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -4,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
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
                      fontSize: 6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
                      color: _tagBackgroundColor.withValues(
                        alpha: _tagBackgroundOpacity,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 16,
                          color: _tagIconColor.withValues(
                            alpha: _tagIconOpacity,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "@${widget.username.replaceAll('@', '').trim()}",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _tagTextColor.withValues(
                              alpha: _tagTextOpacity,
                            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Caption:",
            style: TextStyle(
              fontSize: 15,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
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
                    decoration: InputDecoration(
                      hintText:
                          "Original by: ${widget.username.isEmpty ? '@' : widget.username}",
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
                      UIUtils.showSnackBar(
                        context,
                        "Caption copied to clipboard",
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
        ],
      ),
    );
  }

  Color _optionAccentColor(_ReelOptionAction action) {
    switch (action) {
      case _ReelOptionAction.originalCaption:
        return const Color(0xFF6C63FF);
      case _ReelOptionAction.transcribeTranslate:
        return const Color(0xFF00BCD4);
      case _ReelOptionAction.hookTiming:
        return const Color(0xFFFF9800);
      case _ReelOptionAction.trendyCaptions:
        return const Color(0xFF4CAF50);
      case _ReelOptionAction.trendyHashtags:
        return const Color(0xFF2196F3);
      case _ReelOptionAction.exportPdf:
        return const Color(0xFFE91E63);
      case _ReelOptionAction.downloadAssets:
        return const Color(0xFF9C27B0);
    }
  }

  bool _showAllReelOptions = false;
  bool _isAiBusy = false; // Guard for AI operations
  final ScrollController _repostScrollController = ScrollController();
  final GlobalKey _createFromReelKey = GlobalKey();

  void _showLoadingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      builder: (_) => Center(child: _LoadingSheet(message: message)),
    );
  }

  void _hideLoadingOverlay() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  void _scrollToCreateFromReel() {
    final ctx = _createFromReelKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  Widget _buildCreateFromReelSection() {
    return Container(
      key: _createFromReelKey,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.07),
            const Color(0xFF3B82F6).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Create from reel",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
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
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllReelOptions = !_showAllReelOptions;
                    });
                    if (_showAllReelOptions) {
                      _repostScrollController.animateTo(
                        _repostScrollController.offset + 120,
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOut,
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllReelOptions ? "Less" : "More",
                        style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        _showAllReelOptions
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: const Color(0xFF6C63FF),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (!_showAllReelOptions)
            SizedBox(
              height: 160,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _reelCreationOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return _buildReelOptionCard(_reelCreationOptions[index]);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: _reelCreationOptions.length,
                itemBuilder: (context, index) {
                  return _buildReelOptionCard(
                    _reelCreationOptions[index],
                    isVertical: true,
                  );
                },
              ),
            ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildReelOptionCard(
    _ReelCreationOption option, {
    bool isVertical = false,
  }) {
    final bool isDisabledForImage =
        !_isVideo &&
        (option.action == _ReelOptionAction.transcribeTranslate ||
            option.action == _ReelOptionAction.hookTiming);
    final bool isDisabledForVideo =
        _isVideo && (option.action == _ReelOptionAction.downloadAssets);
    final bool isDisabled = isDisabledForImage || isDisabledForVideo;

    final color = _optionAccentColor(option.action);

    return GestureDetector(
      onTap: () {
        if (isDisabled) {
          String message = "This feature is currently unavailable.";
          if (isDisabledForImage) {
            message = "This tool is only available for video reels.";
          } else if (isDisabledForVideo) {
            message = "Image(s) download is only available for image posts.";
          }
          UIUtils.showSnackBar(context, message);
          return;
        }
        _handleReelOptionTap(option);
      },
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.38 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: isVertical ? null : 125,
          margin: EdgeInsets.symmetric(vertical: isVertical ? 0 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(option.icon, size: 22, color: color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDisabled ? Colors.grey : Colors.black87,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (option.isPro && !isDisabled)
                // Positioned(
                //   top: -9,
                //   right: 7,
                //   child: Container(
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 6,
                //       vertical: 3,
                //     ),
                //     decoration: BoxDecoration(
                //       gradient: const LinearGradient(
                //         colors: [Color(0xFFFF9500), Color(0xFFFF4B2B)],
                //         begin: Alignment.centerLeft,
                //         end: Alignment.centerRight,
                //       ),
                //       color: color,
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //     child: const Text(
                //       "TRY",
                //       style: TextStyle(
                //         color: Colors.white,
                //         fontSize: 10,
                //         fontWeight: FontWeight.w800,
                //         letterSpacing: 0.3,
                //       ),
                //     ),
                //   ),
                // ),
                Positioned(
                  top: -6,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF9500), Color(0xFFFF4B2B)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
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
                      "TRY",
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
      ),
    );
  }

  Widget _buildRepostButton() {
    int targetTab = _isVideo ? 1 : 0;
    if (widget.postUrl == "device_media") {
      targetTab = 2;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              // 1. Save Button
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    if (widget.showDeleteButton) {
                      // Entry from Collection (Home Screen Tab Bar): Show Toast
                      UIUtils.showSnackBar(
                        context,
                        "Already saved to your In-App Collection",
                      );
                    } else {
                      // Entry from New Download: Show Notification
                      UIUtils.showSnackBar(
                        context,
                        "Saved to your In-App Collection",
                      );
                    }

                    if (mounted) {
                      // Check if this is from "Select Pics & Repost" flow
                      final bool isDeviceMedia =
                          widget.postUrl == "device_media";

                      Navigator.of(context).pop({
                        'home': true,
                        'tab': targetTab,
                        'rating':
                            isDeviceMedia, // Trigger rating for device media saves
                      });
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
                        Icon(
                          Icons.download_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "Save to Collection",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}

// =============================================================================
// 🔹 Bottom Sheet Widgets
// =============================================================================

// ── Loading sheet ──────────────────────────────────────────────────────────
class _LoadingSheet extends StatefulWidget {
  final String message;
  const _LoadingSheet({required this.message});

  @override
  State<_LoadingSheet> createState() => _LoadingSheetState();
}

class _LoadingSheetState extends State<_LoadingSheet>
    with TickerProviderStateMixin {
  late final AnimationController _dotController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  int _messageIndex = 0;
  late final Timer _messageTimer;

  List<String> get _loadingTips {
    final msg = widget.message.toLowerCase();
    if (msg.contains("transcrib")) {
      return [
        "Uploading your reel securely...",
        "Detecting spoken language...",
        "Converting speech to text...",
        "Cleaning up the transcript...",
        "Almost done, finalizing text...",
      ];
    } else if (msg.contains("hook")) {
      return [
        "Uploading your reel securely...",
        "Scanning video for peak moments...",
        "Detecting high-engagement sections...",
        "Pinpointing the best start time...",
        "Locking in your hook timing...",
      ];
    } else if (msg.contains("caption")) {
      return [
        "Reading your content...",
        "Matching your niche & tone...",
        "Writing attention-grabbing lines...",
        "Optimizing for engagement...",
        "Polishing the final caption...",
      ];
    } else if (msg.contains("hashtag")) {
      return [
        "Analyzing your content niche...",
        "Searching trending tags right now...",
        "Balancing reach & specificity...",
        "Filtering top-performing sets...",
        "Building your hashtag strategy...",
      ];
    }
    return [
      "Brewing social media magic...",
      "Analyzing for viral potential...",
      "Crafting your engagement strategy...",
      "Almost there, adding final touches...",
      "Preparing your results...",
    ];
  }

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _messageTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _loadingTips.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _dotController.dispose();
    _pulseController.dispose();
    _messageTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.message.split('\n');
    final subtitle = lines.length > 1 ? lines.sublist(1).join('\n') : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon ring
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFF3D3D3D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Headline
            Text(
              lines.first,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            // Rotating Message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _loadingTips[_messageIndex],
                key: ValueKey(_messageIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
            ],
            const SizedBox(height: 28),
            // Animated dots
            AnimatedBuilder(
              animation: _dotController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final delay = i / 3;
                    final t = (_dotController.value - delay).clamp(0.0, 1.0);
                    final scale =
                        (t < 0.5
                                ? Curves.easeOut.transform(t * 2)
                                : Curves.easeIn.transform((1 - t) * 2))
                            .clamp(0.4, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              const Color(0xFFCCCCCC),
                              const Color(0xFF1A1A1A),
                              scale,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Transcript sheet ───────────────────────────────────────────────────────
class _TranscriptSheet extends StatefulWidget {
  final String transcript;
  final String translated;
  final String detectedLanguage;

  const _TranscriptSheet({
    required this.transcript,
    required this.translated,
    required this.detectedLanguage,
  });

  @override
  State<_TranscriptSheet> createState() => _TranscriptSheetState();
}

class _TranscriptSheetState extends State<_TranscriptSheet> {
  String? _selectedLanguage;
  String? _currentTranslation;
  bool _isTranslating = false;
  bool _transcriptExpanded = false;

  final Map<String, TranslateLanguage> _languageCodes = {
    'English': TranslateLanguage.english,
    'Hindi': TranslateLanguage.hindi,
    'Spanish': TranslateLanguage.spanish,
    'French': TranslateLanguage.french,
    'German': TranslateLanguage.german,
    'Italian': TranslateLanguage.italian,
    'Japanese': TranslateLanguage.japanese,
    'Korean': TranslateLanguage.korean,
    'Portuguese': TranslateLanguage.portuguese,
    'Russian': TranslateLanguage.russian,
    'Chinese': TranslateLanguage.chinese,
  };

  OnDeviceTranslator? _translator;

  @override
  void initState() {
    super.initState();
    _currentTranslation = widget.translated;
  }

  @override
  void dispose() {
    _translator?.close();
    super.dispose();
  }

  TranslateLanguage _sourceLanguage() {
    return BCP47Code.fromRawValue(widget.detectedLanguage) ??
        TranslateLanguage.english;
  }

  String _languageDisplayName(String bcpCode) {
    const names = {
      'en': 'English',
      'hi': 'Hindi',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'zh': 'Chinese',
    };
    return names[bcpCode] ?? bcpCode.toUpperCase();
  }

  void _showLanguagePicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Select Language',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._languageCodes.keys.map(
                    (lang) => ListTile(
                      title: Text(
                        lang,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                        ),
                      ),
                      trailing: _selectedLanguage == lang
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF32ADE6),
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        _onLanguageChanged(lang);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copy(String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    UIUtils.showSnackBar(context, 'Copied to clipboard ✓');
  }

  void _onLanguageChanged(String? lang) async {
    if (lang == null || lang == _selectedLanguage) return;

    setState(() {
      _selectedLanguage = lang;
      _isTranslating = true;
    });

    try {
      final targetLang = _languageCodes[lang] ?? TranslateLanguage.english;
      final sourceLang = _sourceLanguage();

      _translator?.close();
      _translator = OnDeviceTranslator(
        sourceLanguage: sourceLang,
        targetLanguage: targetLang,
      );

      final modelManager = OnDeviceTranslatorModelManager();

      // Both source and target models must be on-device for translation to work.
      final sourceCode = sourceLang.bcpCode;
      final targetCode = targetLang.bcpCode;
      final sourceReady = await modelManager.isModelDownloaded(sourceCode);
      final targetReady = await modelManager.isModelDownloaded(targetCode);

      if (!sourceReady || !targetReady) {
        if (mounted) {
          UIUtils.showSnackBar(context, 'Downloading language models…');
        }
        if (!sourceReady) {
          await modelManager.downloadModel(sourceCode, isWifiRequired: false);
        }
        if (!targetReady) {
          await modelManager.downloadModel(targetCode, isWifiRequired: false);
        }
      }

      final result = await _translator!.translateText(widget.transcript);
      if (mounted && result.isNotEmpty) {
        setState(() => _currentTranslation = result);
      }
    } catch (e) {
      if (mounted) UIUtils.showSnackBar(context, 'Translation failed');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF32ADE6);
    final detectedName = _languageDisplayName(widget.detectedLanguage);
    final canCopy = _selectedLanguage != null && !_isTranslating;

    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height - mq.padding.top - 16;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Stack(
                  children: [
                    const Text(
                      'Translate',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Card
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Source section ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Detected as ',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    detectedName,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Colors.black38,
                                    size: 16,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                alignment: Alignment.topLeft,
                                child: _transcriptExpanded
                                    ? SelectionArea(
                                        child: Text(
                                          widget.transcript,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.transcript,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              height: 1.35,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _transcriptExpanded = true,
                                            ),
                                            child: const Text(
                                              'more',
                                              style: TextStyle(
                                                color: blue,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Colors.black12),
                        // ── Target section ──
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: _showLanguagePicker,
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedLanguage ?? 'Select Language',
                                        style: TextStyle(
                                          color: _selectedLanguage != null
                                              ? blue
                                              : Colors.black38,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: _selectedLanguage != null
                                            ? blue
                                            : Colors.black38,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (_selectedLanguage == null)
                                GestureDetector(
                                  onTap: _showLanguagePicker,
                                  behavior: HitTestBehavior.opaque,
                                  child: const Text(
                                    'Tap to select a language',
                                    style: TextStyle(
                                      color: Colors.black26,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else if (_isTranslating)
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: blue,
                                  ),
                                )
                              else
                                SelectionArea(
                                  child: Text(
                                    _currentTranslation ?? '',
                                    style: const TextStyle(
                                      color: blue,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Copy buttons
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _copy(widget.transcript),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.copy_rounded,
                                color: Colors.black87,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Copy Transcription',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: canCopy
                            ? () => _copy(_currentTranslation ?? '')
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.translate_rounded,
                                color: canCopy
                                    ? Colors.black87
                                    : Colors.black26,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Copy Translation',
                                style: TextStyle(
                                  color: canCopy
                                      ? Colors.black87
                                      : Colors.black26,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextBox extends StatelessWidget {
  final String text;
  final VoidCallback onCopy;
  const _TextBox({required this.text, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCopy,
            child: const Icon(
              Icons.copy_outlined,
              size: 18,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hook sheet ─────────────────────────────────────────────────────────────
class _HookSheet extends StatelessWidget {
  final String hookText;
  final double startTime;
  final double endTime;

  const _HookSheet({
    required this.hookText,
    required this.startTime,
    required this.endTime,
  });

  String _fmt(double t) {
    final m = (t ~/ 60).toString();
    final s = (t % 60).round().toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hook',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Hook step',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'The moment that grabs attention in the first seconds.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_fmt(startTime)} - ${_fmt(endTime)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Extracted hook content',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          _TextBox(
            text: hookText,
            onCopy: () {
              Clipboard.setData(ClipboardData(text: hookText));
              UIUtils.showSnackBar(context, 'Hook copied ✓');
            },
          ),
        ],
      ),
    );
  }
}

// ── Trendy Captions sheet ──────────────────────────────────────────────────
class _TrendyCaptionsSheet extends StatefulWidget {
  final String initialCaption;
  final Future<String?> Function() fetchCaption;
  final void Function(String) onUse;

  const _TrendyCaptionsSheet({
    required this.initialCaption,
    required this.fetchCaption,
    required this.onUse,
  });

  @override
  State<_TrendyCaptionsSheet> createState() => _TrendyCaptionsSheetState();
}

class _TrendyCaptionsSheetState extends State<_TrendyCaptionsSheet> {
  late String _caption;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _caption = widget.initialCaption;
  }

  Future<void> _regenerate() async {
    setState(() => _isLoading = true);
    try {
      final newCaption = await widget.fetchCaption();
      if (mounted) {
        setState(() {
          if (newCaption != null) _caption = newCaption;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UIUtils.showSnackBar(context, 'Regeneration failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Trendy Caption',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Trending captions with 5 hashtags, matched to your reel.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          const Text(
            'Trendy caption',
            style: TextStyle(fontSize: 17, color: Colors.black),
          ),
          const SizedBox(height: 10),
          // Caption box with action icons
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _isLoading
                    ? const SizedBox(
                        height: 60,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Text(
                        _caption,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ActionIcon(
                      icon: Icons.refresh_rounded,
                      enabled: !_isLoading,
                      onTap: _regenerate,
                    ),
                    const SizedBox(width: 8),
                    _ActionIcon(
                      icon: Icons.copy_outlined,
                      enabled: !_isLoading,
                      onTap: () {
                        widget.onUse(_caption);
                        UIUtils.showSnackBar(context, 'Caption applied ✓');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? Colors.black : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Trendy Hashtags sheet ──────────────────────────────────────────────────
class _TrendyHashtagsSheet extends StatefulWidget {
  final List<String> trendyPicks;

  const _TrendyHashtagsSheet({required this.trendyPicks});

  @override
  State<_TrendyHashtagsSheet> createState() => _TrendyHashtagsSheetState();
}

class _TrendyHashtagsSheetState extends State<_TrendyHashtagsSheet> {
  late Set<String> _selected;
  final List<String> _userAdded = [];
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.trendyPicks);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _addHashtag() {
    final raw = _inputController.text.trim();
    if (raw.isEmpty) return;
    final tag = raw.startsWith('#') ? raw : '#$raw';
    setState(() => _userAdded.add(tag));
    _inputController.clear();
  }

  List<String> get _finalSet => [..._userAdded, ..._selected];

  void _copyFinalSet(BuildContext ctx) {
    final text = _finalSet.join(' ');
    Clipboard.setData(ClipboardData(text: text));
    UIUtils.showSnackBar(ctx, 'Hashtags copied ✓');
  }

  @override
  Widget build(BuildContext context) {
    final finalSet = _finalSet;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (sheetContext, sc) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Hashtags',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Add your own + pick from trending. Combined set is ready to copy.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // "Add your own" section
                const Text(
                  'Add your own',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: '#travelreel, sunset, maldives…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade400,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                        ),
                        onSubmitted: (_) => _addHashtag(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _addHashtag,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '+ Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // "Trendy picks" section
                Row(
                  children: [
                    const Text(
                      'Trendy picks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'tap to toggle',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.trendyPicks.map((tag) {
                    final isSelected = _selected.contains(tag);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(tag);
                          } else {
                            _selected.add(tag);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          border: Border.all(color: Colors.black, width: 1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Final set box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final set - ${finalSet.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        finalSet.join(' '),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _ActionIcon(
                            icon: Icons.copy_outlined,
                            enabled: finalSet.isNotEmpty,
                            onTap: () => _copyFinalSet(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================

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
      if (_selectedTab == 0) {
        iconColor = c;
      } else if (_selectedTab == 1) {
        textColor = c;
      } else {
        bgColor = c;
      }
    });
    _notifyParent();
  }

  void _updateOpacity(double val) {
    setState(() {
      if (_selectedTab == 0) {
        iconOp = val;
      } else if (_selectedTab == 1) {
        textOp = val;
      } else {
        bgOp = val;
      }
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
        color: bgColor.withValues(alpha: bgOp),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 16,
            color: iconColor.withValues(alpha: iconOp),
          ),
          const SizedBox(width: 4),
          Text(
            widget.username,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: textColor.withValues(alpha: textOp),
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
    bool isSelected = color.toARGB32() == currentColor.toARGB32();
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

// ── Export PDF Sheet ───────────────────────────────────────────────────────
class _ExportPdfSheet extends StatelessWidget {
  final String thumbnailPath;
  final String thumbnailUrl;
  final Future<void> Function(String? shareTarget) onDownload;

  const _ExportPdfSheet({
    required this.thumbnailPath,
    required this.thumbnailUrl,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reel Report',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text(
            'Export as PDF',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bundles caption, transcription, hook, trendy captions & hashtags into a shareable PDF.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // Preview card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F0E8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0D8C8)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: _buildThumbnail(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Reel Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'cover thumbnail',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 10),
                Text(
                  'Insights · cover · transcription · hook · caption · hashtags',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Preview & Download button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await onDownload(null);
              },
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'Preview & Download PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Share anywhere — Instagram, WhatsApp, Drive, email.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),

          // Share buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareButton(
                iconWidget: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                  size: 22,
                ),
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () async {
                  Navigator.pop(context);
                  await onDownload('whatsapp');
                },
              ),
              _ShareButton(
                iconWidget: const FaIcon(
                  FontAwesomeIcons.instagram,
                  color: Color(0xFFE1306C),
                  size: 22,
                ),
                label: 'Instagram',
                color: const Color(0xFFE1306C),
                onTap: () async {
                  Navigator.pop(context);
                  await onDownload('instagram');
                },
              ),
              _ShareButton(
                iconWidget: const FaIcon(
                  FontAwesomeIcons.googleDrive,
                  color: Color(0xFF4285F4),
                  size: 22,
                ),
                label: 'Drive',
                color: const Color(0xFF4285F4),
                onTap: () async {
                  Navigator.pop(context);
                  await onDownload('drive');
                },
              ),
              _ShareButton(
                iconWidget: const Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFFEA4335),
                  size: 22,
                ),
                label: 'Mail',
                color: const Color(0xFFEA4335),
                onTap: () async {
                  Navigator.pop(context);
                  await onDownload('mail');
                },
              ),
              _ShareButton(
                iconWidget: const Icon(
                  Icons.more_horiz_rounded,
                  color: Colors.grey,
                  size: 22,
                ),
                label: 'More',
                color: Colors.grey,
                onTap: () async {
                  Navigator.pop(context);
                  await onDownload('more');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    if (thumbnailPath.isNotEmpty && File(thumbnailPath).existsSync()) {
      final ext = thumbnailPath.toLowerCase();
      if (!ext.endsWith('.mp4') && !ext.endsWith('.mov')) {
        return Image.file(File(thumbnailPath), fit: BoxFit.cover);
      }
    }
    if (thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: const Color(0xFFE0D8C8)),
        errorWidget: (_, __, ___) => _placeholderThumbnail(),
      );
    }
    return _placeholderThumbnail();
  }

  Widget _placeholderThumbnail() {
    return Container(
      color: const Color(0xFFE0D8C8),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 36, color: Colors.white),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ShareButton({
    required this.iconWidget,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withAlpha(60)),
            ),
            child: Center(child: iconWidget),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}

class _ReelReportPreviewScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String filename;
  final String title;
  final String subtitle;

  const _ReelReportPreviewScreen({
    required this.pdfBytes,
    required this.filename,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_ReelReportPreviewScreen> createState() =>
      _ReelReportPreviewScreenState();
}

class _ReelReportPreviewScreenState extends State<_ReelReportPreviewScreen> {
  static const MethodChannel _mediaStoreChannel = MethodChannel('media_store');

  Future<void> _downloadPdf() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.filename}');
      await file.writeAsBytes(widget.pdfBytes);
      final result = await _mediaStoreChannel.invokeMethod<String>(
        'saveMedia',
        {'path': file.path, 'mediaType': 'pdf'},
      );
      if (mounted) {
        UIUtils.showSnackBar(
          context,
          result != null ? 'PDF saved to Downloads' : 'Failed to save PDF',
        );
      }
    } catch (e) {
      if (mounted) UIUtils.showSnackBar(context, 'Failed to save PDF: $e');
    }
  }

  Future<void> _sharePdf() {
    return Printing.sharePdf(bytes: widget.pdfBytes, filename: widget.filename);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PdfHeaderButton(
                    icon: Icons.download_rounded,
                    onTap: _downloadPdf,
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sharePdf,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Share',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (_) async => widget.pdfBytes,
                pdfFileName: widget.filename,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: false,
                allowSharing: false,
                loadingWidget: const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfHeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PdfHeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black, width: 1),
        ),
        child: Icon(icon, size: 19, color: Colors.black),
      ),
    );
  }
}

class _DownloadAssetsSheet extends StatefulWidget {
  final List<String> allMediaPaths;
  final String username;
  final Function(List<String>) onDownload;

  const _DownloadAssetsSheet({
    required this.allMediaPaths,
    required this.username,
    required this.onDownload,
  });

  @override
  State<_DownloadAssetsSheet> createState() => _DownloadAssetsSheetState();
}

class _DownloadAssetsSheetState extends State<_DownloadAssetsSheet> {
  late Set<String> _selectedPaths;

  @override
  void initState() {
    super.initState();
    _selectedPaths = widget.allMediaPaths.toSet();
  }

  void _toggle(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Download Images',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Subtitle
                    const Text(
                      'Download reel images',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pulled from the reel link you pasted · ${widget.allMediaPaths.length} frames. Download them as one PDF or save each frame as an image — share anywhere.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    // Selected count + Clear all
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Selected · ${_selectedPaths.length} / ${widget.allMediaPaths.length}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedPaths.isEmpty) {
                                _selectedPaths = widget.allMediaPaths.toSet();
                              } else {
                                _selectedPaths.clear();
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              _selectedPaths.isEmpty
                                  ? 'Select all'
                                  : 'Clear all',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.allMediaPaths.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: widget.allMediaPaths.length < 3 ? 2 : 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (context, index) {
                        final path = widget.allMediaPaths[index];
                        final isSelected = _selectedPaths.contains(path);
                        return GestureDetector(
                          onTap: () => _toggle(path),
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                ),
                              ),
                              // Index
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              // Checkmark
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? null
                                        : Border.all(color: Colors.black12),
                                  ),
                                  child: Icon(
                                    Icons.check,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              // Download button
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 12),
                child: GestureDetector(
                  onTap: _selectedPaths.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          widget.onDownload(_selectedPaths.toList());
                        },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: _selectedPaths.isEmpty
                          ? Colors.grey
                          : const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Download ${_selectedPaths.length} images / PDF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
