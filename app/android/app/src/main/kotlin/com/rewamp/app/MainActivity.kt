package com.rewamp.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.provider.OpenableColumns
import android.util.Log
import android.window.SplashScreenView
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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

    // ── Fichiers ouverts DEPUIS L'EXTÉRIEUR (« Ouvrir avec », partage) ───────
    //
    // Chemins qu'Android nous a donnés et que Dart n'a pas encore ramassés.
    //
    // Ce tampon EST le mécanisme, comme sur Apple. L'intention arrive dans
    // `onCreate`, pendant que le moteur Flutter monte encore et bien avant
    // qu'un auditeur Dart existe: un message envoyé là tombe dans le vide et le
    // fichier est perdu. Donc on ne POUSSE jamais — on accumule, Dart TIRE avec
    // `takePending`, et `filesAvailable` n'est qu'un coup de coude pour le cas
    // « l'app tournait déjà ».
    private val pendingOpen = mutableListOf<String>()
    private var openFilesChannel: MethodChannel? = null

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
        // APRÈS super: c'est lui qui construit le moteur, donc le canal.
        handleOpenIntent(intent)
    }

    /** L'app tournait déjà: Android relivre par ici. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOpenIntent(intent)
    }

    private fun handleOpenIntent(intent: Intent?) {
        if (intent == null) return
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND -> listOfNotNull(
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: emptyList()
            }
            else -> emptyList()
        }
        if (uris.isEmpty()) return
        var added = false
        for (uri in uris) {
            val path = materialise(uri) ?: continue
            pendingOpen.add(path)
            added = true
        }
        if (added) openFilesChannel?.invokeMethod("filesAvailable", null)
    }

    /**
     * Recopie l'URI dans notre bac à sable et rend le CHEMIN.
     *
     * ⚠️ La copie est une nécessité, pas une précaution: nos décodeurs sont en C
     * et ouvrent un chemin de fichier — on ne peut pas leur donner un
     * `content://`, et la permission de lecture accordée à l'intention ne
     * survit pas à l'activité de toute façon.
     *
     * ⚠️ Le NOM compte autant que le contenu: tout le routage de format part de
     * l'extension, et un `content://` n'en a pas. On demande donc le
     * `DISPLAY_NAME` au fournisseur — le dernier segment du chemin est un
     * identifiant opaque chez la plupart d'entre eux (« document/1234 »), pas un
     * nom de fichier.
     */
    private fun materialise(uri: Uri): String? {
        val name = displayName(uri) ?: uri.lastPathSegment ?: return null
        val dir = File(filesDir, "opened").apply { mkdirs() }
        val dest = File(dir, name.substringAfterLast('/'))
        return try {
            contentResolver.openInputStream(uri).use { input ->
                if (input == null) return null
                dest.outputStream().use { input.copyTo(it) }
            }
            dest.absolutePath
        } catch (t: Throwable) {
            Log.w(ROUTE_TAG, "ouverture externe: copie impossible pour $uri", t)
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME),
                                  null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
            }
        } catch (_: Throwable) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // ⚠️ `super` D'ABORD, et toujours: les greffons Flutter (file_picker
        // entre autres) reçoivent LEURS résultats par ce même point d'entrée.
        super.onActivityResult(requestCode, resultCode, data)
        SafFolderImport.onActivityResult(requestCode, resultCode, data)
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

        // Fichiers ouverts depuis l'extérieur — voir `pendingOpen`.
        val openCh = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, "rewamp/open_files")
        openCh.setMethodCallHandler { call, result ->
            if (call.method != "takePending") { result.notImplemented(); return@setMethodCallHandler }
            // Passation ATOMIQUE: rendre et vider d'un seul geste.
            val out = pendingOpen.toList()
            pendingOpen.clear()
            result.success(out)
        }
        openFilesChannel = openCh
        if (pendingOpen.isNotEmpty()) openCh.invokeMethod("filesAvailable", null)

        // Import d'un DOSSIER par le Storage Access Framework — voir
        // SafFolderImport pour pourquoi le sélecteur du greffon ne peut pas
        // marcher ici (chemin brut + aucune permission de stockage).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                SafFolderImport.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> SafFolderImport.pick(this, result)
                    "copyTree" -> {
                        val uri = call.argument<String>("uri")
                        val dest = call.argument<String>("dest")
                        if (uri == null || dest == null) {
                            result.error("bad_args", "uri/dest manquants", null)
                        } else {
                            // Hors du fil principal: un dossier de plusieurs
                            // centaines de modules bloquerait l'UI, et l'ANR
                            // arriverait avant la fin de la copie.
                            Thread {
                                val out = try {
                                    SafFolderImport.copyTree(
                                        this, Uri.parse(uri), dest)
                                } catch (e: Exception) {
                                    Log.w(ROUTE_TAG, "copyTree: $e")
                                    -1
                                }
                                mainHandler.post {
                                    if (out < 0) {
                                        result.error("copy_failed", "copyTree", null)
                                    } else {
                                        result.success(out)
                                    }
                                }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
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
