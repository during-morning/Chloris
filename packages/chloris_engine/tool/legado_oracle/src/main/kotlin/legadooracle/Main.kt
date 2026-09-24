package legadooracle

import kotlinx.serialization.json.*
import io.legado.app.model.analyzeRule.AnalyzeByRegex
import io.legado.app.model.analyzeRule.AnalyzeByJSoup
import io.legado.app.model.analyzeRule.AnalyzeByXPath
import io.legado.app.model.analyzeRule.AnalyzeByJSonPath

/**
 * Legado-E judging process.
 *
 * Protocol (one JSON object per invocation, read from stdin, written to stdout):
 *   request : {"kind":"<backend>","content":"...","rule":"..."}
 *   response: {"mode":..., "expression":..., "value":...}
 *
 * The output field names intentionally mirror the comparable subset of what
 * Chloris' `EquivalenceFixture.run()` returns, so the Dart audit can diff them
 * field-by-field. `steps` is deliberately omitted: it is a Chloris IR metric
 * (compiled step count) with no Legado equivalent, so it is excluded from the
 * bilateral comparison rather than silently fabricated.
 *
 * Backends are brought online incrementally. A kind that is not yet wired up
 * returns an explicit `{"error":"not-connected:<kind>"}` instead of a guessed
 * value, so the Dart side can skip it rather than trust a fabricated result.
 */
fun main() {
    val raw = System.`in`.readBytes().decodeToString()
    val out = try {
        val req = Json.parseToJsonElement(raw).jsonObject
        val kind = req["kind"]?.jsonPrimitive?.content ?: "regex"
        val content = req["content"]?.jsonPrimitive?.content ?: ""
        val rule = req["rule"]?.jsonPrimitive?.content ?: ""
        when (kind) {
            "regex" -> runRegex(content, rule)
            "css" -> runCss(content, rule)
            "xpath" -> runXPath(content, rule)
            "json" -> runJson(content, rule)
            "single-rule" -> errorJson("not-connected:single-rule")
            else -> errorJson("unknown-kind:$kind")
        }
    } catch (e: Throwable) {
        errorJson("exception:${e.message ?: e::class.simpleName}")
    }
    println(out.toString())
}

/** Regex backend — AnalyzedByRegex.getElement chains patterns with `%%`. */
fun runRegex(content: String, rule: String): JsonObject {
    val patterns = rule.split("%%").toTypedArray()
    val value = AnalyzeByRegex.getElement(content, patterns)
    return result("regex", rule, value)
}

/** CSS backend — AnalyzeByJSoup handles the `@CSS:` prefix internally. */
fun runCss(content: String, rule: String): JsonObject {
    val value = AnalyzeByJSoup(content).getString(rule)
    return result("css", rule, value)
}

/** XPath backend. */
fun runXPath(content: String, rule: String): JsonObject {
    val value = AnalyzeByXPath(content).getString(rule)
    return result("xpath", rule, value)
}

/** JSONPath backend. */
fun runJson(content: String, rule: String): JsonObject {
    val value = AnalyzeByJSonPath(content).getString(rule)
    return result("json", rule, value)
}

fun result(mode: String, expression: String, value: Any?): JsonObject =
    buildJsonObject {
        put("mode", mode)
        put("expression", expression)
        put("value", toJsonElement(value))
    }

fun toJsonElement(value: Any?): JsonElement = when (value) {
    null -> JsonNull
    is String -> JsonPrimitive(value)
    is List<*> -> JsonArray(value.map { toJsonElement(it) })
    is Map<*, *> -> JsonObject(
        value.entries.associate { (k, v) -> k.toString() to toJsonElement(v) },
    )
    else -> JsonPrimitive(value.toString())
}

fun errorJson(message: String): JsonObject = buildJsonObject {
    put("error", message)
}
