import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:InstSave/main.dart'; // To access navigatorKey
import 'package:InstSave/widgets/rating_dialog.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() {
    return _instance;
  }

  RatingService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  bool _isShowing = false;

  // Keys for counters (updated for new strategy)
  static const String _selectPicsSaveCountKey = 'rating_select_pics_save_count';
  static const String _repostGoHomeCountKey = 'rating_repost_go_home_count';
  static const String _pasteLinkDownloadCountKey =
      'rating_paste_link_download_count';

  /// Shows CUSTOM rating dialog (our custom UI)
  /// If [always] is true, shows every time
  /// If [always] is false, uses counter to show on 1st, 5th, 9th... occurrences
  Future<void> showCustomRating(
    String? counterKey, {
    bool always = false,
  }) async {
    debugPrint(
      "📊 showCustomRating called (always: $always, key: $counterKey)",
    );

    if (always) {
      debugPrint("✅ Showing custom rating (always mode)");
      await _showCustomReview();
      return;
    }

    if (counterKey != null) {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt(counterKey) ?? 0) + 1;
      await prefs.setInt(counterKey, count);
      debugPrint("📈 Custom rating counter for '$counterKey': $count");

      // Show on 1st, 5th, 9th... (1 + multiples of 4)
      if (count == 1 || (count - 1) % 4 == 0) {
        debugPrint("✅ Showing custom rating (count: $count)");
        await _showCustomReview();
      } else {
        debugPrint(
          "⏭️ Skipping custom rating (count: $count, next at: ${count + (4 - ((count - 1) % 4))})",
        );
      }
    }
  }

  /// Shows NATIVE rating dialog (system in-app review)
  /// If [always] is true, shows every time
  /// If [always] is false, uses counter to show on 1st, 5th, 9th... occurrences
  Future<void> showNativeRating(
    String? counterKey, {
    bool always = false,
  }) async {
    debugPrint(
      "📊 showNativeRating called (always: $always, key: $counterKey)",
    );

    if (always) {
      debugPrint("✅ Showing native rating (always mode)");
      await _showNativeReview();
      return;
    }

    if (counterKey != null) {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt(counterKey) ?? 0) + 1;
      await prefs.setInt(counterKey, count);
      debugPrint("📈 Native rating counter for '$counterKey': $count");

      // Show on 1st, 5th, 9th... (1 + multiples of 4)
      if (count == 1 || (count - 1) % 4 == 0) {
        debugPrint("✅ Showing native rating (count: $count)");
        await _showNativeReview();
      } else {
        debugPrint(
          "⏭️ Skipping native rating (count: $count, next at: ${count + (4 - ((count - 1) % 4))})",
        );
      }
    }
  }

  /// Shows our custom rating dialog
  Future<void> _showCustomReview() async {
    if (_isShowing) return;
    try {
      final context = navigatorKey.currentContext;
      if (context == null) return;

      _isShowing = true;
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => const RatingDialog(),
      );
      _isShowing = false;
    } catch (e) {
      _isShowing = false;
      debugPrint("Error showing custom rating: $e");
    }
  }

  /// Shows native in-app review
  Future<void> _showNativeReview() async {
    if (_isShowing) {
      debugPrint("⚠️ Native review already showing, skipping");
      return;
    }
    try {
      _isShowing = true;
      final isAvailable = await _inAppReview.isAvailable();
      debugPrint("🔍 Native review available: $isAvailable");

      if (isAvailable) {
        debugPrint("🚀 Requesting native review...");
        await _inAppReview.requestReview();
        debugPrint(
          "✅ Native review request completed (Note: Won't show in debug builds)",
        );
      } else {
        debugPrint("❌ Native review not available on this device/build");
      }
      _isShowing = false;
    } catch (e) {
      _isShowing = false;
      debugPrint("❌ Error showing native rating: $e");
    }
  }

  // Helper getters for keys to avoid typos in other files
  String get selectPicsSaveCountKey => _selectPicsSaveCountKey;
  String get repostGoHomeCountKey => _repostGoHomeCountKey;
  String get pasteLinkDownloadCountKey => _pasteLinkDownloadCountKey;
}
