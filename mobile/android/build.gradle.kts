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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ffmpeg_kit_flutter_new_min (pulled in by whisper_ggml) requires consumers to
// compile against Android API 35+, but whisper_ggml pins compileSdk 34, which
// fails the AAR metadata check. Bump any library subproject below 35.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.let { ext ->
                if ((ext.compileSdk ?: 0) < 35) {
                    ext.compileSdk = 36
                }
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
