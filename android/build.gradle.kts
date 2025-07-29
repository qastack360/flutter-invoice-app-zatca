import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.Delete

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.0.0")
        // Flutter plugin agar zaroori ho to
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Build directory ko project-folders se upar move karna
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // Har subproject ka apna build dir set kardo
    val newSubBuild = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubBuild)

    // ensure app project evaluate pehla ho
    evaluationDependsOn(":app")

    // agar module Android Library hai, namespace set karo
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            namespace = "com.example.flutter_invoice_app"
        }
    }
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
