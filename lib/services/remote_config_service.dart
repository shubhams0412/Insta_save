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
  AdsConfig? _adsConfig;
  HomeConfig? _homeConfig;
  SettingsConfig? _settingsConfig;
  bool _isInstaLoginFlowEnabled = true;
  String _privacyUrl = 'https://turbofast.io/privacy/';
  String _termsUrl = 'https://turbofast.io/terms/';
  String _contactUsUrl = 'https://turbofast.io/contact/';

  SalesConfig? get salesConfig => _salesConfig;
  IntroConfig? get introConfig => _introConfig;
  RatingConfig? get ratingConfig => _ratingConfig;
  AdsConfig? get adsConfig => _adsConfig;
  HomeConfig? get homeConfig => _homeConfig;
  SettingsConfig? get settingsConfig => _settingsConfig;
  bool get isInstaLoginFlowEnabled => _isInstaLoginFlowEnabled;
  String get privacyUrl => _privacyUrl;
  String get termsUrl => _termsUrl;
  String get contactUsUrl => _contactUsUrl;

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(
            minutes: 1,
          ), // Reduced for testing
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

    // Parse Insta Login Flow Flag
    _isInstaLoginFlowEnabled = _remoteConfig.getBool(
      'is_insta_login_flow_enabled',
    );

    // Parse Global URLs
    _privacyUrl = _remoteConfig.getString('privacyUrl').isNotEmpty
        ? _remoteConfig.getString('privacyUrl')
        : 'https://turbofast.io/privacy/';
    _termsUrl = _remoteConfig.getString('termsUrl').isNotEmpty
        ? _remoteConfig.getString('termsUrl')
        : 'https://turbofast.io/terms/';
    _contactUsUrl = _remoteConfig.getString('contactUsUrl').isNotEmpty
        ? _remoteConfig.getString('contactUsUrl')
        : 'https://turbofast.io/contact/';

    // Parse Ads Config
    String adsJson = _remoteConfig.getString('ads_config');
    if (adsJson.isNotEmpty) {
      try {
        _adsConfig = AdsConfig.fromJson(jsonDecode(adsJson));
      } catch (e) {
        debugPrint('Error parsing AdsConfig: $e');
      }
    }

    // Parse Home Config
    String homeJson = _remoteConfig.getString(
      'home_screen_sales_banner_config',
    );
    if (homeJson.isNotEmpty) {
      try {
        _homeConfig = HomeConfig.fromJson(jsonDecode(homeJson));
      } catch (e) {
        debugPrint('Error parsing HomeConfig: $e');
      }
    }

    // Parse Settings Config
    String settingsJson = _remoteConfig.getString(
      'settings_screen_sales_banner_config',
    );
    if (settingsJson.isNotEmpty) {
      try {
        _settingsConfig = SettingsConfig.fromJson(jsonDecode(settingsJson));
      } catch (e) {
        debugPrint('Error parsing SettingsConfig: $e');
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
        "featuresTitle": {
          "text": "WHAT YOU GET",
          "textSize": 16,
          "textColor": "#FFFFFF",
        },
        "featuresStyle": {"textSize": 15, "textColor": "#FFFFFF"},
        "plansStyle": {
          "textSize": 18,
          "textColor": "#FFFFFF",
          "priceColor": "#FFFFFF",
          "originalPriceColor": "#60FFFFFF",
        },
        "features": [
          {"text": "Unlimited Reposts"},
          {"text": "Stories & Highlights"},
          {"text": "Photos Posts & Videos"},
          {"text": "100% Ad-Free Experience"},
          {"text": "Add Directly from the Gallery"},
        ],
        "plans": [
          {
            "title": "Weekly",
            "subtitle": "3-day free trial",
            "price": "\$4.99",
            "savePercentage": 93,
            "badgeText": "Popular",
            "productId": "com.video.downloader.saver.manager.week",
          },
          {
            "title": "Monthly",
            "subtitle": "3-day free trial",
            "price": "\$9.99",
            "productId": "com.video.downloader.saver.manager.month",
          },
        ],
        "privacyText": "Privacy Policy",
        "termsText": "Terms of Use",
        "closeText": "Close",
        "footerStyle": {"textSize": 12.0, "textColor": "#60FFFFFF"},
        "continueButton": {
          "text": "Continue",
          "textSize": 18,
          "textColor": "#FFFFFF",
        },
        "restoreButton": {
          "text": "Restore Purchase",
          "textSize": 14,
          "textColor": "#FFFFFF",
        },
      }),
      "intro_screen_config": jsonEncode({
        "items": [
          {"title": "Grab Reels, Stories &\nPosts in just one tap"},
          {"title": "Repost Your Favorite\nMoments – Instantly!"},
        ],
        "titleSize": 24.0,
        "titleColor": "#000000",
        "buttonText": "Get Started",
      }),
      "rating_screen_config": jsonEncode({
        "title": "Loved by Thousands",
        "subtitle": "Trusted by creators and users worldwide.",
        "titleSize": 28.0,
        "titleColor": "#000000",
        "subTitleSize": 16.0,
        "subTitleColor": "#808080",
      }),
      "is_insta_login_flow_enabled": true,
      "privacyUrl": "https://turbofast.io/privacy/",
      "termsUrl": "https://turbofast.io/terms/",
      "contactUsUrl": "https://turbofast.io/contact/",
      "ads_config": jsonEncode({
        "banner": true,
        "interstitial": true,
        "appOpen": true,
      }),
      "home_screen_sales_banner_config": jsonEncode({
        "proCard": {
          "title": "Upgrade to PRO",
          "titleSize": 20,
          "titleColor": "#FFFFFF",
          "subtitle": "Unlock unlimited downloads",
          "subtitleSize": 16,
          "subtitleColor": "#FFFFFF",
        },
      }),
      "settings_screen_sales_banner_config": jsonEncode({
        "adsBanner": {
          "title": "Remove Ads",
          "titleSize": 20,
          "titleColor": "#FFFFFF",
          "subtitle": "Become a PRO Member",
          "subtitleSize": 16,
          "subtitleColor": "#FFFFFF",
        },
      }),
    };
  }
}
