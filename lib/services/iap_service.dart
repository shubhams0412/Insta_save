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

  static String weeklyProductId =
      RemoteConfigService().salesConfig?.plans.first['productId'] ??
      "com.video.downloader.saver.manager.week";

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
    final response = await _iap.queryProductDetails({weeklyProductId});

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
    final product = getProduct(weeklyProductId);
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

  double getWeeklyPriceValue() {
    final product = getProduct(weeklyProductId);
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

  // ---------------- BUY ----------------
  Future<void> buyWeekly() async {
    final product = getProduct(weeklyProductId);

    if (product == null) {
      debugPrint("Product not found");
      return;
    }

    final param = PurchaseParam(productDetails: product);

    await _iap.buyNonConsumable(purchaseParam: param);
  }

  // ---------------- RESTORE ----------------
  Future<bool> restorePurchases() async {
    try {
      debugPrint("Restore Purchases: Starting...");

      // Track if any purchases were restored
      bool hasRestoredPurchases = false;

      // Listen to purchase stream temporarily
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

      // Trigger restore
      await _iap.restorePurchases();

      // Wait a bit for the stream to process
      await Future.delayed(const Duration(seconds: 2));

      // Cancel temp subscription
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
    final token = purchase.verificationData.serverVerificationData;

    debugPrint("Purchase Token: $token");

    isPremium.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isPremium", true);
  }

  // ---------------- LOCAL RESTORE ----------------
  Future<void> _loadPremiumFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium.value = prefs.getBool("isPremium") ?? false;
  }

  // ---------------- VERIFY SUBSCRIPTION STATUS ----------------
  Future<void> _verifySubscriptionStatus() async {
    try {
      debugPrint("Verify Subscription: Starting...");

      // Only verify if user was previously marked as premium
      if (!isPremium.value) {
        debugPrint(
          "Verify Subscription: User not premium, skipping verification.",
        );
        return;
      }

      bool hasActivePurchase = false;

      // Create a temporary subscription to listen for restored purchases
      StreamSubscription<List<PurchaseDetails>>? tempSubscription;

      tempSubscription = _iap.purchaseStream.listen((purchases) {
        for (var purchase in purchases) {
          debugPrint(
            "Verify Subscription: Found purchase - ${purchase.productID}, Status: ${purchase.status}",
          );

          // Check if this is our subscription product and it's active
          if (purchase.productID == weeklyProductId &&
              (purchase.status == PurchaseStatus.purchased ||
                  purchase.status == PurchaseStatus.restored)) {
            hasActivePurchase = true;
            debugPrint("Verify Subscription: Active subscription found!");
          }
        }
      });

      // Trigger restore to check for active purchases
      await _iap.restorePurchases();

      // Wait a bit for the stream to process
      await Future.delayed(const Duration(seconds: 2));

      // Cancel temp subscription
      await tempSubscription.cancel();

      // If no active purchase found, revoke premium status
      if (!hasActivePurchase) {
        debugPrint(
          "Verify Subscription: No active subscription found. Revoking premium status.",
        );
        await _revokePremium();
      } else {
        debugPrint("Verify Subscription: Active subscription verified!");
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

  // ---------------- DISPOSE ----------------
  void dispose() {
    _subscription?.cancel();
  }
}
