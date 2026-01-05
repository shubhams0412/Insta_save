import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RatingService {
  static final RatingService _instance = RatingService._internal();

  factory RatingService() {
    return _instance;
  }

  RatingService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

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
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
      // Toast to user as feedback/confirmation (per request)
      Fluttertoast.showToast(
        msg: "Please rate us on Play Store",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint("Error showing rating: $e");
    }
  }

  // Helper getters for keys to avoid typos in other files
  String get settingsReturnCountKey => _settingsReturnCountKey;
  String get mediaSaveCountKey => _mediaSaveCountKey;
}
