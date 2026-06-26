# ProGuard rules for Google ML Kit Text Recognition
# Suppress missing class warnings for unused text recognition language scripts.
-dontwarn com.google.mlkit.vision.text.**

# --- flutter_local_notifications + Gson ---------------------------------------
# flutter_local_notifications serializes scheduled notifications with Gson.
# R8 must not strip generic signatures / the TypeToken machinery, or the app
# crashes with "TypeToken must be created with a type argument" when an alarm
# fires or on boot. (Only needed if minification is re-enabled, but harmless.)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.google.gson.** { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
