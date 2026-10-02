plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.nortexsys.paperdrop"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent once published (DEC-006): no third-party mark in the id.
        applicationId = "com.nortexsys.paperdrop"
        // Pinned, not inherited from Flutter's defaults (setup-mvp-foundations, design §4).
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Candidate A of ADR-011 (close-adr-011-pdf-text-route, design §1, task 1.1).
    // Apache-2.0, from Maven Central through the Kotlin channel in
    // src/main/kotlin/com/nortexsys/paperdrop/pdftext/. The runner-up stays in
    // the build until the product owner's decision, so both numbers are in the
    // record; the loser's line leaves with its code (design §5).
    implementation("com.tom-roush:pdfbox-android:2.0.27.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
