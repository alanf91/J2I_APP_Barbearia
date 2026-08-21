import java.util.Properties

plugins {
    id("com.android.application")

    // ============================================================
    // FIREBASE
    // ============================================================

    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration

    // ============================================================
    // FLUTTER
    // ============================================================

    // Mantemos a configuração original do projeto Flutter.
    id("dev.flutter.flutter-gradle-plugin")
}

// ============================================================
// LOCAL.PROPERTIES
// ============================================================

val localProperties =
    Properties().apply {
        val localPropertiesFile =
            rootProject.file("local.properties")

        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use {
                load(it)
            }
        }
    }

// ============================================================
// MERCADO PAGO - PUBLIC KEY
// ============================================================
//
// A Public Key pode ser utilizada pelo aplicativo.
//
// NÃO colocar Access Token aqui.
// O Access Token permanece exclusivamente no backend Node.js.
//
// ============================================================

val mercadoPagoPublicKey =
    localProperties.getProperty(
        "mercadopago.publicKey",
        "",
    )

// ============================================================
// ANDROID
// ============================================================

android {
    namespace =
        "com.example.j2i_app_barbearia"

    // ==========================================================
    // SDK ANDROID
    // ==========================================================

    compileSdk =
        flutter.compileSdkVersion

    ndkVersion =
        flutter.ndkVersion

    // ==========================================================
    // JAVA 17
    // ==========================================================

    compileOptions {
        sourceCompatibility =
            JavaVersion.VERSION_17

        targetCompatibility =
            JavaVersion.VERSION_17
    }

    // ==========================================================
    // CONFIGURAÇÕES PADRÃO
    // ==========================================================

    defaultConfig {
        applicationId =
            "com.example.j2i_app_barbearia"

        minSdk =
            flutter.minSdkVersion

        targetSdk =
            flutter.targetSdkVersion

        versionCode =
            flutter.versionCode

        versionName =
            flutter.versionName

        // ======================================================
        // MERCADO PAGO
        // ======================================================
        //
        // Public Key injetada através do local.properties.
        //
        // NÃO colocar Access Token no Android.
        //
        // ======================================================

        buildConfigField(
            "String",
            "MERCADO_PAGO_PUBLIC_KEY",
            "\"$mercadoPagoPublicKey\"",
        )
    }

    // ==========================================================
    // BUILD FEATURES
    // ==========================================================

    buildFeatures {
        // Necessário porque usamos:
        //
        // BuildConfig.MERCADO_PAGO_PUBLIC_KEY

        buildConfig = true
    }

    // ==========================================================
    // RELEASE
    // ==========================================================

    buildTypes {
        release {
            // TODO:
            //
            // Antes da publicação na Google Play,
            // criaremos a assinatura real do aplicativo.

            signingConfig =
                signingConfigs
                    .getByName("debug")
        }
    }
}

// ============================================================
// KOTLIN
// ============================================================

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl
                .JvmTarget
                .JVM_17
    }
}

// ============================================================
// FLUTTER
// ============================================================

flutter {
    source = "../.."
}

// ============================================================
// DEPENDÊNCIAS
// ============================================================

dependencies {

    // ==========================================================
    // JETPACK COMPOSE BOM
    // ==========================================================
    //
    // O Mercado Pago SDK requer:
    //
    // Jetpack Compose BOM 2024.12.01+
    //
    // IMPORTANTE:
    //
    // O BOM apenas controla as versões.
    // Ele NÃO adiciona as bibliotecas Compose automaticamente.
    //
    // Por isso, abaixo também adicionamos:
    //
    // androidx.compose.ui:ui
    // androidx.compose.ui:ui-graphics
    // androidx.compose.ui:ui-tooling-preview
    // androidx.compose.material3:material3
    // androidx.activity:activity-compose
    //
    // ==========================================================

    implementation(
        platform(
            "androidx.compose:compose-bom:2024.12.01",
        ),
    )

    // ==========================================================
    // COMPOSE UI
    // ==========================================================
    //
    // MUITO IMPORTANTE:
    //
    // Essa dependência contém:
    //
    // androidx.compose.ui.platform.AbstractComposeView
    //
    // que é justamente a classe que estava faltando na
    // compilação dos componentes PCI do Mercado Pago.
    //
    // ==========================================================

    implementation(
        "androidx.compose.ui:ui",
    )

    implementation(
        "androidx.compose.ui:ui-graphics",
    )

    implementation(
        "androidx.compose.ui:ui-tooling-preview",
    )

    implementation(
        "androidx.compose.material3:material3",
    )

    implementation(
        "androidx.activity:activity-compose:1.9.3",
    )

    // ==========================================================
    // COMPOSE TOOLING - SOMENTE DEBUG
    // ==========================================================

    debugImplementation(
        "androidx.compose.ui:ui-tooling",
    )

    // ==========================================================
    // MERCADO PAGO SDK BOM
    // ==========================================================

    implementation(
        platform(
            "com.mercadopago.android.sdk:sdk-android-bom:1.0.0",
        ),
    )

    // ==========================================================
    // MERCADO PAGO CORE METHODS
    // ==========================================================
    //
    // Responsável por:
    //
    // - PCI Fields
    // - CardNumberTextField
    // - ExpirationDateTextField
    // - SecurityCodeTextField
    // - PCIFieldState
    // - generateCardToken()
    //
    // ==========================================================

    implementation(
        "com.mercadopago.android.sdk:core-methods",
    )
}