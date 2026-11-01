plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStorePath = System.getenv("ANDROID_KEYSTORE_PATH")?.takeIf { it.isNotBlank() }
val releaseStorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val releaseKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.example.generic_template"
    val configuredAppName = System.getenv("APP_NAME")
        ?.takeIf { it.isNotBlank() }
        ?: "Generic Android Template"
    compileSdk = flutter.compileSdkVersion
    // لا توجد إضافات أصلية مكتوبة بـC/C++ في هذا المشروع، لذا لا حاجة إلى NDK.
    // حذف السطر يمنع Gradle من محاولة تنزيل نسخة NDK غير مثبتة.

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.generic_template"
        manifestPlaceholders["appName"] = configuredAppName
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

    if (hasReleaseSigning) {
        signingConfigs.create("release") {
            storeFile = file(releaseStorePath!!)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    buildTypes {
        release {
            // The validation task below blocks release builds unless a private
            // production keystore is explicitly configured in the environment.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    group = "verification"
    description = "Require a configured production keystore before creating release artifacts."
    doLast {
        if (!hasReleaseSigning) {
            throw GradleException(
                "Release signing is required. Set ANDROID_KEYSTORE_PATH, " +
                    "ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, and ANDROID_KEY_PASSWORD.",
            )
        }
    }
}

tasks.matching {
    (it.name.startsWith("assemble") || it.name.startsWith("bundle") || it.name.startsWith("package")) &&
        it.name.endsWith("Release")
}.configureEach {
    dependsOn(validateReleaseSigning)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// ينسخ حزمة الإصدار تلقائيًا إلى مجلد dist باسم القالب.
// حتى يظهر الملف للعميل بالاسم الصحيح بعد كل عملية بناء.
val templateAppName = System.getenv("APP_NAME")
    ?.takeIf { it.isNotBlank() }
    ?: "Generic Android Template"
val templateApkName = "$templateAppName.apk"

tasks.register("publishTemplateApk") {
    group = "build"
    description = "Copy the release APK to dist/ using the template name."
    doLast {
        val source = layout.buildDirectory.file("outputs/apk/release/app-release.apk").get().asFile
        if (!source.exists()) {
            logger.warn("Release APK not found at ${source.absolutePath}")
            return@doLast
        }
        val distDir = rootProject.file("../dist")
        distDir.mkdirs()
        val target = File(distDir, templateApkName)
        source.copyTo(target, overwrite = true)
        logger.lifecycle("APK published: ${target.absolutePath}")
    }
}

tasks.matching { it.name == "assembleRelease" }.configureEach {
    finalizedBy("publishTemplateApk")
}

flutter {
    source = "../.."
}
