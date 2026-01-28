import com.android.build.gradle.BaseExtension
import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

/**
 * Перекидываем build/ в общий каталог ../../build
 */
val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()

rootProject.layout.buildDirectory.value(newBuildDir)

/**
 * У каждого подпроекта свой buildDir внутри общего build/
 */
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    layout.buildDirectory.value(newSubprojectBuildDir)
}

/**
 * Иногда Flutter требует evaluationDependsOn(":app")
 */
subprojects {
    evaluationDependsOn(":app")
}

/**
 * Фикс ошибки shared_preferences_android:
 * принудительно задаём compileSdk для всех Android-подпроектов (включая плагины из Pub cache)
 */
subprojects {
    afterEvaluate {
        // если это Android-модуль (application/library), у него будет extension "android"
        extensions.findByName("android")?.let { androidExt ->
            (androidExt as BaseExtension).compileSdkVersion(34)
        }
    }
}

/**
 * clean
 */
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}