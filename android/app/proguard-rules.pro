-keep class com.nativecodex.kabete2026eiteet.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}
-keep class * extends com.google.android.gms.maps.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
