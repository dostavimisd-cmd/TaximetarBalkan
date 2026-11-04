package rs.taksimetar.balkan

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rs.taksimetar.balkan/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    // Sistemski spisak aplikacija sa optimizacijom baterije; ne traži
                    // posebnu dozvolu (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS se ne koristi).
                    "openBatterySettings" -> try {
                        startActivity(
                            Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                    // Signal vozaču (start/pauza/kraj): prava vibracija, jača od
                    // vibracije dodira i ne zavisi od tog podešavanja telefona.
                    "vibrate" -> result.success(vibrate(call.argument<List<Int>>("pattern")))
                    else -> result.notImplemented()
                }
            }
    }

    /// pattern: pauza, vibracija, pauza, vibracija… u ms; false ako nije moguće.
    private fun vibrate(pattern: List<Int>?): Boolean {
        if (pattern.isNullOrEmpty()) return false
        return try {
            val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= 31) {
                (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vibrator.hasVibrator()) return false
            val timings = pattern.map { it.toLong() }.toLongArray()
            when {
                Build.VERSION.SDK_INT >= 33 -> vibrator.vibrate(
                    VibrationEffect.createWaveform(timings, -1),
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
                Build.VERSION.SDK_INT >= 26 ->
                    vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
                else -> @Suppress("DEPRECATION") vibrator.vibrate(timings, -1)
            }
            true
        } catch (e: Exception) {
            false
        }
    }
}
