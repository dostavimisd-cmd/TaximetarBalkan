package rs.taksimetar.balkan

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Glasovni unos adrese: rezultat stiže u onActivityResult.
    private var pendingVoice: MethodChannel.Result? = null
    private val voiceRequest = 4711

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
                    // Sistemski glasovni unos (onaj koji je podešen na telefonu, npr. Google).
                    "voiceInput" -> startVoice(call.argument<String>("language"), result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startVoice(language: String?, result: MethodChannel.Result) {
        if (pendingVoice != null) {
            result.success(null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        if (!language.isNullOrEmpty()) intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
        try {
            pendingVoice = result
            @Suppress("DEPRECATION")
            startActivityForResult(intent, voiceRequest)
        } catch (e: Exception) {
            pendingVoice = null
            result.error("unavailable", "Glasovni unos nije dostupan na ovom telefonu.", null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != voiceRequest) return
        val text = if (resultCode == RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else null
        pendingVoice?.success(text)
        pendingVoice = null
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
