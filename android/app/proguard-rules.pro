# Preserve attributes required for MediaPipe JNI stack inspection & Protobuf reflection
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# Preserve native JNI method names and caller stack traces
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Keep Google MediaPipe Tasks & Framework
-keep class com.google.mediapipe.** { *; }
-keepclassmembers class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# Prevent R8 method inlining on app's native classes
-keep class com.example.flt_kotlin_pose.** { *; }
-keepclassmembers class com.example.flt_kotlin_pose.** {
    <methods>;
    <fields>;
}

# Keep Protocol Buffers Lite classes & field names
-keep class com.google.protobuf.** { *; }
-keepclassmembers class com.google.protobuf.** { *; }
-keepclassmembers class * extends com.google.protobuf.GeneratedMessageLite {
    <fields>;
    public static ** valueOf(java.lang.String);
}
