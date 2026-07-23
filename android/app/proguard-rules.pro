# Keep Google MediaPipe Tasks & Framework reflection fields
-keep class com.google.mediapipe.** { *; }
-keepclassmembers class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Keep Protocol Buffers Lite classes & field names (preserves reflection fields like platform_)
-keep class com.google.protobuf.** { *; }
-keepclassmembers class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
    public static ** valueOf(java.lang.String);
}

# Keep app's native Kotlin plugin & PlatformView classes
-keep class com.example.flt_kotlin_pose.** { *; }
-keepclassmembers class com.example.flt_kotlin_pose.** { *; }
