import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:insta_save/services/remote_config_service.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final ValueNotifier<bool> isPremium = ValueNotifier(false);
  final ValueNotifier<bool> isPremiumPlus = ValueNotifier(false);

  static String weeklyProductId =
      RemoteConfigService().salesConfig?.plans.first['productId'] ??
      "com.video.downloader.saver.manager.week";

  static String creatorReelProductId = "com.video.downloader.creator.week";

  List<ProductDetails> _products = [];

  // ---------------- INIT ----------------
  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    debugPrint("IAP Available: $available");

    if (!available) return;

    await _loadPremiumFromLocal();
    await _fetchProducts();

    // Verify subscription status on app start
    await _verifySubscriptionStatus();

    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) => debugPrint("IAP Stream Error: $e"),
    );
  }

  // ---------------- PRODUCTS ----------------
  Future<void> _fetchProducts() async {
    final response = await _iap.queryProductDetails({
      weeklyProductId,
      creatorReelProductId,
    });

    _products = response.productDetails;

    debugPrint("IAP Products: ${_products.map((e) => e.id)}");
  }

  ProductDetails? getProduct(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String getWeeklyPrice() {
    return _getPriceForProduct(weeklyProductId);
  }

  double getWeeklyPriceValue() {
    return _getPriceValueForProduct(weeklyProductId);
  }

  String getCreatorReelPrice() {
    return _getPriceForProduct(creatorReelProductId);
  }

  double getCreatorReelPriceValue() {
    return _getPriceValueForProduct(creatorReelProductId);
  }

  String _getPriceForProduct(String productId) {
    final product = getProduct(productId);
    if (product == null) return "\$1.99";

    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers == null || offers.isEmpty) {
        return product.price;
      }

      final phases = offers.first.pricingPhases;

      for (var phase in phases) {
        if (phase.priceAmountMicros > 0) {
          return phase.formattedPrice;
        }
      }
    }

    return product.price;
  }

  double _getPriceValueForProduct(String productId) {
    final product = getProduct(productId);
    if (product == null) return 1.99;

    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers == null || offers.isEmpty) {
        return product.rawPrice;
      }

      final phases = offers.first.pricingPhases;

      for (var phase in phases) {
        if (phase.priceAmountMicros > 0) {
          return phase.priceAmountMicros / 1000000.0;
        }
      }
    }

    return product.rawPrice;
  }

  String getTrialText() {
    final product = getProduct(weeklyProductId);
    if (product == null) {
      // Fallback to remote config if product is not available
      final remoteConfig = RemoteConfigService();
      if (remoteConfig.salesConfig != null &&
          remoteConfig.salesConfig!.plans.isNotEmpty) {
        return remoteConfig.salesConfig!.plans.first['subtitle'] ?? "";
      }
      return "";
    }

    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers == null || offers.isEmpty) {
        // Fallback to remote config if no offers
        final remoteConfig = RemoteConfigService();
        if (remoteConfig.salesConfig != null &&
            remoteConfig.salesConfig!.plans.isNotEmpty) {
          return remoteConfig.salesConfig!.plans.first['subtitle'] ?? "";
        }
        return "";
      }

      final phases = offers.first.pricingPhases;

      // Check if there's a free trial phase
      try {
        final free = phases.firstWhere((p) => p.priceAmountMicros == 0);
        return "${free.billingPeriod.replaceAll('P', '').replaceAll('D', ' Days')} Free Trial";
      } catch (_) {
        // No free trial found, fallback to remote config
        final remoteConfig = RemoteConfigService();
        if (remoteConfig.salesConfig != null &&
            remoteConfig.salesConfig!.plans.isNotEmpty) {
          return remoteConfig.salesConfig!.plans.first['subtitle'] ?? "";
        }
      }
    }

    return "";
  }

  String getCreatorReelTrialText() {
    final product = getProduct(creatorReelProductId);
    if (product == null) return "3 Days Free Trial";

    if (product is GooglePlayProductDetails) {
      final offers = product.productDetails.subscriptionOfferDetails;
      if (offers == null || offers.isEmpty) return "3 Days Free Trial";

      final phases = offers.first.pricingPhases;
      try {
        final free = phases.firstWhere((p) => p.priceAmountMicros == 0);
        return "${free.billingPeriod.replaceAll('P', '').replaceAll('D', ' Days')} Free Trial";
      } catch (_) {
        return "3 Days Free Trial";
      }
    }
    return "3 Days Free Trial";
  }

  // ---------------- BUY ----------------
  Future<void> buyWeekly() async {
    await _buyProduct(weeklyProductId);
  }

  Future<void> buyCreatorReel() async {
    await _buyProduct(creatorReelProductId);
  }

  Future<void> _buyProduct(String productId) async {
    final product = getProduct(productId);

    if (product == null) {
      debugPrint("Product not found: $productId");
      return;
    }

    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  // ---------------- RESTORE ----------------
  Future<bool> restorePurchases() async {
    try {
      debugPrint("Restore Purchases: Starting...");

      bool hasRestoredPurchases = false;

      StreamSubscription<List<PurchaseDetails>>? tempSubscription;
      tempSubscription = _iap.purchaseStream.listen((purchases) {
        for (var purchase in purchases) {
          if (purchase.status == PurchaseStatus.restored) {
            debugPrint(
              "Restore Purchases: Found restored purchase - ${purchase.productID}",
            );
            hasRestoredPurchases = true;
          }
        }
      });

      await _iap.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await tempSubscription.cancel();

      debugPrint("Restore Purchases: Completed - Found: $hasRestoredPurchases");
      return hasRestoredPurchases;
    } catch (e) {
      debugPrint("Restore Purchases: Error - $e");
      return false;
    }
  }

  // ---------------- PURCHASE HANDLER ----------------
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      debugPrint("Purchase Status: ${purchase.status}");

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _grantPremium(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  // ---------------- PREMIUM UNLOCK ----------------
  Future<void> _grantPremium(PurchaseDetails purchase) async {
    debugPrint(
      "Purchase Token: ${purchase.verificationData.serverVerificationData}",
    );

    final prefs = await SharedPreferences.getInstance();

    if (purchase.productID == creatorReelProductId) {
      isPremiumPlus.value = true;
      await prefs.setBool("isPremiumPlus", true);
    } else {
      isPremium.value = true;
      await prefs.setBool("isPremium", true);
    }
  }

  // ---------------- LOCAL RESTORE ----------------
  Future<void> _loadPremiumFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool("isPremium") ?? false;
    isPremiumPlus.value = prefs.getBool("isPremiumPlus") ?? false;
  }

  // ---------------- VERIFY SUBSCRIPTION STATUS ----------------
  Future<void> _verifySubscriptionStatus() async {
    try {
      debugPrint("Verify Subscription: Starting...");

      if (!isPremium.value && !isPremiumPlus.value) {
        debugPrint(
          "Verify Subscription: User not premium, skipping verification.",
        );
        return;
      }

      bool hasActivePurchase = false;
      bool hasActivePremiumPlus = false;

      StreamSubscription<List<PurchaseDetails>>? tempSubscription;

      tempSubscription = _iap.purchaseStream.listen((purchases) {
        for (var purchase in purchases) {
          debugPrint(
            "Verify Subscription: Found purchase - ${purchase.productID}, Status: ${purchase.status}",
          );

          if (purchase.productID == weeklyProductId &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored)) {
            hasActivePurchase = true;
          }

          if (purchase.productID == creatorReelProductId &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored)) {
            hasActivePremiumPlus = true;
          }
        }
      });

      await _iap.restorePurchases();
      await Future.delayed(const Duration(seconds: 2));
      await tempSubscription.cancel();

      if (!hasActivePurchase && isPremium.value) {
        debugPrint(
          "Verify Subscription: No active subscription found for Remove Ads. Revoking premium status.",
        );
        await _revokePremium();
      }
      if (!hasActivePremiumPlus && isPremiumPlus.value) {
        debugPrint(
          "Verify Subscription: No active subscription found for Creator Reel. Revoking premium plus status.",
        );
        await _revokePremiumPlus();
      }
    } catch (e) {
      debugPrint("Verify Subscription: Error - $e");
    }
  }

  // ---------------- REVOKE PREMIUM ----------------
  Future<void> _revokePremium() async {
    isPremium.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isPremium", false);
    debugPrint("Premium status revoked.");
  }

  Future<void> _revokePremiumPlus() async {
    isPremiumPlus.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isPremiumPlus", false);
    debugPrint("Premium Plus status revoked.");
  }

  // ---------------- DISPOSE ----------------
  void dispose() {
    _subscription?.cancel();
  }
}
