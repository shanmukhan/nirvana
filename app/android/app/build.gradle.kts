import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file(
    providers.gradleProperty("nirvanaSigningPropertiesFile").orElse("key.properties").get()
)
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val validateReleaseSigning by tasks.registering {
    doLast {
        check(keystorePropertiesFile.exists()) {
            "Release signing is required. Create android/key.properties from key.properties.example."
        }
        for (property in listOf("keyAlias", "keyPassword", "storeFile", "storePassword")) {
            check(!keystoreProperties.getProperty(property).isNullOrBlank()) {
                "Release signing property '$property' is missing."
            }
        }
        check(file(keystoreProperties.getProperty("storeFile")).isFile) {
            "The configured release keystore file does not exist."
        }
    }
}

tasks.configureEach {
    if (name.contains("Release") && name != "validateReleaseSigning") {
        dependsOn(validateReleaseSigning)
    }
}

android {
    namespace = "com.nirvana.nirvana"
    // permission_handler_android requires compileSdk 37; Flutter's own
    // default (flutter.compileSdkVersion) hadn't caught up yet as of this
    // Flutter version, so it's pinned explicitly here.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nirvana.nirvana"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
