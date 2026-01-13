# Google Play Console Setup Checklist

## Current Status

✅ **Product is being found** - The app successfully queries and finds the product  
✅ **Price is correct** - Shows ₹180.00 (not "Free")  
✅ **Purchase initiates** - Google Play billing dialog opens  
❌ **Purchase fails** - Error: `BillingResponse.itemUnavailable`

## Error Details

```
IAP: ❌ Purchase Error: BillingResponse.itemUnavailable
IAP: Error code: purchase_error
IAP: Error message: BillingResponse.itemUnavailable
```

This error means Google Play cannot complete the purchase because the product is not properly configured or accessible.

## Required Actions in Google Play Console

### Step 1: Verify Product Configuration

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **Instant Save** (com.video.downloader.saver.manager.free.allvideodownloader)
3. Navigate to **Monetize** → **Subscriptions** (or **In-app products**)
4. Find product: `com.video.downloader.saver.manager.week`

**Check the following:**

- [ ] Product ID is exactly: `com.video.downloader.saver.manager.week`
- [ ] Product status is **Active** (not Draft or Inactive)
- [ ] Product type is **Subscription** (weekly)
- [ ] Price is set to ₹180.00
- [ ] Product has a title and description
- [ ] Billing period is set to **1 week**

**If product is in Draft:**
1. Click on the product
2. Fill in all required fields
3. Click **Activate** or **Save and Activate**

### Step 2: Publish App to Testing Track

The app MUST be published to at least Internal Testing for IAP to work.

1. Go to **Release** → **Testing** → **Internal testing**
2. Check if there's an active release

**If NO active release:**
1. Click **Create new release**
2. Upload your signed APK/AAB
3. Add release notes
4. Click **Review release**
5. Click **Start rollout to Internal testing**

**If release exists:**
- [ ] Verify the release is **Available** (not Draft)
- [ ] Check the version code matches your current build
- [ ] Ensure the release was rolled out (not just saved)

### Step 3: Add License Testers

1. Go to **Setup** → **License testing**
2. Under **License testers**, add your Gmail account
3. Click **Save changes**

**Important:**
- Use the EXACT Gmail account that's signed in on your test device
- Wait 15-30 minutes after adding for changes to propagate
- The account must be added BEFORE testing

**To verify:**
- [ ] Your Gmail is in the "License testers" list
- [ ] The account has been saved (not just typed)
- [ ] You've waited at least 15 minutes since adding

### Step 4: Verify App Signing

1. Go to **Setup** → **App signing**
2. Check if **Play App Signing** is enabled

**If Play App Signing is ENABLED:**
- [ ] Download the **App signing certificate** (SHA-1)
- [ ] Verify it matches the certificate used in Firebase/Google Services
- [ ] Use the **Upload certificate** for building your APK

**If Play App Signing is NOT enabled:**
- [ ] Ensure you're using the same keystore for all builds
- [ ] Verify the SHA-1 matches what's registered

### Step 5: Install from Play Store

For IAP to work properly during testing:

1. **Uninstall** the app if installed via `flutter run` or direct APK
2. Go to **Internal testing** track in Play Console
3. Copy the **Testing link** (looks like: `https://play.google.com/apps/internaltest/...`)
4. Open the link on your test device
5. Accept to become a tester
6. Install the app from Play Store
7. Test the purchase

**Why this matters:**
- Direct APK installs may not have proper Play Store integration
- Testing link ensures the app is properly linked to your Play Console account

## Quick Verification Commands

### Check App Signature
```bash
# Get the SHA-1 of your installed app
adb shell pm list packages -f | grep "com.video.downloader.saver.manager"
```

### Check if App is from Play Store
```bash
# Check installer package
adb shell pm list packages -i | grep "com.video.downloader.saver.manager"
# Should show: installer=com.android.vending
```

## Common Issues & Solutions

### Issue: Product shows "Free" in testing
**Solution:** ✅ Already fixed! The app now correctly selects the paid product (₹180.00)

### Issue: "Item unavailable" error
**Possible causes:**
1. Product not activated in Play Console → **Activate the product**
2. App not in testing track → **Publish to Internal testing**
3. Account not added as tester → **Add to License testers**
4. App not installed from Play Store → **Install via testing link**
5. Changes not propagated → **Wait 15-30 minutes**

### Issue: Purchase dialog doesn't appear
**Solution:** Check if IAP is available:
- Look for log: `IAP: Store availability: true`
- If false, Google Play Services may not be installed

### Issue: "You already own this item"
**Solution:** 
1. Go to Play Store → Account → Payments & subscriptions
2. Find and cancel the test subscription
3. Wait a few minutes
4. Try again

## Testing Flow

1. **Clear app data:**
   ```bash
   adb shell pm clear com.video.downloader.saver.manager.free.allvideodownloader
   ```

2. **Launch app and navigate to Sales Screen**

3. **Check logs for:**
   ```
   IAP: Products found: 2
   IAP: Selected paid product: ₹180.00
   ```

4. **Tap Continue button**

5. **Expected behavior:**
   - Google Play billing dialog appears
   - Shows ₹180.00 (or "Free" for test purchases)
   - Can complete test purchase

6. **If error occurs:**
   - Check the error message in SnackBar
   - Review logs for specific error code
   - Follow troubleshooting steps above

## Current App Configuration

**Product ID:** `com.video.downloader.saver.manager.week`  
**Package Name:** `com.video.downloader.saver.manager.free.allvideodownloader`  
**Price:** ₹180.00 per week  
**Product Type:** Subscription (Weekly)

## Next Steps

1. ✅ **Verify product is Active** in Google Play Console
2. ✅ **Ensure app is in Internal testing** track
3. ✅ **Add your Gmail as license tester**
4. ✅ **Install app from testing link** (not direct APK)
5. ✅ **Wait 15-30 minutes** for changes to propagate
6. ✅ **Test purchase again**

## Support Resources

- [Google Play Billing Documentation](https://developer.android.com/google/play/billing)
- [Test In-App Purchases](https://developer.android.com/google/play/billing/test)
- [Subscription Testing](https://support.google.com/googleplay/android-developer/answer/6062777)

---

**Note:** The code changes have been successfully implemented. The remaining issue is purely a Google Play Console configuration problem, not a code issue.
