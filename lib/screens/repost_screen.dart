import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'home.dart';

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
  final List<bool> _alignmentSelections = [true, false, false, false];

  // --- Tag Styling State ---
  Alignment _tagAlignment = Alignment.bottomLeft;
  bool _isTagVisible = true;
  bool _isTagBlocked = false;
  bool _isReposting = false;
  double _imageAspectRatio = 1.0;
  bool _isLoadingImage = true;

  // Tag Styling Variables
  Color _tagBackgroundColor = Colors.white;
  double _tagBackgroundOpacity = 1.0;

  Color _tagTextColor = Colors.black;
  double _tagTextOpacity = 1.0;

  Color _tagIconColor = Colors.black;
  double _tagIconOpacity = 1.0;

  // Quick Dark Mode Toggle
  bool _isDarkSelected = false;

  VideoPlayerController? _videoController;
  bool _isVideo = false;

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

  // --- FIXED: Tag Editor Logic ---
  void _openTagEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Local state for the tabs (0=Icon, 1=Text, 2=Background)
        // We declare it here, but we update it inside StatefulBuilder
        int selectedTab = 0;

        return StatefulBuilder(
          builder: (context, setModalState) {

            // Helper to get current color based on selected tab
            Color getCurrentColor() {
              if (selectedTab == 0) return _tagIconColor;
              if (selectedTab == 1) return _tagTextColor;
              return _tagBackgroundColor;
            }

            // Helper to get current opacity based on selected tab
            double getCurrentOpacity() {
              if (selectedTab == 0) return _tagIconOpacity;
              if (selectedTab == 1) return _tagTextOpacity;
              return _tagBackgroundOpacity;
            }

            // Update Color Logic
            void updateColor(Color color) {
              // Update the parent widget state (the actual screen)
              setState(() {
                if (selectedTab == 0) _tagIconColor = color;
                else if (selectedTab == 1) _tagTextColor = color;
                else _tagBackgroundColor = color;
              });
              // Update the modal state (to reflect changes in sliders/circles)
              setModalState(() {});
            }

            // Update Opacity Logic
            void updateOpacity(double val) {
              setState(() {
                if (selectedTab == 0) _tagIconOpacity = val;
                else if (selectedTab == 1) _tagTextOpacity = val;
                else _tagBackgroundOpacity = val;
              });
              setModalState(() {});
            }

            // Change Tab Logic
            void changeTab(int index) {
              setModalState(() {
                selectedTab = index;
              });
            }

            return Container(
              height: 400,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header: Preview & Done Button ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mini Preview
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _tagBackgroundColor.withOpacity(_tagBackgroundOpacity),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 16,
                                color: _tagIconColor.withOpacity(_tagIconOpacity)
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.username,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: _tagTextColor.withOpacity(_tagTextOpacity),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Done Button
                      IconButton(
                        icon: const Icon(Icons.check, size: 28, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // --- Tabs (Icon, Text, Background) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabItem("Icon", 0, selectedTab, changeTab),
                      _buildTabItem("Text", 1, selectedTab, changeTab),
                      _buildTabItem("Background", 2, selectedTab, changeTab),
                    ],
                  ),
                  const Divider(height: 30),

                  // --- Color Picker Row ---
                  const Text("Color", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Presets
                        _buildColorCircle(const Color(0xFF8B0000), getCurrentColor(), updateColor), // Dark Red
                        _buildColorCircle(const Color(0xFFF44336), getCurrentColor(), updateColor), // Red
                        _buildColorCircle(const Color(0xFFE91E63), getCurrentColor(), updateColor), // Pink
                        _buildColorCircle(const Color(0xFFAFB42B), getCurrentColor(), updateColor), // Olive
                        _buildColorCircle(const Color(0xFFFF5722), getCurrentColor(), updateColor), // Deep Orange
                        _buildColorCircle(const Color(0xFF90CAF9), getCurrentColor(), updateColor), // Light Blue
                        _buildColorCircle(const Color(0xFF607D8B), getCurrentColor(), updateColor), // Blue Grey
                        _buildColorCircle(const Color(0xFFFFC107), getCurrentColor(), updateColor), // Amber
                        _buildColorCircle(const Color(0xFFD81B60), getCurrentColor(), updateColor), // Magenta
                        _buildColorCircle(Colors.black, getCurrentColor(), updateColor),
                        _buildColorCircle(Colors.white, getCurrentColor(), updateColor),

                        // Custom Picker
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Pick a color'),
                                content: SingleChildScrollView(
                                  child: ColorPicker(
                                    pickerColor: getCurrentColor(),
                                    onColorChanged: updateColor,
                                    enableAlpha: false,
                                    displayThumbColor: true,
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
                            margin: const EdgeInsets.only(right: 12),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: SweepGradient(
                                colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Opacity Slider ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Opacity", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("${(getCurrentOpacity() * 100).toInt()}%", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Slider(
                    value: getCurrentOpacity(),
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.black,
                    inactiveColor: Colors.grey.shade300,
                    onChanged: updateOpacity,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ✅ Fixed Helper for Tabs: Now accepts a callback
  Widget _buildTabItem(String title, int index, int selectedIndex, Function(int) onTabSelected) {
    bool isSelected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque, // Ensures tap is caught easily
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black : Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(height: 2, width: 40, color: Colors.black)
          else
            const SizedBox(height: 2), // Keep layout stable
        ],
      ),
    );
  }

  // Helper for Color Circles
  Widget _buildColorCircle(Color color, Color currentColor, Function(Color) onTap) {
    bool isSelected = color.value == currentColor.value;
    return GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 2) : Border.all(color: Colors.grey.shade300),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2)],
        ),
      ),
    );
  }

  // --- Standard Logic (Same as before) ---

  void _checkIfVideo() async {
    if (widget.localImagePath.toLowerCase().endsWith('.mp4')) {
      _isVideo = true;
      _videoController = VideoPlayerController.file(File(widget.localImagePath));
      await _videoController!.initialize();
      final videoWidth = _videoController!.value.size.width;
      final videoHeight = _videoController!.value.size.height;
      setState(() {
        _imageAspectRatio = videoWidth / videoHeight;
        _isLoadingImage = false;
      });
      _videoController!.setLooping(true);
      _videoController!.play();
    }
  }

  void _onSharePressed() => Share.share(_captionController.text);

  void _onDeletePressed() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Delete Post"),
          content: const Text("Are you sure you want to remove this post?"),
          actions: [
            TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(context)),
            TextButton(child: const Text("Delete", style: TextStyle(color: Colors.red)), onPressed: () { Navigator.pop(context); _deletePostFromList(); }),
          ],
        );
      },
    );
  }

  Future<void> _deletePostFromList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> savedData = prefs.getStringList('savedPosts') ?? [];
      final int initialLength = savedData.length;
      savedData.removeWhere((item) {
        final Map<String, dynamic> decoded = jsonDecode(item);
        return decoded['localPath'] == widget.localImagePath;
      });
      if (savedData.length < initialLength) {
        await prefs.setStringList('savedPosts', savedData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post removed')));
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const HomeScreen()), (route) => false);
        }
      }
    } catch (e) { print("Error deleting: $e"); }
  }

  void _onCopyPressed() {
    Clipboard.setData(ClipboardData(text: _captionController.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caption copied!')));
  }

  Future<File?> _saveEditedPost() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      RenderRepaintBoundary boundary = _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/repost_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) { return null; }
  }

  Future<void> _loadImageAspectRatio() async {
    if (widget.localImagePath.toLowerCase().endsWith('.mp4')) return;
    final Image image = Image.file(File(widget.localImagePath));
    final ImageStream stream = image.image.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      setState(() { _imageAspectRatio = info.image.width / info.image.height; _isLoadingImage = false; });
    }, onError: (_, __) { if (mounted) setState(() { _imageAspectRatio = 1.0; _isLoadingImage = false; }); }));
  }

  Future<void> _repostEditedImage() async {
    setState(() => _isReposting = true);
    try {
      File? fileToShare;
      if (_isVideo) {
        fileToShare = File(widget.localImagePath);
        await Share.shareXFiles([XFile(fileToShare.path)], text: "Shared via InstaSave 🎬\n\n@${widget.username}\n${_captionController.text}\n\n${widget.postUrl}");
      } else {
        final file = await _saveEditedPost();
        if (file != null) {
          fileToShare = file;
          await Share.shareXFiles([XFile(fileToShare.path)], text: "Shared via InstaSave 📸\n\n@${widget.username}\n${_captionController.text}\n\n${widget.postUrl}");
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isReposting = false);
    }
  }

  Future<void> _openInstagramProfile(String username) async {
    final cleanName = username.replaceAll('@', '').trim();
    final Uri url = Uri.parse("https://www.instagram.com/$cleanName/");
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw Exception('Could not launch');
    } catch (e) { await launchUrl(url, mode: LaunchMode.platformDefault); }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,

        // ✅ 1. INCREASE WIDTH TO FIT 2 ICONS
        leadingWidth: 100,

        // ✅ 2. ROW FOR BACK + HOME ICONS
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            // ✅ Home Icon
            if (widget.showHomeButton)  IconButton(
              icon: const Icon(Icons.home_outlined, color: Colors.black),
              onPressed: () {
                // Navigate to Home and clear all previous routes
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                      (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
        title: Text(widget.username, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.send_outlined, color: Colors.black), onPressed: _onSharePressed),
          if (widget.showDeleteButton) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: _onDeletePressed),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _isLoadingImage
                ? AspectRatio(aspectRatio: 1, child: Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())))
                : AspectRatio(
              aspectRatio: _imageAspectRatio,
              child: RepaintBoundary(
                key: _imageKey,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _isVideo
                        ? GestureDetector(
                      onTap: () => setState(() => _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play()),
                      child: Stack(alignment: Alignment.center, children: [
                        AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)),
                        if (!_videoController!.value.isPlaying) Container(color: Colors.black26, child: const Icon(Icons.play_arrow, color: Colors.white, size: 60)),
                      ]),
                    )
                        : Image.file(File(widget.localImagePath), fit: BoxFit.cover),

                    // ✅ CUSTOMIZABLE TAG OVERLAY
                    Visibility(
                      visible: _isTagVisible,
                      child: Align(
                        alignment: _tagAlignment,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: GestureDetector(
                            // Open URL on tap, but we could also allow editing here
                            onTap: () => _openInstagramProfile(widget.username),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _tagBackgroundColor.withOpacity(_tagBackgroundOpacity),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_border, size: 16, color: _tagIconColor.withOpacity(_tagIconOpacity)),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.username,
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
                    ),
                  ],
                ),
              ),
            ),

            // SETTINGS ROW
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ToggleButtons(
                      isSelected: _alignmentSelections,
                      onPressed: (int index) {
                        setState(() {
                          for (int i = 0; i < _alignmentSelections.length; i++) _alignmentSelections[i] = (i == index);
                          switch (index) {
                            case 0: _tagAlignment = Alignment.bottomLeft; break;
                            case 1: _tagAlignment = Alignment.bottomRight; break;
                            case 2: _tagAlignment = Alignment.topLeft; break;
                            case 3: _tagAlignment = Alignment.topRight; break;
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Colors.black,
                      color: Colors.grey.shade600,
                      fillColor: Colors.grey.shade200,
                      constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                      children: const [Text('L'), Text('R'), Text('TL'), Text('TR')],
                    ),
                    const SizedBox(width: 12),

                    // Toggle Visibility
                    _buildSettingsIcon(Icons.block, isSelected: _isTagBlocked, onTap: () {
                      setState(() {
                        _isTagBlocked = !_isTagBlocked;
                        _isTagVisible = !_isTagVisible;
                      });
                    }),
                    const SizedBox(width: 8),

                    // Quick Dark Mode Toggle
                    FilterChip(
                      label: const Text('Dark'),
                      selected: _isDarkSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          _isDarkSelected = selected;
                          if(selected) {
                            _tagBackgroundColor = Colors.black;
                            _tagTextColor = Colors.white;
                            _tagIconColor = Colors.white;
                          } else {
                            _tagBackgroundColor = Colors.white;
                            _tagTextColor = Colors.black;
                            _tagIconColor = Colors.black;
                          }
                        });
                      },
                      avatar: CircleAvatar(backgroundColor: Colors.white, child: Container(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade400, width: 1.5)))),
                      backgroundColor: Colors.transparent,
                      shape: const StadiumBorder(side: BorderSide(color: Colors.grey)),
                      selectedColor: Colors.grey.shade200,
                    ),
                    const SizedBox(width: 8),

                    // ✅ RAINBOW CIRCLE -> OPENS TAG EDITOR
                    GestureDetector(
                      onTap: _openTagEditor,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [Colors.red, Colors.yellow, Colors.green, Colors.blue, Colors.purple, Colors.red],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 12, height: 12,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // CAPTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Caption:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _captionController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: TextButton.icon(icon: const Icon(Icons.copy, size: 16), label: const Text('Copy'), onPressed: _onCopyPressed),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: _isReposting ? const SizedBox.shrink() : const Icon(Icons.repeat),
          label: _isReposting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Repost', style: TextStyle(fontSize: 16)),
          onPressed: _repostEditedImage,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }

  Widget _buildSettingsIcon(IconData icon, {required VoidCallback onTap, bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.grey.shade700 : Colors.transparent, border: Border.all(color: Colors.grey.shade400, width: 1.5)),
          child: Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade700, size: 18),
        ),
      ),
    );
  }
}