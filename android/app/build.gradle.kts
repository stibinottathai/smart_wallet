import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load the upload keystore credentials from android/key.properties (kept out of
// version control). Falls back to no release signing if the file is absent, so
// debug builds and CI without the keystore still work.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.smart_wallet"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    // The release-time lint gate (lintVitalAnalyzeRelease) is disabled: it adds no
    // signal beyond `flutter analyze` for this app and its jar cache is prone to
    // Windows file-lock failures during `bundleRelease`. Run lint explicitly with
    // `./gradlew lint` if needed.
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.stibin.smartwallet"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Use the real upload keystore when key.properties is present;
            // otherwise fall back to debug signing so local `flutter run
            // --release` still works without the keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8/ProGuard code + resource shrinking. This previously crashed the
            // app ("TypeToken must be created with a type argument") because R8
            // stripped the Gson generic type info that flutter_local_notifications
            // relies on. The keep-rules in proguard-rules.pro (-keepattributes
            // Signature + the Gson TypeToken keeps) address that, so shrinking is
            // re-enabled to trim unused Java/Kotlin bytecode and resources.
            // NOTE: ML Kit native libs and the Dart AOT library are not touched by
            // R8, so the bulk of the APK is unaffected — the win is on the dex.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
