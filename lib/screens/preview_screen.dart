import 'dart:async'; // ✅ Import this for StreamSubscription
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:insta_save/screens/home.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/services/download_manager.dart';
import 'package:insta_save/widgets/status_dialog.dart';
import 'repost_screen.dart';

class PreviewScreen extends StatefulWidget {
  final List<Map<String, String>> mediaItems;
  final String username;
  final String caption;
  final String postUrl;

  const PreviewScreen({
    super.key,
    required this.mediaItems,
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
  String? _tempPath;

  // ✅ 1. Add Subscription & Dialog State variables
  StreamSubscription? _downloadSubscription;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTempDir();

    // ✅ 2. Listen for completion events to Auto-Close the dialog
    _downloadSubscription = DownloadManager.instance.onTaskCompleted.listen((_) {
      // Check if the specific batch for this post is totally done
      // (We add a small delay to ensure the Manager has updated its list)
      Future.delayed(const Duration(milliseconds: 500), () {
        bool isStillDownloading = DownloadManager.instance.isBatchDownloading(widget.postUrl);

        if (!isStillDownloading && _isDialogOpen && mounted) {
          Navigator.of(context).pop(); // 💥 Auto-Pop the Loader
        }
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!DownloadManager.instance.isBatchDownloading(widget.postUrl)) {

        DownloadManager.instance.startBatchDownloads(
          widget.mediaItems,
          widget.username,
          widget.caption,
          widget.postUrl,
        );

        // ✅ 3. Mark dialog as Open
        _isDialogOpen = true;

        _isDialogOpen = true;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            // ✅ WRAP DIALOG IN ANIMATED BUILDER TO UPDATE PROGRESS LIVE
            return AnimatedBuilder(
              animation: DownloadManager.instance,
              builder: (context, _) {
                // Get real-time progress (0.0 to 1.0)
                final double progress = DownloadManager.instance.getBatchProgress(widget.postUrl);

                return StatusDialog(
                  type: DialogType.processing,
                  progress: progress, // ✅ Pass the live progress here
                  onButtonClick: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      createSlideRoute(const HomeScreen(), direction: SlideFrom.left),
                          (route) => false,
                    );
                  },
                );
              },
            );
          },
        ).then((_) {
          _isDialogOpen = false;
        });
      }
    });
  }

  Future<void> _initTempDir() async {
    final dir = await getTemporaryDirectory();
    if(mounted) {
      setState(() {
        _tempPath = dir.path;
      });
    }
  }

  @override
  void dispose() {
    // ✅ 5. Cancel subscription to prevent memory leaks
    _downloadSubscription?.cancel();

    _pageController.dispose();
    super.dispose();
  }

  String _getExpectedFilePath(String url, int index) {
    if (_tempPath == null) return "";
    final isVideo = url.contains('.mp4');
    final fileName = "insta_${url.hashCode}_$index.${isVideo ? 'mp4' : 'jpg'}";
    return "$_tempPath/$fileName";
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
      body: AnimatedBuilder(
        animation: DownloadManager.instance,
        builder: (context, child) {
          final manager = DownloadManager.instance;
          final isBatchDownloading = manager.isBatchDownloading(widget.postUrl);

          if (_tempPath == null) return const SizedBox();

          return Stack(
            children: [
              // --- CONTENT CAROUSEL ---
              Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.mediaItems.length,
                      onPageChanged: (index) => setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        final itemUrl = widget.mediaItems[index]['url']!;
                        final expectedPath = _getExpectedFilePath(itemUrl, index);
                        final file = File(expectedPath);

                        bool fileExists = file.existsSync();

                        if (fileExists) {
                          return LocalMediaViewer(filePath: expectedPath);
                        }

                        final task = manager.activeTasks.firstWhere(
                              (t) => t.url == itemUrl,
                          orElse: () => DownloadTask(id: "", url: "", type: "", username: "", caption: "", postUrl: ""),
                        );

                        if (task.isCompleted && task.localPath != null) {
                          return LocalMediaViewer(filePath: task.localPath!);
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.mediaItems[index]['thumbnail'] != null)
                              Image.network(
                                widget.mediaItems[index]['thumbnail']!,
                                fit: BoxFit.cover,
                                errorBuilder: (_,__,___) => Container(color: Colors.grey[200]),
                              )
                            else
                              Container(color: Colors.grey[200]),

                            if(isBatchDownloading) Container(color: Colors.black38),
                          ],
                        );
                      },
                    ),
                  ),

                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.mediaItems.length,
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

                  // Next Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBatchDownloading ? Colors.grey : Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (isBatchDownloading) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("⏳ Please wait for download to finish")),
                          );
                          return;
                        }

                        final path = _getExpectedFilePath(widget.mediaItems[_currentPage]['url']!, _currentPage);
                        if (File(path).existsSync()) {
                          Navigator.of(context).push(createSlideRoute(
                            RepostScreen(
                              imageUrl: path,
                              username: widget.username,
                              initialCaption: widget.caption,
                              postUrl: widget.postUrl,
                              localImagePath: path,
                              showDeleteButton: false,
                              showHomeButton: true,
                            ),
                            direction: SlideFrom.right,
                          ));
                        }
                      },
                      child: Text(
                        isBatchDownloading ? "Downloading..." : "Next",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ... (Rest of LocalMediaViewer and PlayPauseOverlay)

// --------------------------------------------------------
// 🔹 Helper Widget to display Local Image or Video
// --------------------------------------------------------
class LocalMediaViewer extends StatefulWidget {
  final String filePath;
  const LocalMediaViewer({super.key, required this.filePath});

  @override
  State<LocalMediaViewer> createState() => _LocalMediaViewerState();
}

class _LocalMediaViewerState extends State<LocalMediaViewer> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.filePath.endsWith(".mp4")) {
      _videoController = VideoPlayerController.file(File(widget.filePath))
        ..initialize().then((_) {
          if (mounted) setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filePath.endsWith(".mp4")) {
      if (_videoController != null && _videoController!.value.isInitialized) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            _PlayPauseOverlay(controller: _videoController!),
          ],
        );
      } else {
        // ❌ REMOVED: CircularProgressIndicator
        // Replaced with a black container to prevent white flashes while loading
        return Container(color: Colors.black);
      }
    } else {
      return Image.file(
        File(widget.filePath),
        fit: BoxFit.contain,
        errorBuilder: (_,__,___) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
      );
    }
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
          Container(color: Colors.transparent),
          if (_showPlayIcon || !widget.controller.value.isPlaying)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
            ),
        ],
      ),
    );
  }
}