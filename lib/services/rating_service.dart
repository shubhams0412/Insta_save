import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insta_save/main.dart'; // To access navigatorKey
import 'package:insta_save/widgets/rating_dialog.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() {
    return _instance;
  }

  RatingService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  bool _isShowing = false;

  // Keys for counters
  static const String _settingsReturnCountKey = 'rating_settings_return_count';
  static const String _mediaSaveCountKey = 'rating_media_save_count';

  /// Shows the rating flow.
  /// If [always] is true, it attempts to show the review dialog every time.
  /// If [always] is false, it uses the provided [counterKey] to show it on 1st, 3rd, 5th... occurrences.
  Future<void> checkAndShowRating(
    String? counterKey, {
    bool always = false,
  }) async {
    if (always) {
      await _showReview();
      return;
    }

    if (counterKey != null) {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt(counterKey) ?? 0) + 1;
      await prefs.setInt(counterKey, count);

      // Show on 1st, 3rd, 5th... (Odd numbers)
      if (count % 2 != 0) {
        await _showReview();
      }
    }
  }

  Future<void> _showReview() async {
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

      // We still attempt standard review in background or after custom dialog if needed,
      // but for now, the custom dialog is the primary UI.
      if (await _inAppReview.isAvailable()) {
        // Option: only show standard review if they gave 4+ stars in custom dialog
      }
    } catch (e) {
      _isShowing = false;
      debugPrint("Error showing rating: $e");
    }
  }

  // Helper getters for keys to avoid typos in other files
  String get settingsReturnCountKey => _settingsReturnCountKey;
  String get mediaSaveCountKey => _mediaSaveCountKey;
}
