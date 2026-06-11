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

    // ffmpeg_kit_flutter_new_min (pulled in by whisper_ggml) requires consumers
    // to compile against Android API 35+, but whisper_ggml pins compileSdk 34,
    // which fails the AAR metadata check. Bump any library subproject below 35.
    // Registered here (before the evaluationDependsOn block) so the subproject
    // isn't already evaluated when afterEvaluate is added.
    afterEvaluate {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.let { ext ->
                if ((ext.compileSdk ?: 0) < 35) {
                    ext.compileSdk = 36
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
