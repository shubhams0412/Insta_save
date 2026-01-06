import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:insta_save/services/saved_post.dart';

class DownloadTask {
  final String id;
  final String url;
  final String? thumbnailUrl;
  final String type;
  final String username;
  final String caption;
  final String postUrl;
  final ValueNotifier<double> progress = ValueNotifier(0.0);
  final ValueNotifier<bool> isCompleted = ValueNotifier(false);

  bool hasError = false;
  String? localPath;

  DownloadTask({
    required this.id,
    required this.url,
    this.thumbnailUrl,
    required this.type,
    required this.username,
    required this.caption,
    required this.postUrl,
  });
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager instance = DownloadManager._();
  DownloadManager._();

  final List<DownloadTask> _activeTasks = [];
  List<DownloadTask> get activeTasks => _activeTasks;

  // ✅ NEW: Stream to notify Home Screen only when a download finishes
  final StreamController<void> _completionController =
      StreamController.broadcast();
  Stream<void> get onTaskCompleted => _completionController.stream;

  void startBatchDownloads(
    List<Map<String, String>> mediaItems,
    String username,
    String caption,
    String postUrl,
  ) {
    for (int i = 0; i < mediaItems.length; i++) {
      final item = mediaItems[i];
      String type = item['type'] ?? 'image';
      if (item['url']!.contains('.mp4')) type = 'video';

      final task = DownloadTask(
        id: "${postUrl}_$i",
        url: item['url']!,
        thumbnailUrl: item['thumbnail'],
        type: type,
        username: username,
        caption: caption,
        postUrl: postUrl,
      );

      _activeTasks.add(task);
      _processTask(task, i);
    }
    notifyListeners();
  }

  Future<void> _processTask(DownloadTask task, int index) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final extension = task.type == 'video' ? 'mp4' : 'jpg';
      final fileName = "insta_${task.url.hashCode}_$index.$extension";
      final filePath = "${tempDir.path}/$fileName";
      final file = File(filePath);

      if (await file.exists()) {
        _completeTask(task, filePath);
        return;
      }

      final request = http.Request('GET', Uri.parse(task.url));
      final response = await http.Client().send(request);
      final contentLength = response.contentLength ?? 1;

      List<int> bytes = [];
      int receivedBytes = 0;

      response.stream.listen(
        (List<int> newBytes) {
          bytes.addAll(newBytes);
          receivedBytes += newBytes.length;
          task.progress.value = receivedBytes / contentLength;
          notifyListeners(); // 🔥 Notify UI for progress bar updates
        },
        onDone: () async {
          await file.writeAsBytes(bytes);
          await SaverGallery.saveFile(
            filePath: filePath,
            fileName: fileName,
            skipIfExists: true,
            androidRelativePath: 'Pictures/InstaSave',
          );
          _completeTask(task, filePath);
        },
        onError: (e) {
          print("Download Error: $e");
          _activeTasks.remove(task);
          notifyListeners();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _activeTasks.remove(task);
      notifyListeners();
    }
  }

  Future<void> _completeTask(DownloadTask task, String localPath) async {
    task.localPath = localPath;
    task.progress.value = 1.0;
    task.isCompleted.value = true;
    notifyListeners();

    // 1. Save to History
    await _saveToHistory(task);

    // 2. Notify UI: Show 100% progress
    notifyListeners();

    // 3. 🔥 FIRE COMPLETION EVENT NOW (Start reloading Home Screen DB)
    // We do this BEFORE removing the task so there is no gap.
    _completionController.add(null);

    // 4. Wait long enough for Home Screen to reload (e.g., 2 seconds)
    // During this time, the item exists in BOTH lists.
    await Future.delayed(const Duration(seconds: 2));

    // 5. Remove from active list
    _activeTasks.remove(task);
    notifyListeners();
  }

  // Mutex Lock for saving to history
  Future<void> _saveLock = Future.value();

  Future<void> _saveToHistory(DownloadTask task) async {
    // Wait for the previous save to complete before starting this one
    // This chains the futures: prev -> current -> next
    final completer = Completer<void>();
    final previousLock = _saveLock;
    _saveLock = completer.future;

    try {
      await previousLock;
    } catch (e) {
      // Ignore errors from previous task to proceed
    }

    try {
      final prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: <String>{'savedPosts'},
        ),
      );
      final List<String> existingData = prefs.getStringList('savedPosts') ?? [];

      final newPost = SavedPost(
        localPath: task.localPath!,
        username: task.username,
        caption: task.caption,
        postUrl: task.postUrl,
      );

      bool isDuplicate = existingData.any((item) {
        final decoded = jsonDecode(item);
        return decoded['localPath'] == task.localPath;
      });

      if (!isDuplicate) {
        existingData.add(jsonEncode(newPost.toJson()));
        await prefs.setStringList('savedPosts', existingData);
      }
    } finally {
      completer.complete();
    }
  }

  double getBatchProgress(String postUrl) {
    final tasks = _activeTasks.where((t) => t.postUrl == postUrl).toList();
    if (tasks.isEmpty) return 1.0;

    double total = 0;
    for (var t in tasks) {
      total += t.progress.value; // ✅ FIX
    }
    return total / tasks.length;
  }

  bool isBatchDownloading(String postUrl) {
    return _activeTasks.any((t) => t.postUrl == postUrl);
  }
}
