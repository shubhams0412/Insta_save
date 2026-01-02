# ==============================================================================
# 1. FLUTTER & PLUGIN BRIDGE PROTECTION
# ==============================================================================

# Protect the Flutter engine and internal embedding
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Protect the plugin registration and generated code
-keep class io.flutter.app.FlutterApplication { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-keep public class * extends io.flutter.embedding.engine.plugins.FlutterPlugin
-keep class io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }

# General Pigeon protection (Fixes the "Unable to establish connection" error)
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }

# ==============================================================================
# 2. SHARED PREFERENCES 2.3.0+ (DataStore & Async API)
# ==============================================================================

# Keep the new SharedPreferencesAsync and WithCache bridge (Pigeon)
-keep class dev.flutter.pigeon.shared_preferences_android.** { *; }
-keep interface dev.flutter.pigeon.shared_preferences_android.** { *; }

# Protect the implementation for DataStore backend
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesAsyncAndroid { *; }
-keep class io.flutter.plugins.sharedpreferences.SharedPreferencesAsyncAndroidOptions { *; }

# Protect the underlying Jetpack DataStore library
-keep class androidx.datastore.** { *; }
-dontwarn androidx.datastore.**

# Legacy support for SharedPreferences (sometimes required for migration)
-keep class io.flutter.plugins.sharedpreferences.LegacySharedPreferencesPlugin { *; }

# ==============================================================================
# 3. FIREBASE & GOOGLE SERVICES
# ==============================================================================

# Firebase Core Pigeon-generated classes (CRITICAL for channel communication)
-keep class io.flutter.plugins.firebase.core.** { *; }
-keep class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore { *; }
-keep class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$* { *; }
-keep interface io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$* { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePlugin { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebaseCoreRegistrar { *; }
-keep class io.flutter.plugins.firebase.core.FlutterFirebasePluginRegistry { *; }

# Firebase SDK
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Remote Config
-keep class com.google.firebase.remoteconfig.** { *; }

# Keep all Pigeon-generated message classes (pattern matching)
-keep class **.*Messages { *; }
-keep class **.*Messages$* { *; }
-keep class **.Generated* { *; }
-keep class **.Generated*$* { *; }
-keep interface **.Generated*$* { *; }

# Firebase initialization
-keep class com.google.firebase.provider.FirebaseInitProvider { *; }
-keep class com.google.firebase.FirebaseOptions { *; }
-keep class com.google.firebase.FirebaseApp { *; }

# Method channel codecs (CRITICAL)
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }
-keep interface io.flutter.plugin.common.BinaryMessenger$* { *; }

-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Core Pigeon bridge (dev.flutter.pigeon namespace)
-keep class dev.flutter.pigeon.firebase_core_platform_interface.** { *; }
-keep interface dev.flutter.pigeon.firebase_core_platform_interface.** { *; }

# ==========================================================
# CRITICAL: R8 Full-mode specific rules for Pigeon channels
# ==========================================================

# Keep all inner classes with their static INSTANCE fields (codecs)
-keepclassmembers class ** {
    public static ** INSTANCE;
}

# Keep all implementations of MessageCodec
-keep class * extends io.flutter.plugin.common.StandardMessageCodec { *; }
-keepclassmembers class * extends io.flutter.plugin.common.StandardMessageCodec {
    <methods>;
    <fields>;
}

# Keep classes implementing Result callback
-keep interface io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$Result { *; }
-keep class * implements io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$Result { *; }

# Prevent R8 from merging or outlining Pigeon-generated classes
-keep,allowobfuscation,allowshrinking class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$FirebaseCoreHostApiCodec
-keepclassmembers class io.flutter.plugins.firebase.core.GeneratedAndroidFirebaseCore$FirebaseCoreHostApiCodec {
    public static final ** INSTANCE;
    *;
}

# Keep the channel name strings
-keepclassmembers class * {
    @androidx.annotation.NonNull java.lang.String *FirebaseCoreHostApi*;
}

# ==============================================================================
# 4. PROJECT & SYSTEM SPECIFICS
# ==============================================================================

# Replace with your actual package name if different
-keep class com.example.insta_save.** { *; }
-keep class * extends io.flutter.embedding.android.FlutterActivity
-keep class * extends io.flutter.embedding.android.FlutterFragmentActivity
-keep class androidx.lifecycle.DefaultLifecycleObserver { *; }

# Preserve attributes for library functionality
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses, SourceFile, LineNumberTable
-ignorewarnings
-renamesourcefileattribute SourceFile

# ==============================================================================
# 5. FFMPEG KIT
# ==============================================================================
# Fix "NoClassDefFoundError: com.antonkarpenko.ffmpegkit.FFmpegKitConfig"
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keep class com.arthenica.ffmpegkit.** { *; }

# Protect JNI callbacks
-keep class * extends com.arthenica.ffmpegkit.AbstractSession { *; }
-keep class * extends com.arthenica.ffmpegkit.AbstractLog { *; }
-keep class * extends com.arthenica.ffmpegkit.AbstractStatistics { *; }

# Keep native library loading code
-keep class com.arthenica.ffmpegkit.AbiDetect { *; }
-keep class com.arthenica.ffmpegkit.FFmpegKitConfig { *; }

# Prevent warning spam
-dontwarn com.antonkarpenko.ffmpegkit.**
-dontwarn com.arthenica.ffmpegkit.**