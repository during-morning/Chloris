package android.text

/**
 * Minimal stub of `android.text.TextUtils` covering only what the Legado-E
 * XPath backend uses: `join(delimiter, iterable)`. Behaviour mirrors the
 * Android implementation (elements concatenated with the delimiter, null
 * elements rendered as "null" to match Java's default toString).
 */
object TextUtils {
    @JvmStatic
    fun join(delimiter: CharSequence, elements: Iterable<*>): String {
        val sb = StringBuilder()
        var first = true
        for (element in elements) {
            if (!first) sb.append(delimiter)
            sb.append(element?.toString() ?: "null")
            first = false
        }
        return sb.toString()
    }
}
