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
// flutter_secure_storage 11 声明 compileSdk = 37，但 API 37 平台包在本机 SDK 仓库里只有
// android-37.0（主.小版本命名 + 坏元数据），AGP 按 hash android-37 找不到目标。该插件源码
// 未用任何 API 37 独有符号，把它的 compileSdk 钳到 36（已装、亦为 Flutter 3.47 默认值）可正常编译。
// permission_handler 已在 pubspec 降到 12.x（android 实现 compileSdk 35），不受此影响。
// afterEvaluate 必须注册在 evaluationDependsOn 之前（否则 :app 已求值，注册会抛异常）。上游适配后可删。
subprojects {
    afterEvaluate {
        if (name != "app") {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            val setter = androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1 &&
                    (it.parameterTypes[0] == java.lang.Integer.TYPE || it.parameterTypes[0] == java.lang.Integer::class.java)
            }
            setter?.invoke(androidExt, 36)
        }
    }
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
