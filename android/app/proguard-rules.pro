-ignorewarnings

# Flutter Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.yousful.snapsweep.** { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }

# Google Play Services & ML Kit
-keep class com.google.android.gms.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.common.internal.safeparcel.SafeParcelable { *; }

# Preserve AndroidX and essential UI classes
-keep class androidx.annotation.Keep
-keep @androidx.annotation.Keep class * {*;}
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Preserve all annotations and essential attributes
-keepattributes Exceptions,InnerClasses,Signature,Deprecated,SourceFile,LineNumberTable,*Annotation*,EnclosingMethod

# Don't warn about optional/missing dependencies
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**
-dontwarn io.flutter.**
