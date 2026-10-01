package com.during.chloris

import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import org.json.JSONObject
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONTokener

class MainActivity : AudioServiceActivity() {
    private val sessions = mutableMapOf<String, BrowserSession>()
    private val handler = Handler(Looper.getMainLooper())
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chloris/browser").setMethodCallHandler { call, result ->
            val data = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
            val id = data["id"] as? String ?: ""
            when (call.method) {
                "close" -> { sessions.remove(id)?.finish(null); result.success(null) }
                "run" -> {
                    if (sessions.size >= 2) { result.error("browser_busy", "动态解析队列已满，请稍后重试", null) }
                    else { sessions.remove(id)?.finish(null); val session = BrowserSession(id, data, result); sessions[id] = session; session.start() }
                }
                else -> result.notImplemented()
            }
        }
    }
    private inner class BrowserSession(val id: String, val data: Map<*, *>, val result: MethodChannel.Result) {
        val web = WebView(this@MainActivity)
        var completed = false
        val timeout = Runnable { fail("browser_timeout", "网页解析超时") }
        val poll = object : Runnable {
            override fun run() {
                if (completed) return
                web.evaluateJavascript(data["script"] as? String ?: "null") { value ->
                    if (completed) return@evaluateJavascript
                    val parsed = try { JSONTokener(value).nextValue() } catch (_: Exception) { null }
                    if (parsed is String && parsed.isNotEmpty()) finish(parsed)
                    else handler.postDelayed(this, 250)
                }
            }
        }
        fun start() {
            web.settings.javaScriptEnabled = true
            web.settings.domStorageEnabled = true
            web.settings.mediaPlaybackRequiresUserGesture = false
            val headers = (data["headers"] as? Map<*, *>)?.entries?.associate { it.key.toString() to it.value.toString() } ?: emptyMap()
            headers.entries.firstOrNull { it.key.equals("User-Agent", true) }?.let { web.settings.userAgentString = it.value }
            val url = data["url"] as? String ?: "about:blank"
            headers.entries.firstOrNull { it.key.equals("Cookie", true) }?.let { it.value.split(";").forEach { cookie -> CookieManager.getInstance().setCookie(url, cookie.trim()) } }
            if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
                WebViewCompat.addDocumentStartJavaScript(web, data["capture"] as? String ?: "", setOf("*"))
            }
            web.webViewClient = object : WebViewClient() {
                override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
                    view.evaluateJavascript(data["capture"] as? String ?: "", null)
                }
                override fun onPageFinished(view: WebView, url: String?) {
                    view.evaluateJavascript(data["capture"] as? String ?: "", null)
                    handler.removeCallbacks(poll); handler.post(poll)
                }
                override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): android.webkit.WebResourceResponse? {
                    val raw = org.json.JSONObject.quote(request.url.toString())
                    handler.post { if (!completed) web.evaluateJavascript("window.__chlorisResources && window.__chlorisResources.push({url:$raw,options:{}})", null) }
                    return null
                }
            }
            handler.postDelayed(timeout, (data["timeoutMs"] as? Number)?.toLong() ?: 20000)
            val html = data["html"] as? String
            if (html.isNullOrEmpty()) web.loadUrl(url, headers)
            else web.loadDataWithBaseURL(url, "<script>${data["capture"]}</script>$html", "text/html", "UTF-8", null)
        }
        fun fail(code: String, message: String) {
            if (completed) return
            cleanup(); result.error(code, message, null)
        }
        fun cleanup() {
            completed = true; handler.removeCallbacks(timeout); handler.removeCallbacks(poll)
            web.stopLoading(); web.destroy(); sessions.remove(id)
        }
        fun finish(value: String?) {
            if (completed) return
            val body = if (value == null) null else try {
                JSONObject(value).apply { put("cookie", CookieManager.getInstance().getCookie(web.url ?: data["url"] as? String ?: "") ?: "") }.toString()
            } catch (_: Exception) { value }
            cleanup(); result.success(body)
        }
    }
    override fun onDestroy() {
        sessions.values.toList().forEach { it.finish(null) }; sessions.clear(); super.onDestroy()
    }
}
