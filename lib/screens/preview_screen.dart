import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:insta_save/screens/repost_screen.dart';
import 'package:insta_save/services/download_manager.dart';
import 'package:insta_save/services/navigation_helper.dart';
import 'package:insta_save/widgets/status_dialog.dart';

import 'package:insta_save/services/rating_service.dart';

class PreviewScreen extends StatefulWidget {
  // Static flag to prevent HomeScreen from triggering rating when PreviewScreen is active
  static bool isProcessing = false;

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

  StreamSubscription? _downloadSubscription;
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initTempDir();

    // 1. Listen for completion to Auto-Close dialog
    _downloadSubscription = DownloadManager.instance.onTaskCompleted.listen((
      _,
    ) {
      if (!mounted) return;
      // Small delay to allow manager to update internal list
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final isStillDownloading = DownloadManager.instance.isBatchDownloading(
          widget.postUrl,
        );

        if (!isStillDownloading && _isDialogOpen) {
          Navigator.of(context).pop(); // Auto-Pop
          _isDialogOpen = false;

          // 3. Trigger Rating AFTER Downling dialog close
          // Small delay to ensure snackbars or pop animations finish if any
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              RatingService().checkAndShowRating(
                RatingService().mediaSaveCountKey,
              );
            }
          });
        }
      });
    });

    // 2. Start Download & Show Dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!DownloadManager.instance.isBatchDownloading(widget.postUrl)) {
        PreviewScreen.isProcessing = true; // Set flag
        DownloadManager.instance.startBatchDownloads(
          widget.mediaItems,
          widget.username,
          widget.caption,
          widget.postUrl,
        );
        _isDialogOpen = true;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return PopScope(
              canPop: false,
              child: AnimatedBuilder(
                animation: DownloadManager.instance,
                builder: (context, child) {
                  final progress = DownloadManager.instance.getBatchProgress(
                    widget.postUrl,
                  );

                  final currentItem = widget.mediaItems[_currentPage];
                  final bool isVideo =
                      currentItem['url']?.contains('.mp4') ?? false;
                  final int targetTab = isVideo ? 1 : 0;

                  return StatusDialog(
                    type: DialogType.processing,
                    progress: progress,
                    onButtonClick: () {
                      // "Got it, notify me" -> Go to Home with specific tab
                      Navigator.of(
                        context,
                      ).pop({'home': true, 'tab': targetTab});
                    },
                  );
                },
              ),
            );
          },
        ).then((result) {
          _isDialogOpen = false;
          PreviewScreen.isProcessing = false; // Reset flag
          if (result is Map && result['home'] == true && mounted) {
            Navigator.of(context).pop(result);
          }
        });
      }
    });
  }

  Future<void> _initTempDir() async {
    final dir = await getTemporaryDirectory();
    if (mounted) {
      setState(() => _tempPath = dir.path);
    }
  }

  @override
  void dispose() {
    PreviewScreen.isProcessing = false; // Ensure flag is reset
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
    // Determine target tab based on the current page's media type
    final currentItem = widget.mediaItems[_currentPage];
    final bool isVideo = currentItem['url']?.contains('.mp4') ?? false;
    final int targetTab = isVideo ? 1 : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop({'home': true, 'tab': targetTab});
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                Navigator.of(context).pop({'home': true, 'tab': targetTab}),
          ),
          title: Text(
            widget.username,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: _tempPath == null
            ? const SizedBox() // Wait for temp path
            : AnimatedBuilder(
                animation: DownloadManager.instance,
                builder: (context, child) {
                  final isBatchDownloading = DownloadManager.instance
                      .isBatchDownloading(widget.postUrl);
                  final batchProgress = DownloadManager.instance
                      .getBatchProgress(widget.postUrl);

                  // Consider download complete if progress is 100% OR no active tasks
                  final isDownloadComplete =
                      !isBatchDownloading || batchProgress >= 1.0;

                  return Stack(
                    children: [
                      Column(
                        children: [
                          // Carousel
                          Expanded(child: _buildCarousel(!isDownloadComplete)),

                          // Indicators
                          _buildPageIndicators(),

                          // Next Button
                          _buildNextButton(!isDownloadComplete),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildCarousel(bool isBatchDownloading) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.mediaItems.length,
      onPageChanged: (index) => setState(() => _currentPage = index),
      itemBuilder: (context, index) {
        final itemUrl = widget.mediaItems[index]['url']!;
        final thumbnail = widget.mediaItems[index]['thumbnail'];
        final expectedPath = _getExpectedFilePath(itemUrl, index);
        final file = File(expectedPath);

        // 1. Check Local File
        if (file.existsSync()) {
          // ✅ Key is important to prevent video state mix-ups
          return LocalMediaViewer(
            key: ValueKey(expectedPath),
            filePath: expectedPath,
            thumbnail: thumbnail, // Pass thumbnail for smooth loading
          );
        }

        // 2. Check Completed Task (In memory fallback)
        final task = DownloadManager.instance.activeTasks.firstWhere(
          (t) => t.url == itemUrl,
          orElse: () => DownloadTask(
            id: "",
            url: "",
            type: "",
            username: "",
            caption: "",
            postUrl: "",
          ),
        );

        if (task.isCompleted.value && task.localPath != null) {
          return LocalMediaViewer(
            key: ValueKey(task.localPath),
            filePath: task.localPath!,
            thumbnail: thumbnail,
          );
        }

        // 3. Fallback: Show Thumbnail + Overlay (with error handling)
        return Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail != null && thumbnail.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbnail,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 300),
                // Placeholder removed aka transparent while loading
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 50,
                    ),
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[300],
                child: const Center(
                  child: Icon(Icons.image, color: Colors.grey, size: 50),
                ),
              ),

            // Darken if downloading
            if (isBatchDownloading) Container(color: Colors.black38),
          ],
        );
      },
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.mediaItems.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          width: _currentPage == index ? 10 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.black : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildNextButton(bool isBatchDownloading) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isBatchDownloading ? Colors.grey : Colors.black,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () {
          if (isBatchDownloading) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("⏳ Please wait for download to finish"),
              ),
            );
            return;
          }

          final path = _getExpectedFilePath(
            widget.mediaItems[_currentPage]['url']!,
            _currentPage,
          );
          final thumbnail = widget.mediaItems[_currentPage]['thumbnail'];

          if (File(path).existsSync()) {
            Navigator.of(context)
                .push(
                  createSlideRoute(
                    RepostScreen(
                      imageUrl: path,
                      username: widget.username,
                      initialCaption: widget.caption,
                      postUrl: widget.postUrl,
                      localImagePath: path,
                      showDeleteButton: false,
                      showHomeButton: true,
                      thumbnailUrl: thumbnail ?? path,
                    ),
                    direction: SlideFrom.right,
                  ),
                )
                .then((result) {
                  if (result is Map && result['home'] == true) {
                    if (mounted) {
                      Navigator.of(context).pop(result);
                    }
                  }
                });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "⚠️ Media file not found. Try downloading again.",
                ),
              ),
            );
          }
        },
        child: Text(
          isBatchDownloading ? "Downloading..." : "Next",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 🔹 Helper Widget: LocalMediaViewer
// --------------------------------------------------------
class LocalMediaViewer extends StatefulWidget {
  final String filePath;
  final String? thumbnail;

  const LocalMediaViewer({super.key, required this.filePath, this.thumbnail});

  @override
  State<LocalMediaViewer> createState() => _LocalMediaViewerState();
}

class _LocalMediaViewerState extends State<LocalMediaViewer> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isDisposed = false;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();
    _isVideo = widget.filePath.toLowerCase().endsWith(".mp4");
    if (_isVideo) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant LocalMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _disposeVideo();
      _hasError = false;
      _isDisposed = false;
      _isVideo = widget.filePath.toLowerCase().endsWith(".mp4");
      if (_isVideo) {
        _initializeVideo();
      }
    }
  }

  Future<void> _initializeVideo() async {
    final file = File(widget.filePath);

    // Verify file exists and has content
    if (!file.existsSync()) {
      if (mounted && !_isDisposed) {
        setState(() => _hasError = true);
      }
      return;
    }

    try {
      // Check if file has content
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }

      // Small delay to ensure file is fully written
      await Future.delayed(const Duration(milliseconds: 200));

      if (_isDisposed || !mounted) return;

      _videoController = VideoPlayerController.file(file);

      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Video initialization timeout');
        },
      );

      if (_isDisposed || !mounted) {
        _videoController?.dispose();
        return;
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }

      _videoController!.setLooping(true);
      _videoController!.play();

      // Force UI updates for play/pause state and ensure looping
      _videoController!.addListener(_videoListener);
    } catch (error) {
      debugPrint("❌ Video initialization error: $error");
      if (mounted && !_isDisposed) {
        setState(() => _hasError = true);
      }
      _videoController?.dispose();
      _videoController = null;
    }
  }

  void _videoListener() {
    if (!mounted || _isDisposed) return;
    setState(() {});
  }

  void _disposeVideo() {
    _isDisposed = true;
    _videoController?.removeListener(_videoListener);
    _videoController?.pause();
    _videoController?.dispose();
    _videoController = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      return _buildVideoPlayer();
    } else {
      return _buildImageViewer();
    }
  }

  Widget _buildVideoPlayer() {
    // ERROR STATE
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 50),
              const SizedBox(height: 10),
              const Text(
                'Failed to load video',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isDisposed = false;
                  });
                  _initializeVideo();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // PLAYING STATE
    if (_isInitialized &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
            _PlayPauseOverlay(controller: _videoController!),
          ],
        ),
      );
    }

    // LOADING STATE
    if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.thumbnail!,
            fit: BoxFit.contain,
            placeholder: (context, url) => const SizedBox(),
            errorWidget: (context, url, error) => const SizedBox(),
          ),
        ),
      );
    }

    return Container(color: Colors.black);
  }

  Widget _buildImageViewer() {
    final file = File(widget.filePath);

    // File doesn't exist
    if (!file.existsSync()) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image, size: 50, color: Colors.grey),
              SizedBox(height: 8),
              Text('Image not found', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Display image with comprehensive error handling
    return Container(
      color: Colors.black,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            debugPrint("❌ Image load error: $error");
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, size: 50, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;

            return AnimatedOpacity(
              opacity: frame == null ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: frame == null
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : child,
            );
          },
        ),
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
