plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.spideytech.spinora"
    compileSdk = 37 // permission_handler_android requires SDK 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.spideytech.spinora"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ---------------------------------------------------------------------------
    // Build flavors
    //
    // dev   → completely isolated from real user data:
    //         • distinct applicationId suffix (.dev) → separate Play Store slot
    //         • separate app label ("Spinora Dev")
    //         • BUILD_FLAVOR Dart-visible string for conditional logic in Dart
    //         • dedicated Drift DB name ("spinora_dev.db") so DB files never mix
    //
    // prod  → the real, shipping build.
    //         • unchanged applicationId
    //         • no suffix on the app label
    //
    // Run with:
    //   flutter run  --flavor dev  -t lib/main_dev.dart
    //   flutter run  --flavor prod -t lib/main_prod.dart
    // ---------------------------------------------------------------------------
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue("string", "app_name", "Spinora Dev")
            // Passed to Dart via --dart-define when using flutter run --flavor dev.
            // We also expose it as a manifest placeholder so native code can read it.
            manifestPlaceholders["buildFlavor"] = "dev"
            // Separate Drift database file – dev builds never open the prod DB.
            buildConfigField("String", "DB_NAME", "\"spinora_dev.db\"")
            buildConfigField("String", "BUILD_FLAVOR", "\"dev\"")
        }

        create("prod") {
            dimension = "environment"
            // No applicationId or versionName suffix – prod uses the defaults.
            resValue("string", "app_name", "Spinora")
            manifestPlaceholders["buildFlavor"] = "prod"
            buildConfigField("String", "DB_NAME", "\"spinora.db\"")
            buildConfigField("String", "BUILD_FLAVOR", "\"prod\"")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Required so Gradle generates the BuildConfig class with our custom fields
    // and emits per-flavor resValue() strings (e.g. app_name).
    buildFeatures {
        buildConfig = true
        resValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
