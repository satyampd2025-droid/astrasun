plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "`in`.atulyaa.atulyaa_mill"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "`in`.atulyaa.atulyaa_mill"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Preview APKs built by CI are signed with one fixed key so each new build
    // installs over the last one. The key is kept by CI, never in the repo.
    val previewKeystore = file("preview.keystore")
    signingConfigs {
        if (previewKeystore.exists()) {
            create("preview") {
                storeFile = previewKeystore
                storePassword = System.getenv("PREVIEW_KEYSTORE_PASSWORD")
                keyAlias = "preview"
                keyPassword = System.getenv("PREVIEW_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (previewKeystore.exists()) signingConfigs.getByName("preview")
                else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
