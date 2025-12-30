import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:insta_save/models/remote_config_models.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  SalesConfig? _salesConfig;
  IntroConfig? _introConfig;
  RatingConfig? _ratingConfig;

  SalesConfig? get salesConfig => _salesConfig;
  IntroConfig? get introConfig => _introConfig;
  RatingConfig? get ratingConfig => _ratingConfig;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      await _remoteConfig.setDefaults(_getDefaults());
      _parseConfigs(); // Load defaults immediately
      await _fetchAndActivate();
    } catch (e) {
      debugPrint('Error initializing Remote Config: $e');
      // Ensure specific configs are parsed even if fetch fails (from defaults)
      if (_salesConfig == null) _parseConfigs();
    }
  }

  Future<void> _fetchAndActivate() async {
    await _remoteConfig.fetchAndActivate();
    _parseConfigs();
  }

  void _parseConfigs() {
    // Parse Sales Config
    String salesJson = _remoteConfig.getString('sales_screen_config');
    if (salesJson.isNotEmpty) {
      try {
        _salesConfig = SalesConfig.fromJson(jsonDecode(salesJson));
      } catch (e) {
        debugPrint('Error parsing SalesConfig: $e');
      }
    }

    // Parse Intro Config
    String introJson = _remoteConfig.getString('intro_screen_config');
    if (introJson.isNotEmpty) {
      try {
        _introConfig = IntroConfig.fromJson(jsonDecode(introJson));
      } catch (e) {
        debugPrint('Error parsing IntroConfig: $e');
      }
    }

    // Parse Rating Config
    String ratingJson = _remoteConfig.getString('rating_screen_config');
    if (ratingJson.isNotEmpty) {
      try {
        _ratingConfig = RatingConfig.fromJson(jsonDecode(ratingJson));
      } catch (e) {
        debugPrint('Error parsing RatingConfig: $e');
      }
    }
  }

  Map<String, dynamic> _getDefaults() {
    return {
      "sales_screen_config": jsonEncode({
        "title": {
          "text": "Instant Saver Premium",
          "textSize": 28,
          "textColor": "#FFFFFF",
        },
        "subTitle": {
          "text": "No commitment, cancel anytime",
          "textSize": 16,
          "textColor": "#B3FFFFFF",
        },
        "featuresStyle": {"textSize": 15, "textColor": "#FFFFFF"},
        "plansStyle": {"textSize": 18, "textColor": "#FFFFFF"},
        "features": [
          {"text": "Download Unlimited Reels"},
          {"text": "Download Stories & Highlights ✨"},
          {"text": "Download Post & Videos"},
          {"text": "No Ads"},
          {"text": "Save Photos & Videos to Gallery"},
        ],
        "plans": [
          {
            "title": "Annual",
            "subtitle": "3-day free trial",
            "price": "\$19.99",
            "originalPrice": "\$32.00",
            "badgeText": "Best - \$0.38 / week",
          },
          {
            "title": "Monthly",
            "subtitle": "3-day free trial",
            "price": "\$9.99",
          },
        ],
      }),
      "intro_screen_config": jsonEncode({
        "items": [
          {"title": "Grab Reels, Stories &\nPosts in just one tap"},
          {"title": "Repost Your Favorite\nInstagram Posts!"},
        ],
        "titleSize": 24.0,
        "titleColor": "#000000",
      }),
      "rating_screen_config": jsonEncode({
        "title": "Loved by Thousands",
        "subtitle": "Trusted by creators and users worldwide.",
        "titleSize": 28.0,
        "titleColor": "#000000",
        "subTitleSize": 16.0,
        "subTitleColor": "#808080",
      }),
    };
  }
}
