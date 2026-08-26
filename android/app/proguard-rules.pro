# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Play Core
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# OpenAI/Gemini HTTP
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep model classes
-keep class com.neharohilla.calorietracker.models.** { *; }
