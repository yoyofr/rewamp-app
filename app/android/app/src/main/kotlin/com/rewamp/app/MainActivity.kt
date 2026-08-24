package com.rewamp.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.window.SplashScreenView
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Extends AudioServiceActivity (instead of FlutterActivity) so audio_service can
// bind its media-browser service to this activity for lock-screen / notification
// media controls. Playback itself stays in the native C engine.
private const val ROUTE_TAG = "RewampRoute"

class MainActivity : AudioServiceActivity() {

    // Android 12+ plays a fade-out exit animation on the system splash icon,
    // and Flutter's first frame lands a beat later → the sun visibly fades out
    // then pops back in (the launch intro's frame-0). Hold the system splash
    // ON SCREEN until Flutter has actually displayed its first frame, then
    // remove it instantly (no fade) — the intro's identical sun is already
    // underneath, so the handoff is seamless.
    //
    // Ordering is NOT guaranteed between the exit-animation listener and
    // onFlutterUiDisplayed — either can fire first — so both paths check the
    // other's state, and a watchdog removes the splash after 4s no matter what
    // (never hard-lock on the splash).
    private var splashView: SplashScreenView? = null
    private var flutterUiReady = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { view ->
                if (flutterUiReady) {
                    view.remove()          // Flutter frame already up → cut, no fade
                } else {
                    splashView = view      // hold — removed in onFlutterUiDisplayed
                    mainHandler.postDelayed({ removeSplash() }, 4000)  // watchdog
                }
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Audio route picker — see showRouteChooser. Two dead ends before the
        // current shape: the Settings Output Switcher panel launches then
        // CRASHES inside com.android.settings on HyperOS/MIUI (their
        // SettingsPanelActivity, another process, nothing to catch); and the
        // androidx MediaRouteChooserDialog is CAST-oriented — "Caster sur",
        // empty spinner, local outputs never listed. What the media-center
        // chip opens is SystemUI's own Media Output dialog, and THAT is what
        // showRouteChooser now requests.
        // Keep the display awake while a visualizer is up (see ScreenWakelock).
        // The window flag rather than a WakeLock: no permission, and it is
        // scoped to this activity - backgrounding the app drops it by
        // construction, so a missed release can never keep a phone lit.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rewamp/wakelock")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") { result.notImplemented(); return@setMethodCallHandler }
                val on = call.argument<Boolean>("on") ?: false
                runOnUiThread {
                    if (on) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rewamp/route_picker")
            .setMethodCallHandler { call, result ->
                if (call.method != "show") { result.notImplemented(); return@setMethodCallHandler }
                result.success(showRouteChooser())
            }
    }

    /** True if something was shown. SystemUI dialog → Settings panel → BT settings. */
    private fun showRouteChooser(): Boolean {
        // 1) SystemUI's Media Output dialog — the SAME dialog the media-center /
        // notification chip opens: instant, lists the real local outputs
        // (speaker, wired, Bluetooth) bound to our active MediaSession.
        // Hidden-but-stable broadcast since Android 11. The androidx
        // MediaRouteChooserDialog tried before was CAST-oriented: it showed
        // "Caster sur", scanned for cast devices and never listed a local
        // output — an empty spinner on every phone.
        // Resolved before firing so an OEM build without the receiver falls
        // through instead of blind-firing a broadcast nobody answers.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val out = Intent("com.android.systemui.action.LAUNCH_MEDIA_OUTPUT_DIALOG")
                    .setPackage("com.android.systemui")
                    .putExtra("package_name", packageName)
                val handlers = packageManager.queryBroadcastReceivers(out, 0)
                if (handlers.isNotEmpty()) {
                    sendBroadcast(out)
                    Log.i(ROUTE_TAG, "SystemUI media-output dialog requested")
                    return true
                }
                Log.i(ROUTE_TAG, "no SystemUI media-output receiver — falling back")
            } catch (t: Throwable) {
                Log.w(ROUTE_TAG, "SystemUI media-output launch failed", t)
            }
        }
        // 2) Settings Output Switcher panel. Caveat: always LAUNCHES, then
        // crashes inside com.android.settings on some HyperOS/MIUI builds
        // (their SettingsPanelActivity, not us — nothing to catch here).
        val panel = Intent("com.android.settings.panel.action.MEDIA_OUTPUT")
            .putExtra("com.android.settings.panel.extra.PACKAGE_NAME", packageName)
        try {
            startActivity(panel)
            return true
        } catch (_: Exception) {
            return try {
                startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        flutterUiReady = true
        removeSplash()
    }

    private fun removeSplash() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashView?.remove()
            splashView = null
        }
    }
}
