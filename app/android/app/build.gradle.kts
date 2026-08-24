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

    // 64-BIT ONLY — and this is the mechanism that actually works.
    //
    // Why drop 32-bit: only android-arm64 and android-x86_64 FFmpeg slices are
    // vendored, so an armeabi-v7a build silently loses the vgmstream formats
    // whose codec goes through FFmpeg (our config also turns vgmstream's own
    // MPEG/Vorbis/G719 off in its favour). A 64-bit phone takes the arm64 slice
    // anyway; only 32-bit-ONLY devices, pre-2018 and low end, would get it.
    //
    // Three mechanisms were tried before this one, and the failures are the
    // reason it is worth writing down:
    //   - the PLUGIN's cmake abiFilters stop librewamp_audio.so being built for
    //     armeabi-v7a, but Flutter then packaged a 32-bit slice with
    //     libflutter/libapp and NO engine — installs, dies at the first FFI call;
    //   - `ndk { abiFilters }` here is silently overridden by Flutter's Gradle
    //     plugin: the APK still came out with all three ABIs;
    //   - `--target-platform` gets most of the way but leaves libdartjni.so and
    //     libdatastore_shared_counter.so behind, from third-party AARs — enough
    //     for Play to keep advertising an armeabi-v7a variant.
    // Excluding at PACKAGING time is the one thing nothing downstream re-adds.
    //
    // Overridable, so the direct-distribution APK can be arm64 alone instead of
    // carrying x86_64 for a phone that cannot use it:
    //   flutter build apk --release -Prewamp.excludeAbis=armeabi-v7a,x86,x86_64
    packaging {
        jniLibs {
            excludes += (project.findProperty("rewamp.excludeAbis") as String?
                ?: "armeabi-v7a,x86").split(",").map { "lib/$it/**" }
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
