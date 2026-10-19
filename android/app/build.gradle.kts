import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Podpis wydania ──────────────────────────────────────────────────────
// Klucz podpisujący nigdy nie leży w repozytorium (CLAUDE.md, reguła 2 —
// i tak samo każe Google). Gradle szuka go w dwóch miejscach:
//
//  1. `android/key.properties` — plik na komputerze dewelopera
//     (w .gitignore), z wpisami: storeFile, storePassword, keyAlias,
//     keyPassword;
//  2. zmiennych środowiskowych AGRO_KEYSTORE_PLIK, AGRO_KEYSTORE_HASLO,
//     AGRO_KLUCZ_ALIAS, AGRO_KLUCZ_HASLO — tak podaje go przepływ
//     GitHub Actions z sekretów repozytorium.
//
// Gdy klucza nie ma w żadnym z nich, wydanie podpisuje się kluczem
// debugowym: `flutter build apk --release` nadal działa, a plik nadaje
// się do testów na telefonie — ale nie do Google Play. Mówi o tym
// ostrzeżenie w logu, żeby nikt nie wysłał testowego pliku do sklepu.
val wlasnosciKlucza = Properties().apply {
    val plik = rootProject.file("key.properties")
    if (plik.exists()) {
        plik.inputStream().use { load(it) }
    }
}

fun wartoscKlucza(nazwaWPliku: String, nazwaZmiennej: String): String? =
    wlasnosciKlucza.getProperty(nazwaWPliku)
        ?: System.getenv(nazwaZmiennej)

val keystorePlik = wartoscKlucza("storeFile", "AGRO_KEYSTORE_PLIK")
val keystoreHaslo = wartoscKlucza("storePassword", "AGRO_KEYSTORE_HASLO")
val kluczAlias = wartoscKlucza("keyAlias", "AGRO_KLUCZ_ALIAS")
val kluczHaslo = wartoscKlucza("keyPassword", "AGRO_KLUCZ_HASLO")

val wlasnyPodpis = listOf(
    keystorePlik,
    keystoreHaslo,
    kluczAlias,
    kluczHaslo,
).all { !it.isNullOrBlank() } && file(keystorePlik!!).exists()

android {
    namespace = "pl.mojlan.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Wymagane przez wtyczkę powiadomień: pozwala używać nowych klas
        // czasu także na starszych Androidach (przypomnienia o terminach).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "pl.mojlan.app"
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
        if (wlasnyPodpis) {
            create("wydanie") {
                storeFile = file(keystorePlik!!)
                storePassword = keystoreHaslo
                keyAlias = kluczAlias
                keyPassword = kluczHaslo
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (wlasnyPodpis) {
                signingConfigs.getByName("wydanie")
            } else {
                logger.warn(
                    "Mój Łan: brak klucza podpisującego — wydanie " +
                        "podpisuję kluczem debugowym. Plik nadaje się do " +
                        "testów na telefonie, ale nie do Google Play. " +
                        "Patrz docs/wydanie-android.md.",
                )
                signingConfigs.getByName("debug")
            }
            // Reguły dla R8: patrz `proguard-rules.pro` — bez nich wydanie
            // nie buduje się przez brakujące klasy rozpoznawania pisma
            // azjatyckiego we wtyczce odczytu zdjęć.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
