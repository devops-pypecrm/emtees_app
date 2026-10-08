# Starting point for when R8 minification is turned back on in build.gradle.kts
# (isMinifyEnabled/isShrinkResources) — verify against a real device run first.

# Jitsi Meet SDK — uses reflection/JNI internally.
-keep class org.jitsi.** { *; }
-keep class com.oney.WebRTCModule.** { *; }
-dontwarn org.jitsi.**

# socket.io-client / engine.io — reflection-based JSON handling.
-keep class io.socket.** { *; }
-keep class org.json.** { *; }
-dontwarn io.socket.**

# General Flutter plugin safety.
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
