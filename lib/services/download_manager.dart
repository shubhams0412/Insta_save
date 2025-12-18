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

  double progress = 0.0;
  bool isCompleted = false;
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
  final StreamController<void> _completionController = StreamController.broadcast();
  Stream<void> get onTaskCompleted => _completionController.stream;

  void startBatchDownloads(List<Map<String, String>> mediaItems, String username, String caption, String postUrl) {
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
          task.progress = receivedBytes / contentLength;
          notifyListeners(); // Updates Progress Bar
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
    task.isCompleted = true;
    task.progress = 1.0;

    // 1. Save to History (so it's ready in the DB)
    await _saveToHistory(task);

    // 2. Notify UI (Update progress to 100%)
    notifyListeners();

    // 3. Fire Completion Event (Home Screen loads the data in background)
    _completionController.add(null);

    // 4. CHECK BATCH STATUS
    // Are there any OTHER tasks from this same postUrl that are NOT complete?
    bool isBatchStillRunning = _activeTasks.any((t) =>
    t.postUrl == task.postUrl && !t.isCompleted
    );

    if (isBatchStillRunning) {
      // 🛑 STOP! Don't remove this task yet.
      // Keep it in the list so it stays in order with its downloading friends.
      return;
    }

    // 5. IF BATCH IS DONE:
    // Wait a small moment for visual satisfaction
    await Future.delayed(const Duration(milliseconds: 500));

    // Remove ALL tasks belonging to this batch at once
    _activeTasks.removeWhere((t) => t.postUrl == task.postUrl);

    notifyListeners();
  }

  Future<void> _saveToHistory(DownloadTask task) async {
    final prefs = await SharedPreferences.getInstance();
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
  }

  double getBatchProgress(String postUrl) {
    final tasks = _activeTasks.where((t) => t.postUrl == postUrl).toList();
    if (tasks.isEmpty) return 1.0;
    double total = 0;
    for (var t in tasks) total += t.progress;
    return total / tasks.length;
  }

  bool isBatchDownloading(String postUrl) {
    return _activeTasks.any((t) => t.postUrl == postUrl);
  }
}