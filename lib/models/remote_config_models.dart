import 'package:flutter/material.dart';

class RemoteConfigModels {
  static Color parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class SalesConfig {
  final String titleText;
  final double titleSize;
  final Color titleColor;
  final String subTitleText;
  final double subTitleSize;
  final Color subTitleColor;
  final double featureSize;
  final Color featureColor;
  final double planSize;
  final Color planColor;
  final List<Map<String, dynamic>> features;
  final List<Map<String, dynamic>> plans;
  final String privacyText;
  final String termsText;
  final String closeText;
  final double footerTextSize;
  final Color footerTextColor;

  SalesConfig({
    required this.titleText,
    required this.titleSize,
    required this.titleColor,
    required this.subTitleText,
    required this.subTitleSize,
    required this.subTitleColor,
    required this.featureSize,
    required this.featureColor,
    required this.planSize,
    required this.planColor,
    required this.features,
    required this.plans,
    required this.privacyText,
    required this.termsText,
    required this.closeText,
    required this.footerTextSize,
    required this.footerTextColor,
  });

  factory SalesConfig.fromJson(Map<String, dynamic> json) {
    return SalesConfig(
      titleText: json['title']['text'],
      titleSize: (json['title']['textSize'] as num).toDouble(),
      titleColor: RemoteConfigModels.parseColor(json['title']['textColor']),
      subTitleText: json['subTitle']['text'],
      subTitleSize: (json['subTitle']['textSize'] as num).toDouble(),
      subTitleColor: RemoteConfigModels.parseColor(
        json['subTitle']['textColor'],
      ),
      featureSize: (json['featuresStyle']['textSize'] as num).toDouble(),
      featureColor: RemoteConfigModels.parseColor(
        json['featuresStyle']['textColor'],
      ),
      planSize: (json['plansStyle']['textSize'] as num).toDouble(),
      planColor: RemoteConfigModels.parseColor(json['plansStyle']['textColor']),
      features: List<Map<String, dynamic>>.from(json['features']),
      plans: List<Map<String, dynamic>>.from(json['plans']),
      privacyText: json['privacyText'] ?? 'Privacy Policy',
      termsText: json['termsText'] ?? 'Terms of Use',
      closeText: json['closeText'] ?? 'Close',
      footerTextSize:
          (json['footerStyle'] != null &&
              json['footerStyle']['textSize'] != null)
          ? (json['footerStyle']['textSize'] as num).toDouble()
          : 12.0,
      footerTextColor: RemoteConfigModels.parseColor(
        (json['footerStyle'] != null &&
                json['footerStyle']['textColor'] != null)
            ? json['footerStyle']['textColor']
            : '#60FFFFFF',
      ),
    );
  }
}

class IntroConfig {
  final List<IntroItemConfig> items;
  final double titleSize;
  final Color titleColor;

  IntroConfig({
    required this.items,
    required this.titleSize,
    required this.titleColor,
  });

  factory IntroConfig.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List;
    List<IntroItemConfig> itemsList = list
        .map((i) => IntroItemConfig.fromJson(i))
        .toList();
    return IntroConfig(
      items: itemsList,
      titleSize: (json['titleSize'] as num?)?.toDouble() ?? 24.0,
      titleColor: RemoteConfigModels.parseColor(
        json['titleColor'] ?? '#000000',
      ),
    );
  }
}

class IntroItemConfig {
  final String title;

  IntroItemConfig({required this.title});

  factory IntroItemConfig.fromJson(Map<String, dynamic> json) {
    return IntroItemConfig(title: json['title']);
  }
}

class RatingConfig {
  final String title;
  final String subtitle;
  final double titleSize;
  final Color titleColor;
  final double subTitleSize;
  final Color subTitleColor;

  RatingConfig({
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.titleColor,
    required this.subTitleSize,
    required this.subTitleColor,
  });

  factory RatingConfig.fromJson(Map<String, dynamic> json) {
    return RatingConfig(
      title: json['title'],
      subtitle: json['subtitle'],
      titleSize: (json['titleSize'] as num?)?.toDouble() ?? 28.0,
      titleColor: RemoteConfigModels.parseColor(
        json['titleColor'] ?? '#000000',
      ),
      subTitleSize: (json['subTitleSize'] as num?)?.toDouble() ?? 16.0,
      subTitleColor: RemoteConfigModels.parseColor(
        json['subTitleColor'] ?? '#808080',
      ),
    );
  }
}

class AdsConfig {
  final bool banner;
  final bool interstitial;
  final bool appOpen;

  AdsConfig({
    required this.banner,
    required this.interstitial,
    required this.appOpen,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    return AdsConfig(
      banner: json['banner'] ?? true,
      interstitial: json['interstitial'] ?? true,
      appOpen: json['appOpen'] ?? true,
    );
  }
}
