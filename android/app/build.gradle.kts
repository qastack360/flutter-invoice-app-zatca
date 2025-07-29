plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin must come after Android & Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

// سب لائبریری ماڈیولز کے لیے namespace set کرنے کے لیے
subprojects {
    plugins.withId("com.android.library") {
        // import کو یقینی بنائیں: com.android.build.gradle.LibraryExtension
        val androidExt = extensions.getByName("android") as com.android.build.gradle.LibraryExtension
        androidExt.namespace = "com.example.flutter_invoice_app"
    }
}

android {
    namespace = "com.example.flutter_invoice_app"
    compileSdk = flutter.compileSdkVersion
    //ndkVersion = flutter.ndkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // اپنا unique Application ID
        applicationId = "com.example.flutter_invoice_app"
        minSdk = 21  // Was: minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
