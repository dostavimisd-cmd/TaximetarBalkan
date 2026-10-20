# R8/ProGuard pravila za release. Dart kod se obfuskuje odvojeno
# (flutter build --obfuscate --split-debug-info). Ovde čuvamo klase koje
# Android zove iz manifesta ili refleksijom, da ih R8 ne ukloni.

# Flutter engine i embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# flutter_foreground_task: servis se u manifestu navodi po punom imenu
-keep class com.pravera.flutter_foreground_task.** { *; }

# print_bluetooth_thermal (Bluetooth štampač)
-keep class **.print_bluetooth_thermal.** { *; }

# geolocator / permission_handler koriste callback-e i refleksiju
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# Play Core (ponekad referisan iz Flutter deferred components, nije korišćen)
-dontwarn com.google.android.play.core.**

# Čuvanje standardnih stvari koje R8 inače obrađuje, za svaki slučaj
-keepattributes *Annotation*
-keepclassmembers enum * { *; }
