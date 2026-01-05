# Firebase Remote Config - Instagram Login Flow Control

## Overview
Implemented Firebase Remote Config control for the Instagram login flow in the home screen. The feature allows you to dynamically enable or disable the Instagram login requirement without releasing a new app version.

## Changes Made

### 1. Updated `RemoteConfigService` (`lib/services/remote_config_service.dart`)
- **Added parsing logic** for the `is_insta_login_flow_enabled` flag in the `_parseConfigs()` method
- The flag is already defined in the defaults as `true` (login flow enabled by default)
- The service now properly reads and exposes this flag via the `isInstaLoginFlowEnabled` getter

### 2. Updated `HomeScreen` (`lib/screens/home_screen.dart`)
- **Added import** for `RemoteConfigService`
- **Modified `_processLinkNavigation()` method** to check the Firebase flag before showing login flow:
  - **If `is_insta_login_flow_enabled` is `true`**: Shows the Instagram login flow (existing behavior)
  - **If `is_insta_login_flow_enabled` is `false`**: Skips the login check entirely and proceeds directly to the API call for fetching posts

## How It Works

### Flow Diagram
```
User pastes Instagram link and clicks "Go"
    ↓
Check Firebase Remote Config flag: is_insta_login_flow_enabled
    ↓
    ├─ TRUE → Check if user is logged in
    │           ├─ Not logged in → Show Instagram login webview
    │           │                   ├─ Login successful → Proceed to API
    │           │                   └─ Login failed → Show error, stop
    │           └─ Already logged in → Proceed to API
    │
    └─ FALSE → Skip login check, proceed directly to API
                ↓
            Call download_media API
                ↓
            Show PreviewScreen with fetched media
```

## Firebase Console Configuration

### Setting Up the Flag
1. Go to Firebase Console → Remote Config
2. Find or create the parameter: `is_insta_login_flow_enabled`
3. Set the value:
   - `true` - Enable Instagram login flow (default)
   - `false` - Disable login flow, fetch posts directly

### Default Value
The default value is set to `true` in the code, ensuring the login flow is enabled if Firebase Remote Config fails to load or if the parameter is not set.

## Testing

### Test Case 1: Login Flow Enabled (is_insta_login_flow_enabled = true)
1. Set the Firebase flag to `true`
2. Paste an Instagram link
3. Click "Go"
4. **Expected**: Login screen appears if not logged in
5. After login, posts are fetched

### Test Case 2: Login Flow Disabled (is_insta_login_flow_enabled = false)
1. Set the Firebase flag to `false`
2. Paste an Instagram link
3. Click "Go"
4. **Expected**: Login screen is skipped, API is called directly
5. Posts are fetched without login requirement

## Benefits
- **Remote Control**: Toggle login requirement without app updates
- **A/B Testing**: Test different user flows
- **Quick Response**: Disable login if there are authentication issues
- **Flexibility**: Adapt to changing Instagram API requirements

## Notes
- The flag is cached for 12 hours (as per RemoteConfigService settings)
- Default behavior (if Remote Config fails) is to show the login flow
- The API call at `${_apiBaseUrl}download_media` remains unchanged
