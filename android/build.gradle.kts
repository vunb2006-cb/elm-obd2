import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Flutter plugins ship their own android {} blocks; many still use a low compileSdk,
// which breaks release AAPT linking (e.g. android:attr/lStar requires API 31+).
subprojects {
    afterEvaluate {
        extensions.findByType(LibraryExtension::class.java)?.apply {
            compileSdk = 34
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Workaround for older Flutter plugins that don't declare `namespace` (required by AGP 8+).
subprojects {
    afterEvaluate {
        if (name == "flutter_bluetooth_serial") {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            // Avoid compile-time dependency on Android Gradle Plugin classes by using reflection.
            val setNamespace = androidExt
                .javaClass
                .methods
                .firstOrNull { it.name == "setNamespace" && it.parameterTypes.contentEquals(arrayOf(String::class.java)) }
                ?: return@afterEvaluate
            setNamespace.invoke(androidExt, "io.github.edufolly.flutterbluetoothserial")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
