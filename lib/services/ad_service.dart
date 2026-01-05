import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:insta_save/main.dart';

class AdService {
  static final AdService _instance = AdService._internal();

  factory AdService() {
    return _instance;
  }

  AdService._internal();

  // Test Ad Unit IDs
  final String _bannerAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  final String _bannerAdUnitIdiOS = 'ca-app-pub-3940256099942544/2934735716';

  final String _interstitialAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  final String _interstitialAdUnitIdiOS =
      'ca-app-pub-3940256099942544/4411468910';

  final String _appOpenAdUnitIdAndroid =
      'ca-app-pub-3940256099942544/9257395921';
  final String _appOpenAdUnitIdiOS = 'ca-app-pub-3940256099942544/5662855259';

  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  bool _isPausedForShare = false; // Flag to pause ad for share sheet
  DateTime? _lastAdShowTime; // Track last show time

  // Counters
  static const String _appOpenCountKey = 'ad_app_open_count';
  static const String _selectPicsCountKey = 'ad_select_pics_count';
  static const String _repostCountKey = 'ad_repost_count';

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    // Set Test Device ID from logs
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: ['7D8B7204FB3723B1109916F0D0A29A3E']),
    );
  }

  // --- APP OPEN ADS ---

  // Method to pause/resume app open ads (e.g. for share sheet)
  void setPausedForShare(bool paused) {
    _isPausedForShare = paused;
    debugPrint("App Open Ad Flow: Set Paused For Share = $paused");
  }

  Future<void> loadAppOpenAd() async {
    final String adUnitId = Platform.isAndroid
        ? _appOpenAdUnitIdAndroid
        : _appOpenAdUnitIdiOS;
    debugPrint("App Open Ad Flow: Loading Ad Unit ID: $adUnitId");

    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  Future<void> showAppOpenAdWithLoader(BuildContext context) async {
    if (_isShowingAppOpenAd) return;

    // Check if paused for share sheet
    if (_isPausedForShare) {
      debugPrint("App Open Ad Flow: Skipping due to Share Sheet Close.");
      _isPausedForShare = false; // Reset flag
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    int openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, openCount);

    debugPrint("App Open Ad Flow: Counter = $openCount");

    // Interval Logic: 1 (Skip), 2 (Skip), 3 (Show)...
    // Prevent loop: Don't show if shown recently (e.g. < 5 seconds ago) which happens on Ad Dismiss
    // Also protects against short background trips.
    if (_lastAdShowTime != null &&
        DateTime.now().difference(_lastAdShowTime!) <
            const Duration(seconds: 10)) {
      debugPrint("App Open Ad Flow: Skipping due to recent show.");
      return;
    }

    // Interval Logic: 1 (Skip), 2 (Skip), 3 (Show)...
    if (openCount % 3 != 0) {
      debugPrint("App Open Ad Flow: Skipping due to interval ($openCount).");
      return;
    }

    // 1. Show Loader Screen
    // 1. Show Loader Screen
    // 1. Show Loader Screen (Push as a Page for full control)
    debugPrint("App Open Ad Flow: Showing Loader...");
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const _LoaderPage(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    // 2. Start Ad Load if needed
    if (_appOpenAd == null) {
      debugPrint("App Open Ad Flow: Ad is null, loading new ad...");
      loadAppOpenAd();
    } else {
      debugPrint("App Open Ad Flow: Ad is already loaded.");
    }

    // 3. Wait for 3 seconds (Enforce Loader Duration)
    debugPrint("App Open Ad Flow: Waiting for 3 seconds...");
    await Future.delayed(const Duration(seconds: 3));

    // 4. Check Ad Status & Transition
    if (_appOpenAd != null) {
      debugPrint("App Open Ad Flow: Ad ready. Showing...");

      // Pass a callback to close the loader (and the ad wrapper) when ad finishes
      _showAdInternal(
        onComplete: () {
          debugPrint("App Open Ad Flow: Ad Internal Complete. Popping Loader.");
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!).pop();
          }
        },
      );
    } else {
      debugPrint("App Open Ad Flow: Ad not ready after 3s. Proceeding to app.");
      // Just pop the loader
      if (navigatorKey.currentContext != null) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
    }
  }

  void _showAdInternal({VoidCallback? onComplete}) {
    if (_appOpenAd == null) {
      onComplete?.call();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint("App Open Ad Flow: Ad showed full screen.");
        _isShowingAppOpenAd = true;
        _lastAdShowTime = DateTime.now(); // Record show time
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint("App Open Ad Flow: Ad dismissed.");
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        onComplete?.call(); // Call callback here
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("App Open Ad Flow: Ad failed to show - $error");
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
        onComplete?.call(); // Call callback here
      },
    );
    _appOpenAd!.show();
  }

  // Deprecated: Use showAppOpenAdWithLoader instead
  Future<void> showAppOpenAdIfAvailable() async {
    // Keeping this for backward compatibility if needed, but redirects to internal show
    final prefs = await SharedPreferences.getInstance();
    int openCount = (prefs.getInt(_appOpenCountKey) ?? 0) + 1;
    await prefs.setInt(_appOpenCountKey, openCount);
    if (openCount % 3 != 0) return;

    if (_appOpenAd == null) {
      loadAppOpenAd();
      return;
    }
    _showAdInternal();
  }

  // --- INTERSTITIAL ADS ---

  void showInterstitialAd({required Function onAdDismissed}) {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid
          ? _interstitialAdUnitIdAndroid
          : _interstitialAdUnitIdiOS,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _lastAdShowTime =
                  DateTime.now(); // Record dismissal time to prevent App Open Ad loop
              onAdDismissed();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              onAdDismissed();
            },
          );
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          onAdDismissed();
        },
      ),
    );
  }

  Future<void> handleSelectPicsAd(Function onProceed) async {
    final prefs = await SharedPreferences.getInstance();
    int count = (prefs.getInt(_selectPicsCountKey) ?? 0) + 1;
    await prefs.setInt(_selectPicsCountKey, count);

    debugPrint("Select Pics Count: $count");

    // "Show an ad when a user selects images on the 1st, 3rd, 5th, etc." (Odd numbers)
    if (count % 2 != 0) {
      showInterstitialAd(onAdDismissed: onProceed);
    } else {
      onProceed();
    }
  }

  Future<void> handleRepostAd(Function onProceed) async {
    final prefs = await SharedPreferences.getInstance();
    int count = (prefs.getInt(_repostCountKey) ?? 0) + 1;
    await prefs.setInt(_repostCountKey, count);

    debugPrint("Repost Count: $count");

    // "Show an ad when reposting images at the 2nd, 4th, 6th, etc." (Even numbers)
    if (count % 2 == 0) {
      showInterstitialAd(onAdDismissed: onProceed);
    } else {
      onProceed();
    }
  }

  void handlePasteLinkAd(Function onProceed) {
    // "Show an ad each time when the user clicks Paste Link and proceeds with Go"
    showInterstitialAd(onAdDismissed: onProceed);
  }

  // --- BANNER ADS ---

  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: Platform.isAndroid
          ? _bannerAdUnitIdAndroid
          : _bannerAdUnitIdiOS,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    )..load();
  }
}

// Renamed to _LoaderPage and verified full screen visuals
class _LoaderPage extends StatelessWidget {
  const _LoaderPage();

  @override
  Widget build(BuildContext context) {
    // WillPopScope to prevent back button
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.white, // Background screen color
        body: Center(
          child: Image.asset(
            'assets/images/App_openAd_loader.gif',
            width: 150, // Adjust size as needed
            height: 150,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
