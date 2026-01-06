# Firebase Remote Config - Terms and Privacy Links

## Overview
Implemented Firebase Remote Config management for Terms of Use and Privacy Policy links in the Sales Screen. The links can now be updated remotely through Firebase Console without requiring an app update.

## Changes Made

### 1. Updated `SalesConfig` Model (`lib/models/remote_config_models.dart`)
- **Added fields**:
  - `privacyUrl`: String field for Privacy Policy URL
  - `termsUrl`: String field for Terms of Use URL
- **Updated `fromJson` factory**: Added parsing logic with fallback defaults
  - Default Privacy URL: `https://turbofast.io/privacy/`
  - Default Terms URL: `https://turbofast.io/terms/`

### 2. Updated `RemoteConfigService` (`lib/services/remote_config_service.dart`)
- **Added to `sales_screen_config` defaults**:
  ```json
  {
    "privacyUrl": "https://turbofast.io/privacy/",
    "termsUrl": "https://turbofast.io/terms/"
  }
  ```

### 3. Updated `SalesScreen` (`lib/screens/sales_screen.dart`)
- **Replaced hardcoded URLs** with Firebase Remote Config values
- **Privacy Policy**: Now uses `_config?.privacyUrl ?? 'https://turbofast.io/privacy/'`
- **Terms of Use**: Now uses `_config?.termsUrl ?? 'https://turbofast.io/terms/'`

## Firebase Console Configuration

### Parameter: `sales_screen_config`

The existing `sales_screen_config` parameter now includes two additional fields:

```json
{
  "title": {
    "text": "Instant Saver Premium",
    "textSize": 28,
    "textColor": "#FFFFFF"
  },
  "subTitle": {
    "text": "No commitment, cancel anytime",
    "textSize": 16,
    "textColor": "#B3FFFFFF"
  },
  "featuresStyle": {"textSize": 15, "textColor": "#FFFFFF"},
  "plansStyle": {"textSize": 18, "textColor": "#FFFFFF"},
  "features": [
    {"text": "Unlimited Reposts"},
    {"text": "Stories & Highlights"},
    {"text": "Photos Posts & Videos"},
    {"text": "100% Ad-Free Experience"},
    {"text": "Add Directly from the Gallery"}
  ],
  "plans": [
    {
      "title": "Annual",
      "subtitle": "3-day free trial",
      "price": "$19.99",
      "originalPrice": "$32.00",
      "badgeText": "Best - $0.38 / week"
    },
    {
      "title": "Monthly",
      "subtitle": "3-day free trial",
      "price": "$9.99"
    }
  ],
  "privacyUrl": "https://turbofast.io/privacy/",
  "termsUrl": "https://turbofast.io/terms/"
}
```

## How to Update Links

### Via Firebase Console:
1. Go to **Firebase Console** → **Remote Config**
2. Find parameter: `sales_screen_config`
3. Update the JSON to include or modify:
   ```json
   {
     ...existing config...,
     "privacyUrl": "https://your-new-privacy-url.com",
     "termsUrl": "https://your-new-terms-url.com"
   }
   ```
4. Publish changes

### Default Behavior:
- If Firebase Remote Config fails to load or the URLs are not set, the app will use the default URLs:
  - Privacy: `https://turbofast.io/privacy/`
  - Terms: `https://turbofast.io/terms/`

## User Flow

```
User taps "Privacy Policy" or "Terms of Use" in Sales Screen
    ↓
App checks Firebase Remote Config for URLs
    ↓
    ├─ Config loaded → Use privacyUrl/termsUrl from Firebase
    └─ Config failed → Use default URLs (https://turbofast.io/...)
    ↓
Open WebViewScreen with the URL
```

## Benefits
- **Remote Control**: Update legal links without app updates
- **Compliance**: Quickly update links if legal requirements change
- **Flexibility**: Different URLs for different app versions or regions (via Firebase conditions)
- **Consistency**: Links managed in the same place as other sales screen content

## Testing

### Test Case 1: Default URLs
1. Ensure Firebase Remote Config is working
2. Open Sales Screen
3. Tap "Privacy Policy"
4. **Expected**: Opens `https://turbofast.io/privacy/`
5. Tap "Terms of Use"
6. **Expected**: Opens `https://turbofast.io/terms/`

### Test Case 2: Custom URLs via Firebase
1. Update `sales_screen_config` in Firebase Console with custom URLs
2. Wait for config to sync (or force refresh)
3. Open Sales Screen
4. Tap links
5. **Expected**: Opens the custom URLs from Firebase

### Test Case 3: Fallback Behavior
1. Disable network or Firebase Remote Config
2. Open Sales Screen
3. Tap links
4. **Expected**: Opens default URLs (https://turbofast.io/...)

## Notes
- The URLs are part of the existing `sales_screen_config` parameter
- No new Firebase parameters were created
- The implementation includes null-safety with fallback defaults
- Links open in the existing `WebViewScreen` component
