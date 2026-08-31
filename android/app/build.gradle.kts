import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Where the release signing details come from.
//
// NOT in the repository, and `.gitignore` keeps it that way along with the
// keystore itself. That file is the app's IDENTITY: Android decides whether an
// update may replace an installed app by comparing signatures, so anyone
// holding it can publish something that overwrites this app on a user's phone,
// and losing it means no future version can ever update the installed one.
//
// `android/key.properties.example` lists the four keys and how to make the
// keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

android {
    namespace = "com.archlence.archlence_mobile"
    // 37 rather than `flutter.compileSdkVersion`, which is 36 in Flutter
    // 3.47. `flutter_secure_storage` 11 is compiled against 37 and declares
    // it in its AAR metadata, so `:app:checkDebugAarMetadata` FAILS the build
    // at 36 — it is a hard requirement, not the warning the Flutter tool
    // prints one line earlier.
    //
    // Only the compile SDK moves. `targetSdk` stays on Flutter's number
    // below, because that one changes how Android treats the app at runtime
    // and is a decision to make deliberately and test; compiling against a
    // newer SDK changes nothing about behaviour.
    compileSdk = 37
    // And its minor version, which is not optional any more. Google ships
    // platform 37 as `android-37.0`, `37.1` and `37.2`; there is no bare
    // `android-37` package in the SDK repository. With `compileSdk = 37`
    // alone, AGP asks for target hash `android-37`, downloads
    // `platforms/android-37.0` on its own initiative, and then fails to find
    // the thing it just installed. `compileSdkMinor = 0` makes the hash
    // `android-37.0`, which is the package that exists.
    compileSdkMinor = 0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.archlence.archlence_mobile"
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

    signingConfigs {
        // Declared only when there is something to declare. A config pointing
        // at a keystore that is not there fails deep inside AGP with a message
        // about a missing file; the check below fails early and says what to
        // do instead.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Null when `key.properties` is absent, and the guard below turns
            // that into a refusal.
            //
            // What this REPLACED is the point: the Flutter template signs
            // release builds with the DEBUG key so that `flutter run --release`
            // works out of the box. The debug key is a well-known one that
            // ships with the SDK and is identical on every machine — an APK
            // carrying it can be replaced by anything anyone else builds, can
            // never be updated by a real key afterwards, and Play refuses it.
            // It is the one failure here that looks like success.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// Refuse to build a release that is not properly signed.
//
// The alternative is an APK that installs and runs and is quietly worthless —
// either unsigned, or carrying the SDK's debug key. Both are discovered at the
// moment someone tries to ship an update, which is the worst moment to find
// out. `assembleDebug` is untouched: development does not need any of this.
tasks.matching { it.name.matches(Regex("^(assemble|bundle).*Release$")) }
    .configureEach {
        doFirst {
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "A release build needs android/key.properties, which is " +
                        "not in the repository. See " +
                        "android/key.properties.example — it lists the four " +
                        "keys and the keytool command that makes the keystore."
                )
            }
            val missing = listOf(
                "storeFile", "storePassword", "keyAlias", "keyPassword"
            ).filter { keystoreProperties.getProperty(it).isNullOrBlank() }
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "android/key.properties is missing: " +
                        missing.joinToString(", ")
                )
            }
            val store = file(keystoreProperties.getProperty("storeFile"))
            if (!store.exists()) {
                throw GradleException(
                    "storeFile in android/key.properties points at " +
                        "${store.absolutePath}, which does not exist."
                )
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
