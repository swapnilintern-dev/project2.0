allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Raise every plugin module to compileSdk 36.
    //
    // flutter_plugin_android_lifecycle (a transitive dependency of file_picker
    // and image_picker) publishes AAR metadata demanding API 36. Setting
    // compileSdk on :app alone is not enough — each plugin module compiles with
    // its own value, which still comes from the Flutter default (34), so
    // :file_picker itself fails the metadata check.
    //
    // Only the COMPILE target moves. Each plugin keeps its own minSdk and
    // targetSdk, so neither device compatibility nor runtime behaviour changes.
    //
    // Registered HERE rather than in a later subprojects block: the
    // `evaluationDependsOn(":app")` below forces evaluation, after which Gradle
    // refuses any further afterEvaluate registration.
    afterEvaluate {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
        if (android != null) {
            val current = android.compileSdkVersion
                ?.removePrefix("android-")
                ?.toIntOrNull()
            if (current == null || current < 36) {
                android.compileSdkVersion(36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
