import 'dart:io';
import 'package:flutter/material.dart';
import 'package:insta_save/utils/navigation_helper.dart';
import 'package:video_player/video_player.dart';
import 'repost_screen.dart';

class PreviewScreen extends StatefulWidget {
  final List<String> mediaPaths;
  final String username;
  final String caption;
  final String postUrl;

  const PreviewScreen({
    super.key,
    required this.mediaPaths,
    required this.username,
    required this.caption,
    required this.postUrl,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initVideoControllers();
  }

  Future<void> _initVideoControllers() async {
    for (int i = 0; i < widget.mediaPaths.length; i++) {
      final path = widget.mediaPaths[i];
      if (path.toLowerCase().endsWith(".mp4")) {
        final controller = VideoPlayerController.file(File(path));
        await controller.initialize();
        controller.setLooping(true);
        _videoControllers[i] = controller;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Pause all other videos
    for (final entry in _videoControllers.entries) {
      if (entry.key != index) entry.value.pause();
    }

    // Play current video if available
    if (_videoControllers.containsKey(index)) {
      _videoControllers[index]!.play();
    }

    setState(() => _currentPage = index);
  }

  void _goToRepostScreen() {
    final selectedPath = widget.mediaPaths[_currentPage];
    Navigator.of(context).push(createSlideRoute(RepostScreen(
      imageUrl: selectedPath,
      username: widget.username,
      initialCaption: widget.caption,
      postUrl: widget.postUrl,
      localImagePath: selectedPath,
      showDeleteButton: false,
      showHomeButton: true,
    ), direction: SlideFrom.right));

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔹 Image / Video Preview Carousel
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaPaths.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final path = widget.mediaPaths[index];
                final isVideo = path.toLowerCase().endsWith(".mp4");

                if (isVideo) {
                  final controller = _videoControllers[index];
                  if (controller == null || !controller.value.isInitialized) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      _PlayPauseOverlay(controller: controller),
                    ],
                  );
                } else {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.error,
                        color: Colors.red,
                      ),
                    ),
                  );
                }
              },
            ),
          ),

          // 🔹 Page indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.mediaPaths.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: _currentPage == index ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index ? Colors.black : Colors.grey,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          // 🔹 Next button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _goToRepostScreen,
              child: const Text(
                "Next",
                style: TextStyle(fontSize: 16),
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
  bool _showPlayIcon = false;

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
        _showPlayIcon = true;
      } else {
        widget.controller.play();
        _showPlayIcon = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_showPlayIcon || !widget.controller.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 48,
              ),
            ),
        ],
      ),
    );
  }
}
