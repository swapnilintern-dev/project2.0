import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials, kept OUT of version control. Create
// android/key.properties (see android/key.properties.example) on the machine
// that cuts store builds:
//
//   storeFile=C:/keys/vsarogya-upload.jks
//   storePassword=…
//   keyAlias=upload
//   keyPassword=…
//
// When the file is absent (every dev machine, CI that only builds debug) the
// release build falls back to the debug keys, exactly as before, so
// `flutter build apk --release` keeps working locally. A build signed that way
// is NOT uploadable to Play — the properties file is what makes it shippable.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.vsarogya.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The published identity of VS Arogya on Google Play. Never revert this
        // to a com.example.* id — Play rejects those outright.
        applicationId = "com.vsarogya.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Code shrinking stays OFF deliberately. R8 strips the reflective
            // entry points Razorpay's checkout relies on, and a mis-shrunk
            // payment flow only fails on a real device — not in a build. Turn it
            // on together with the keep rules in proguard-rules.pro, and only
            // after testing a live payment on-device.
            isMinifyEnabled = false
            isShrinkResources = false
        }
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
