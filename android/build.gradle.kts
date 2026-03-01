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

fun applyFallbackNamespace(project: Project) {
    val androidExt = project.extensions.findByName("android") ?: return

    val getNamespace = androidExt.javaClass.methods.firstOrNull {
        it.name == "getNamespace" && it.parameterCount == 0
    } ?: return

    val setNamespace = androidExt.javaClass.methods.firstOrNull {
        it.name == "setNamespace" && it.parameterCount == 1
    } ?: return

    val currentNamespace = getNamespace.invoke(androidExt) as? String
    if (currentNamespace.isNullOrBlank()) {
        val safeName = project.name.replace("-", "_")
        setNamespace.invoke(androidExt, "com.trackbound.generated.$safeName")
    }
}

subprojects {
    if (state.executed) {
        applyFallbackNamespace(this)
    } else {
        afterEvaluate {
            applyFallbackNamespace(this)
        }
    }
}

subprojects {
    if (name == "isar_flutter_libs") {
        val patchLegacyManifestPackage by tasks.registering {
            doLast {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (!manifestFile.exists()) return@doLast

                val original = manifestFile.readText()
                val patched = original.replace(Regex("\\s*package=\"[^\"]+\""), "")
                if (patched != original) {
                    manifestFile.writeText(patched)
                    println("Patched legacy package attribute in isar_flutter_libs AndroidManifest.xml")
                }
            }
        }

        tasks.matching {
            it.name.startsWith("process") && it.name.endsWith("Manifest")
        }.configureEach {
            dependsOn(patchLegacyManifestPackage)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
