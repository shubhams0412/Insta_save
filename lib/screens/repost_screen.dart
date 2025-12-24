import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import 'package:insta_save/screens/home_screen.dart';

class RepostScreen extends StatefulWidget {
  final String imageUrl;
  final String username;
  final String initialCaption;
  final String postUrl;
  final String localImagePath;
  final bool showDeleteButton;
  final bool showHomeButton;

  const RepostScreen({
    super.key,
    required this.imageUrl,
    required this.username,
    required this.initialCaption,
    required this.postUrl,
    required this.localImagePath,
    this.showDeleteButton = false,
    this.showHomeButton = false,
  });

  @override
  State<RepostScreen> createState() => _RepostScreenState();
}

class _RepostScreenState extends State<RepostScreen> {
  final GlobalKey _imageKey = GlobalKey();
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

  @override
  void initState() {
    super.initState();
    _captionController = TextEditingController(text: widget.initialCaption);
    _checkIfVideo();
    _loadImageAspectRatio();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // --- LOGIC: Media Initialization ---

  void _checkIfVideo() async {
    if (widget.localImagePath.toLowerCase().endsWith('.mp4')) {
      _isVideo = true;
      _videoController = VideoPlayerController.file(File(widget.localImagePath));

      try {
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _imageAspectRatio = _videoController!.value.aspectRatio;
            _isLoadingImage = false;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      } catch (e) {
        debugPrint("Error initializing video: $e");
      }
    }
  }

  Future<void> _loadImageAspectRatio() async {
    if (_isVideo) return;
    final file = File(widget.localImagePath);
    if (!file.existsSync()) {
      setState(() => _isLoadingImage = false);
      return;
    }
    final Image image = Image.file(file);
    final ImageStream stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (mounted) {
        setState(() {
          _imageAspectRatio = info.image.width / info.image.height;
          _isLoadingImage = false;
        });
      }
    }, onError: (_, __) {
      if (mounted) setState(() => _isLoadingImage = false);
    }));
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
    final outputPath = '${tempDir.path}/repost_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final cleanName = widget.username.replaceAll('@', '').trim();

    String toHex(Color c) => c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    final textColorHex = toHex(_tagTextColor);
    final bgColorHex = toHex(_tagBackgroundColor);

    // Position logic (Mapping alignment to FFmpeg coordinates)
    String xPos = "20";
    String yPos = "20";
    if (_tagAlignment == Alignment.bottomLeft) { xPos = "20"; yPos = "h-th-40"; }
    else if (_tagAlignment == Alignment.bottomRight) { xPos = "w-tw-20"; yPos = "h-th-40"; }
    else if (_tagAlignment == Alignment.topRight) { xPos = "w-tw-20"; yPos = "40"; }
    else { xPos = "20"; yPos = "40"; }

    // FFmpeg command with explicit fontfile and box background
    final command = "-y -i \"${widget.localImagePath}\" " +
        "-vf \"drawtext=fontfile='$fontPath':text='@$cleanName':x=$xPos:y=$yPos:fontsize=40:fontcolor=0x$textColorHex:box=1:boxcolor=0x$bgColorHex@$_tagBackgroundOpacity:boxborderw=12\" " +
        "-c:v libx264 -preset ultrafast -c:a copy \"$outputPath\"";

    debugPrint("Starting FFmpeg: $command");

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      debugPrint("FFmpeg Success");
      return File(outputPath);
    } else {
      final logs = await session.getAllLogsAsString();
      debugPrint("FFmpeg Failed: $logs");
      throw Exception("FFmpeg failed to generate video overlay.");
    }
  }

  // --- LOGIC: Handle Repost (Share Video Only) ---

  Future<void> _handleRepostAction() async {
    if (_isReposting) return;
    setState(() => _isReposting = true);

    try {
      String pathToSend = widget.localImagePath;

      if (_isVideo && _isTagVisible) {
        final renderedFile = await renderVideoWithCustomStyle();
        pathToSend = renderedFile.path;
      }

      // Save to MediaStore
      final String? uriString = await _mediaStoreChannel.invokeMethod<String>(
          'saveVideo',
          {'path': pathToSend}
      );

      if (uriString != null) {
        // ✅ This now matches the name in MainActivity
        await _instaChannel.invokeMethod('repostToInstagram', {
          'uri': uriString,
        });
      }

    } on PlatformException catch (e) {
      debugPrint("Native Error: ${e.message}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Platform Error: ${e.message}")),
      );
    } catch (e) {
      debugPrint("General Error: $e");
    } finally {
      if (mounted) setState(() => _isReposting = false); // ✅ Always stops spinner
    }
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

  Future<void> _deletePostFromList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];
      savedData.removeWhere((item) {
        final Map<String, dynamic> decoded = jsonDecode(item);
        return decoded['localPath'] == widget.localImagePath;
      });
      await prefs.setStringList('savedPosts', savedData);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen(initialTabIndex: 0)),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error deleting: $e");
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
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
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(widget.username, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      centerTitle: true,
      actions: [
        if (widget.showDeleteButton)
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deletePostFromList,
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
          if (_isVideo && _videoController != null && _videoController!.value.isInitialized)
            VideoPlayer(_videoController!)
          else
            Image.file(File(widget.localImagePath), fit: BoxFit.cover),
          if (_isTagVisible)
            Align(
              alignment: _tagAlignment,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tagBackgroundColor.withOpacity(_tagBackgroundOpacity),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 16, color: _tagIconColor.withOpacity(_tagIconOpacity)),
                      const SizedBox(width: 4),
                      Text(widget.username, style: TextStyle(fontWeight: FontWeight.w600, color: _tagTextColor.withOpacity(_tagTextOpacity))),
                    ],
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
                    Text("Preparing video...", style: TextStyle(color: Colors.white))
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
      child: Row(
        children: [
          ToggleButtons(
            isSelected: _alignmentSelections,
            onPressed: (int index) {
              setState(() {
                for (int i = 0; i < _alignmentSelections.length; i++) _alignmentSelections[i] = (i == index);
                if (index == 0) _tagAlignment = Alignment.bottomLeft;
                if (index == 1) _tagAlignment = Alignment.bottomRight;
                if (index == 2) _tagAlignment = Alignment.topLeft;
                if (index == 3) _tagAlignment = Alignment.topRight;
              });
            },
            borderRadius: BorderRadius.circular(8),
            children: const [Text('L'), Text('R'), Text('TL'), Text('TR')],
          ),
          const Spacer(),
          IconButton(
            icon: Icon(_isTagVisible ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _isTagVisible = !_isTagVisible),
          ),
          IconButton(icon: const Icon(Icons.palette_outlined), onPressed: _openTagEditor),
        ],
      ),
    );
  }

  Widget _buildCaptionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: _captionController,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: "Caption",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRepostButton() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: _isReposting ? null : _handleRepostAction,
        child: _isReposting
            ? const Text("Processing...")
            : const Text("Repost to Instagram", style: TextStyle(color: Colors.white)),
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

  Color get currentColor => _selectedTab == 0 ? iconColor : (_selectedTab == 1 ? textColor : bgColor);
  double get currentOp => _selectedTab == 0 ? iconOp : (_selectedTab == 1 ? textOp : bgOp);

  void _updateColor(Color c) {
    setState(() {
      if (_selectedTab == 0) iconColor = c;
      else if (_selectedTab == 1) textColor = c;
      else bgColor = c;
    });
    _notifyParent();
  }

  void _updateOpacity(double val) {
    setState(() {
      if (_selectedTab == 0) iconOp = val;
      else if (_selectedTab == 1) textOp = val;
      else bgOp = val;
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
              IconButton(icon: const Icon(Icons.check, size: 28), onPressed: () => Navigator.pop(context)),
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
                        actions: [TextButton(child: const Text('Done'), onPressed: () => Navigator.of(ctx).pop())],
                      ),
                    );
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red])),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Opacity", style: TextStyle(fontWeight: FontWeight.bold)),
              Text("${(currentOp * 100).toInt()}%"),
            ],
          ),
          Slider(value: currentOp, min: 0.0, max: 1.0, activeColor: Colors.black, onChanged: _updateOpacity),
        ],
      ),
    );
  }

  Widget _buildMiniPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor.withOpacity(bgOp), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 16, color: iconColor.withOpacity(iconOp)),
          const SizedBox(width: 4),
          Text(widget.username, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor.withOpacity(textOp))),
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
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? Colors.black : Colors.grey)),
          Container(height: 2, width: 40, color: isSelected ? Colors.black : Colors.transparent),
        ],
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    bool isSelected = color.value == currentColor.value;
    return GestureDetector(
      onTap: () => _updateColor(color),
      child: Container(
        width: 32, height: 32, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.black, width: 2) : Border.all(color: Colors.grey.shade300)),
      ),
    );
  }
}