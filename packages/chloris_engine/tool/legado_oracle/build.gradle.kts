plugins {
    kotlin("jvm") version "2.0.21"
    application
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    // Versions mirror reference/legado-E-main/gradle/libs.versions.toml so the
    // oracle runs the same jsoup / XPath / JSONPath semantics as upstream.
    implementation("org.jsoup:jsoup:1.16.2")
    implementation("cn.wanghaomiao:JsoupXpath:2.5.3")
    implementation("com.jayway.jsonpath:json-path:2.10.0")
    // jsoup-xpath pulls slf4j; bind it to NOP so the judging process stays
    // silent on stdout/stderr (the bridge only reads stdout JSON).
    implementation("org.slf4j:slf4j-nop:2.0.16")
}

kotlin {
    jvmToolchain(21)
}

application {
    mainClass.set("legadooracle.MainKt")
}

// The two Legado-E sources are NOT copied here. They are referenced via
// symlinks under src/main/kotlin/io/legado/app/model/analyzeRule so the
// oracle always runs the real upstream implementation.
tasks.named<JavaExec>("run") {
    standardInput = System.`in`
}
