import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: loaded from android/key.properties (git-ignored). Falls back
// to the debug key when the file is absent (e.g. CI without secrets).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // Kept EQUAL to applicationId on purpose. When they differed, MIUI/HyperOS
    // components read the class half of ComponentInfo{applicationId/class} and
    // fed it to the PackageManager as if it were a package, spamming
    // NameNotFoundException: com.modizer.rewamp.rewamp. Nothing of ours was
    // wrong, but keeping the two in step removes a whole class of surface
    // confusion for free.
    namespace = "com.rewamp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Store identity, reserved on Play Store / App Store. Same as the
        // namespace above — see the note there.
        applicationId = "com.rewamp.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26  // rewamp_audio requires API 26 (AAudio)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ABI choisies AU MOMENT DE L'EMPAQUETAGE — le seul mécanisme qui tient.
    //
    // arm64-v8a, x86_64 et, depuis le 2026-11-14, armeabi-v7a (box Android TV:
    // souvent un userland 32 bits seul, même sur un SoC 64 bits). Une ABI n'est
    // livrable que si son FFmpeg existe: sans lui vgmstream y perd EN SILENCE
    // MP3, Vorbis, AAC, Opus, ATRAC, WMA, XMA… — le CMakeLists du plugin fait
    // désormais ÉCHOUER le build dans ce cas. x86 (émulateurs 32 bits) reste
    // exclu: aucun appareil réel, et aucun FFmpeg pour lui.
    //
    // Trois mécanismes ont été essayés avant celui-ci, et leurs échecs sont la
    // raison de l'écrire:
    //   - les abiFilters du PLUGIN empêchent librewamp_audio.so d'être bâtie
    //     pour une ABI, mais Flutter empaquetait quand même la tranche avec
    //     libflutter/libapp et SANS moteur — s'installe, meurt au 1er appel FFI;
    //   - `ndk { abiFilters }` ici est écrasé en silence par le plugin Gradle
    //     de Flutter: l'APK sortait avec toutes les ABI;
    //   - `--target-platform` fait presque tout mais laisse libdartjni.so et
    //     libdatastore_shared_counter.so (AAR tiers) — assez pour que Play
    //     annonce encore la variante.
    // Exclure à l'EMPAQUETAGE est la seule chose que rien en aval ne rajoute.
    // ⚠️ La liste ci-dessous et les abiFilters du plugin doivent concorder.
    //
    // Surchargeable, p.ex. un APK de distribution directe en arm64 seul:
    //   flutter build apk --release -Prewamp.excludeAbis=armeabi-v7a,x86,x86_64
    packaging {
        jniLibs {
            excludes += (project.findProperty("rewamp.excludeAbis") as String?
                ?: "x86").split(",").map { "lib/$it/**" }
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release keystore when key.properties is present, else fall
            // back to the debug key so `flutter run --release` still works.
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // R8/resource-shrinking OFF. It stripped audio_service's bundled
            // notification-control drawables (audio_service_play_arrow, …), so in
            // release every media notification build threw
            // "IllegalArgumentException: You must specify an icon resource id to
            // build a CustomAction" (250ms loop) → NO lock-screen / shade media
            // controls (worked in debug, which isn't minified). This app is
            // overwhelmingly native (audio decoders + FFI), where R8 would be a
            // keep-rule minefield and its Dart-code savings are negligible, so
            // disabling it is both the fix and the safer default.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // (Audio-route picker history: androidx mediarouter's chooser dialog was
    // tried and dropped — it is CAST-oriented, showed "Caster sur" with an
    // empty spinner and never listed local outputs. The picker now asks
    // SystemUI for its Media Output dialog — the one the media-center chip
    // opens — via broadcast, no dependency needed. See MainActivity.)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
