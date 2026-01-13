# In-App Purchase Troubleshooting Guide

## Issue: "The item you were attempting to purchase could not be found"

This error typically occurs when the product ID is not properly configured in Google Play Console or the app isn't set up correctly for IAP testing.

## Changes Made

### 1. Enhanced IAP Service (`lib/services/iap_service.dart`)
- ✅ Added comprehensive debug logging throughout the service
- ✅ Added error callback mechanism (`onPurchaseError`) for UI feedback
- ✅ Enhanced error handling in `buyProduct()` method
- ✅ Added detailed product information logging in `fetchProducts()`
- ✅ Added store availability checks

### 2. Updated Sales Screen (`lib/screens/sales_screen.dart`)
- ✅ Integrated error callback to show user-friendly error messages
- ✅ Error messages displayed in red SnackBar with 5-second duration

## Debug Logs to Check

When you run the app, check the console for these logs:

### On App Start:
```
IAP: Initializing In-App Purchase service...
IAP: Store availability: true/false
IAP: Fetching products...
IAP: Querying product IDs: {com.video.downloader.saver.manager.week}
IAP: Products found: X
```

### If Product Not Found:
```
IAP: ⚠️ Products not found: [com.video.downloader.saver.manager.week]
IAP: ⚠️ Please check:
IAP:   1. Product ID matches Google Play Console exactly
IAP:   2. Product is active in Google Play Console
IAP:   3. App is properly signed and configured
IAP:   4. Testing with a valid test account
```

### If Product Found:
```
IAP: Product: com.video.downloader.saver.manager.week
IAP:   Title: [Product Title]
IAP:   Description: [Product Description]
IAP:   Price: $X.XX
```

### On Purchase Attempt:
```
IAP: Attempting to purchase product: com.video.downloader.saver.manager.week
IAP: Product found: com.video.downloader.saver.manager.week - [Title]
IAP: Product price: $X.XX
IAP: Initiating purchase...
IAP: Purchase initiated: true
```

## Checklist for Google Play Console

### 1. Product Configuration
- [ ] Navigate to **Monetize** → **In-app products** in Google Play Console
- [ ] Verify product ID is exactly: `com.video.downloader.saver.manager.week`
- [ ] Product status must be **Active**
- [ ] Product type should be **Subscription** (not one-time purchase)
- [ ] Price is properly set

### 2. App Configuration
- [ ] App must be published to at least **Internal Testing** track
- [ ] Your Google account must be added as a **License tester** in:
  - **Setup** → **License testing**
- [ ] The app version you're testing must match the version uploaded to Play Console
- [ ] App must be signed with the same keystore as the uploaded APK/AAB

### 3. Testing Account Setup
- [ ] Add your test Gmail account to license testers
- [ ] Use the same Gmail account on your test device
- [ ] Wait 15-30 minutes after adding the account (propagation time)
- [ ] Clear Google Play Store cache and data if needed

### 4. App Signing
- [ ] Verify the app is signed correctly:
  ```bash
  # Check the signing certificate
  keytool -list -v -keystore /path/to/your/keystore.jks
  ```
- [ ] If using Play App Signing, download the deployment certificate from Play Console
- [ ] Ensure the SHA-1 fingerprint matches what's in Play Console

## Common Issues & Solutions

### Issue 1: Product ID Mismatch
**Symptom:** "Product not found" error
**Solution:** 
- Double-check the product ID in `iap_service.dart` (line 21-22)
- Current ID: `com.video.downloader.saver.manager.week`
- Must match EXACTLY with Google Play Console

### Issue 2: Product Not Active
**Symptom:** Product shows in console but not available in app
**Solution:**
- Ensure product status is "Active" in Play Console
- Products in "Draft" or "Inactive" state won't be available

### Issue 3: App Not in Testing Track
**Symptom:** IAP not available even with correct product ID
**Solution:**
- Upload app to Internal Testing track minimum
- Add your Google account as a tester
- Install app from Play Store (not direct APK install)

### Issue 4: Wrong App Signature
**Symptom:** Products not loading, IAP unavailable
**Solution:**
- Ensure app is signed with production keystore
- For testing, use the same keystore that was uploaded to Play Console
- If using Play App Signing, use the upload key

### Issue 5: Cache Issues
**Symptom:** Changes not reflecting
**Solution:**
```bash
# Clear app data
adb shell pm clear com.video.downloader.saver.manager

# Clear Play Store cache
adb shell pm clear com.android.vending

# Reinstall app
flutter clean
flutter pub get
flutter run --release
```

## Testing Steps

### Step 1: Check Logs
1. Run the app in debug mode
2. Navigate to Sales Screen
3. Check console for IAP initialization logs
4. Verify products are loaded successfully

### Step 2: Test Purchase Flow
1. Tap "Continue" button
2. Check console for purchase attempt logs
3. If error occurs, note the exact error message
4. Check if error SnackBar appears with detailed message

### Step 3: Verify Product Details
1. Check if the price displays correctly on the plan card
2. If showing fallback price ($4.99), product wasn't loaded
3. If showing actual price, product is loaded correctly

## Product ID Reference

Current product ID in code:
```dart
static const String weeklyProductId = 'com.video.downloader.saver.manager.week';
```

This must match exactly in:
- ✅ `lib/services/iap_service.dart`
- ✅ Google Play Console → Monetize → In-app products

## Next Steps

1. **Run the app** and check the debug logs
2. **Copy the logs** from app startup to purchase attempt
3. **Verify in Google Play Console**:
   - Product exists and is active
   - App is in testing track
   - Your account is added as tester
4. **Share the logs** if issue persists

## Additional Resources

- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [Flutter in_app_purchase Package](https://pub.dev/packages/in_app_purchase)
- [Testing In-App Purchases](https://developer.android.com/google/play/billing/test)

## Contact Information

If the issue persists after following this guide:
1. Share the complete debug logs from app launch to purchase attempt
2. Confirm all checklist items are completed
3. Provide screenshots from Google Play Console showing product configuration
