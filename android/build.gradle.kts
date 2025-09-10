allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

// Redirect the build directory to a path without spaces to fix the build error.
rootProject.buildDir = File("C:/build/${rootProject.name}")

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}