import 'dart:async';
import 'dart:convert';

import '../models/book.dart';
import '../models/book_source.dart';
import '../models/domain_protocol.dart';
import 'java_host.dart';
import 'js_runtime.dart';

/// Shared helpers so IO / Web JS runtimes can inject legado-like bindings.
class JsHostBridge {
  static final _ajaxLit = RegExp(
    r'''java\.ajax\(\s*['"]([^'"]+)['"]\s*\)''',
  );
  static final _ajaxAllLit = RegExp(
    r'''java\.ajaxAll\(\s*\[(.*?)\]\s*\)''',
    dotAll: true,
  );
  static final _getStringLit = RegExp(
    r'''java\.getString\(\s*['"]([^'"]+)['"]\s*\)''',
  );

  static Map<String, Object?> serialize(JsScope scope) {
    final out = <String, Object?>{};
    scope.variables.forEach((k, v) {
      if (k == 'java') return;
      out[k] = _plain(v);
    });
    return out;
  }

  static Object? _plain(Object? v) {
    if (v == null || v is String || v is num || v is bool) return v;
    if (v is Book) {
      return {
        'name': v.name,
        'author': v.author,
        'bookUrl': v.bookUrl,
        'tocUrl': v.tocUrl,
        'origin': v.origin,
        'originName': v.originName,
        'kind': v.kind,
        'coverUrl': v.coverUrl,
        'intro': v.intro,
        'wordCount': v.wordCount,
      };
    }
    if (v is BookChapter) {
      return {
        'title': v.title,
        'url': v.url,
        'bookUrl': v.bookUrl,
        'index': v.index,
      };
    }
    if (v is BookSource) {
      return {
        'bookSourceUrl': v.bookSourceUrl,
        'bookSourceName': v.bookSourceName,
        'bookSourceGroup': v.bookSourceGroup,
        'key': v.bookSourceUrl,
        'jsLib': v.jsLib,
      };
    }
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), _plain(val)));
    if (v is List) return v.map(_plain).toList();
    return v.toString();
  }

  static Future<Map<String, String>> prefetchAjax(
    String code,
    JavaHost? host,
  ) async {
    if (host == null) return const {};
    final out = <String, String>{};
    if (code.contains('java.ajax')) {
      for (final m in _ajaxLit.allMatches(code)) {
        final url = m.group(1)!;
        if (out.containsKey(url)) continue;
        out[url] = (await host.ajax(url)) ?? '';
      }
      for (final m in _ajaxAllLit.allMatches(code)) {
        for (final inner in RegExp(r'''['"]([^'"]+)['"]''').allMatches(m.group(1)!)) {
          final url = inner.group(1)!;
          if (out.containsKey(url)) continue;
          out[url] = (await host.ajax(url)) ?? '';
        }
      }
    }
    if (code.contains('java.getString') && host.analyzeRule != null) {
      for (final m in _getStringLit.allMatches(code)) {
        final rule = m.group(1)!;
        final key = '__getString:$rule';
        if (out.containsKey(key)) continue;
        out[key] = (await host.getString(rule)) ?? '';
      }
    }
    return out;
  }

  static String prelude({
    required Map<String, Object?> vars,
    Map<String, String> ajaxCache = const {},
    String hid = '',
  }) {
    final buf = StringBuffer();
    buf.writeln('var __hid = ${jsonEncode(hid)};');
    buf.writeln('var __ajaxCache = ${jsonEncode(ajaxCache)};');
    vars.forEach((k, v) {
      if (!_safeIdent(k)) return;
      buf.writeln('var $k = ${jsonEncode(v)};');
    });
    buf.writeln(r'''
function __chlorisJava(m, a) {
  if (m === 'ajax') {
    var u = (a && a.length) ? a[0] : '';
    if (__ajaxCache[u] != null) return __ajaxCache[u];
  }
  if (m === 'getString') {
    var g = '__getString:' + ((a && a.length) ? a[0] : '');
    if (__ajaxCache[g] != null) return __ajaxCache[g];
  }
  if (typeof sendMessage === 'function') {
    return sendMessage('chlorisJava', JSON.stringify({id: __hid, m: m, a: a || []}));
  }
  if (typeof globalThis !== 'undefined' && typeof globalThis.__chlorisJava === 'function') {
    return globalThis.__chlorisJava(__hid, m, JSON.stringify(a || []));
  }
  return '';
}
if (source && typeof source === 'object') {
  source.getKey = function() { return source.key || source.bookSourceUrl || ''; };
}
var __cookieStr = (typeof cookie === 'string') ? cookie : '';
cookie = {
  toString: function() { return __cookieStr; },
  getCookie: function(tag) { return __chlorisJava('getCookie', [tag]); },
  removeCookie: function(tag) { return __chlorisJava('removeCookie', [tag]); }
};
// Legado binds a `cache` facade (CacheManager) into the rule scope. Without
// it a script calling cache.get/put raised ReferenceError, which the runtime
// swallowed and turned into the rule's input -- so the binding is what keeps
// those rules honest.
var cache = {
  put: function(k, v, saveTime) { return __chlorisJava('cachePut', [k, v, saveTime]); },
  // 第二参是 onlyDisk 而不是默认值（CacheManager.kt:98）——旧实现当默认值用，
  // 导致 `cache.get(k, true)` 两侧语义相反（差异文档 §12 的 P2）。
  get: function(k, onlyDisk) { return __chlorisJava('cacheGet', [k, onlyDisk === true]); },
  delete: function(k) { return __chlorisJava('cacheDelete', [k]); },
  putMemory: function(k, v) { return __chlorisJava('cachePutMemory', [k, v]); },
  getFromMemory: function(k) { return __chlorisJava('cacheGetFromMemory', [k]); },
  deleteMemory: function(k) { return __chlorisJava('cacheDeleteMemory', [k]); },
  getInt: function(k) { return __chlorisJava('cacheGetInt', [k]); },
  getLong: function(k) { return __chlorisJava('cacheGetInt', [k]); },
  getDouble: function(k) { return __chlorisJava('cacheGetDouble', [k]); },
  getFloat: function(k) { return __chlorisJava('cacheGetDouble', [k]); },
  putFile: function(url, saveTime) { return __chlorisJava('cacheFile', [url, saveTime]); },
  getFile: function(url) { return __chlorisJava('cacheFile', [url]); }
};
if (result && typeof result === 'object' && result.body !== undefined && typeof result.body !== 'function') {
  result = __asResp(result);
}
function __headerLookup(headers, key) {
  var h = headers || {};
  if (key == null || key === undefined || key === '') return h;
  var want = String(key).toLowerCase();
  for (var k in h) {
    if (String(k).toLowerCase() === want) {
      var v = h[k];
      return Array.isArray(v) ? v : [v];
    }
  }
  return [];
}
function __asResp(r) {
  if (r && typeof r === 'object' && typeof r.body !== 'function') {
    var x = r;
    return {
      body: function() { return x.body; },
      url: function() { return x.url; },
      code: function() { return x.code; },
      raw: function() { return x; },
      header: function(key) { return __headerLookup(x.headers, key); },
      headers: function(key) { return __headerLookup(x.headers, key); },
      toString: function() { return x.body || ''; }
    };
  }
  return r;
}
function __respFromCache(m, a) {
  var raw = __ajaxCache[m + ':' + JSON.stringify(a || [])];
  if (raw == null) return null;
  try { return JSON.parse(raw); } catch (e) { return raw; }
}
// ── element facade ────────────────────────────────────────────────────────
// `java.getElement(rule).text()` 这类写法在 Legado 上拿到的是真实 jsoup
// Element。Chloris 的桥是 JSON-only，Dart 侧因此回一个信封：
//   {"__el": {描述符}} / {"__els": [描述符]} / {"__raws": [非元素结果]}
// 这里把它还原成带方法的对象；看见别的值就原样返回，保证旧写法不受影响。
function __elOp(h, op, arg) {
  return __chlorisJava('elementOp', [h, op, arg]);
}
function __mkEl(d) {
  if (d == null) return null;
  var el = {
    __handle: d.h,
    tagName: function() { return d.tag || ''; },
    text: function() { return d.text || ''; },
    ownText: function() { return d.own || ''; },
    html: function() { return d.html || ''; },
    outerHtml: function() { return d.outer || ''; },
    attr: function(n) {
      if (n == null) return '';
      var a = d.attrs || {};
      return a[n] === undefined ? '' : a[n];
    },
    hasAttr: function(n) { return n != null && (d.attrs || {})[n] !== undefined; },
    attributes: function() {
      var out = [];
      var a = d.attrs || {};
      for (var k in a) out.push({ key: k, value: a[k] });
      return out;
    },
    id: function() { return d.id || ''; },
    className: function() { return d.cls || ''; },
    children: function() { return __elFrom(__elOp(d.h, 'children', '')); },
    parent: function() { return __elFrom(__elOp(d.h, 'parent', '')); },
    select: function(css) { return __elFrom(__elOp(d.h, 'select', css)); },
    selectFirst: function(css) { return __elFrom(__elOp(d.h, 'selectFirst', css)); },
    getElementsByTag: function(t) { return __elFrom(__elOp(d.h, 'tag', t)); },
    getElementsByClass: function(c) { return __elFrom(__elOp(d.h, 'class', c)); },
    toString: function() { return d.outer || d.text || ''; },
    valueOf: function() { return d.outer || d.text || ''; }
  };
  return el;
}
// jsoup 的 Elements：既是数组，也带 text()/attr()/select() 这类聚合方法。
// 真实书源大量写 `java.getElement('div.list').select('a').text()`，所以这一层
// 不能省。
function __mkEls(list) {
  var els = [];
  for (var i = 0; i < (list || []).length; i++) els.push(__mkEl(list[i]));
  els.size = function() { return els.length; };
  els.get = function(i) { return els[i] === undefined ? null : els[i]; };
  els.first = function() { return els.length ? els[0] : null; };
  els.last = function() { return els.length ? els[els.length - 1] : null; };
  els.text = function() {
    var out = [];
    for (var i = 0; i < els.length; i++) {
      var t = els[i] ? els[i].text() : '';
      if (t) out.push(t);
    }
    return out.join('\n');
  };
  els.html = function() {
    var out = [];
    for (var i = 0; i < els.length; i++) out.push(els[i] ? els[i].html() : '');
    return out.join('');
  };
  els.outerHtml = function() {
    var out = [];
    for (var i = 0; i < els.length; i++) out.push(els[i] ? els[i].outerHtml() : '');
    return out.join('');
  };
  els.attr = function(n) { return els.length ? els[0].attr(n) : ''; };
  els.select = function(css) {
    var out = [];
    for (var i = 0; i < els.length; i++) {
      var sub = els[i].select(css);
      for (var j = 0; j < sub.length; j++) out.push(sub[j]);
    }
    return out;
  };
  els.toString = function() { return els.outerHtml(); };
  els.valueOf = function() { return els.outerHtml(); };
  return els;
}
function __elFrom(p) {
  if (p == null || p === '') return null;
  var d = p;
  if (typeof d === 'string') {
    // 非信封的字符串（例如正则后端的结果）原样返回，保持旧行为。
    if (d.charAt(0) !== '{') return d;
    try { d = JSON.parse(d); } catch (e) { return p; }
  }
  if (d && d.__el) return __mkEl(d.__el);
  if (d && d.__els) return __mkEls(d.__els);
  if (d && d.__raws) return d.__raws;
  return p;
}
var java = {
  ajax: function(url) { return __chlorisJava('ajax', [url]); },
  ajaxAll: function(urls) {
    var raw = __chlorisJava('ajaxAll', [urls]);
    if (raw && raw.length !== undefined && raw.length > 0 && raw[0] && raw[0].body !== undefined) {
      var out = [];
      for (var i = 0; i < raw.length; i++) out.push(__asResp(raw[i]));
      return out;
    }
    var fallback = [];
    for (var j = 0; j < (urls || []).length; j++) fallback.push(java.ajax(urls[j]));
    return fallback;
  },
  md5Encode: function(s) { return __chlorisJava('md5Encode', [s]); },
  md5Encode16: function(s) { return __chlorisJava('md5Encode16', [s]); },
  base64Encode: function(s) { return __chlorisJava('base64Encode', [s]); },
  base64EncodeStr: function(s) { return __chlorisJava('base64Encode', [s]); },
  base64Decode: function(s) { return __chlorisJava('base64Decode', [s]); },
  base64DecodeStr: function(s) { return __chlorisJava('base64Decode', [s]); },
  hexEncodeToString: function(s) { return __chlorisJava('hexEncodeToString', [s]); },
  hexDecodeToString: function(s) { return __chlorisJava('hexDecodeToString', [s]); },
  htmlFormatStr: function(s) { return __chlorisJava('htmlFormatStr', [s]); },
  htmlFormat: function(s) { return __chlorisJava('htmlFormatStr', [s]); },
  getCookie: function(tag, key) { return __chlorisJava('getCookie', [tag, key]); },
  removeCookie: function(tag) { return __chlorisJava('removeCookie', [tag]); },
  timeFormat: function(t) { return __chlorisJava('timeFormat', [t]); },
  timeFormatUTC: function(t, fmt, sh) { return __chlorisJava('timeFormatUTC', [t, fmt, sh]); },
  put: function(k, v) { return __chlorisJava('put', [k, v]); },
  get: function(k, headers) {
    if (arguments.length >= 2) {
      var hit = __respFromCache('get', [k, headers]);
      if (hit != null) return __asResp(hit);
      return __asResp(__chlorisJava('get', [k, headers]));
    }
    return __chlorisJava('get', [k]);
  },
  log: function(msg) { return __chlorisJava('log', [msg]); },
  toast: function(msg) { return __chlorisJava('toast', [msg]); },
  sha256Encode: function(s) { return __chlorisJava('sha256Encode', [s]); },
  aesDecrypt: function(data, key, iv) { return __chlorisJava('aesDecrypt', [data, key, iv]); },
  getString: function(rule) {
    var hit = __respFromCache('getString', [rule]);
    if (hit != null) return hit;
    return __chlorisJava('getString', [rule]);
  },
  getStringList: function(rule) {
    var hit = __respFromCache('getStringList', [rule]);
    if (hit != null) return hit;
    return __chlorisJava('getStringList', [rule]);
  },
  getElement: function(rule) {
    var hit = __respFromCache('getElement', [rule]);
    if (hit != null) return __elFrom(hit);
    return __elFrom(__chlorisJava('getElement', [rule]));
  },
  getElements: function(rule) {
    var hit = __respFromCache('getElements', [rule]);
    if (hit != null) return __elFrom(hit);
    return __elFrom(__chlorisJava('getElements', [rule]));
  },
  readTxtFile: function(path, charset) {
    var hit = __respFromCache('readTxtFile', [path, charset]);
    if (hit != null) return hit;
    return __chlorisJava('readTxtFile', [path, charset]);
  },
  readFile: function(path) {
    var hit = __respFromCache('readFile', [path]);
    if (hit != null) return hit;
    return __chlorisJava('readFile', [path]);
  },
  getFile: function(url) {
    var hit = __respFromCache('getFile', [url]);
    if (hit != null) return hit;
    return __chlorisJava('getFile', [url]);
  },
  downloadFile: function(url, content) {
    var hit = __respFromCache('downloadFile', [url, content]);
    if (hit != null) return hit;
    return __chlorisJava('downloadFile', [url, content]);
  },
  deleteFile: function(path) {
    var hit = __respFromCache('deleteFile', [path]);
    if (hit != null) return hit;
    return __chlorisJava('deleteFile', [path]);
  },
  getTxtInFolder: function(dir) {
    var hit = __respFromCache('getTxtInFolder', [dir]);
    if (hit != null) return hit;
    return __chlorisJava('getTxtInFolder', [dir]);
  },
  unzipFile: function(path) {
    var hit = __respFromCache('unzipFile', [path]);
    if (hit != null) return hit;
    return __chlorisJava('unzipFile', [path]);
  },
  unArchiveFile: function(path) {
    var hit = __respFromCache('unArchiveFile', [path]);
    if (hit != null) return hit;
    return __chlorisJava('unArchiveFile', [path]);
  },
  un7zFile: function(path) { return __chlorisJava('un7zFile', [path]); },
  unrarFile: function(path) { return __chlorisJava('unrarFile', [path]); },
  getRarStringContent: function(url, path, charset) { return __chlorisJava('getRarStringContent', [url, path, charset]); },
  get7zStringContent: function(url, path, charset) { return __chlorisJava('get7zStringContent', [url, path, charset]); },
  getRarByteArrayContent: function(url, path) { return __chlorisJava('getRarByteArrayContent', [url, path]); },
  get7zByteArrayContent: function(url, path) { return __chlorisJava('get7zByteArrayContent', [url, path]); },
  importScript: function(path) {
    var hit = __respFromCache('importScript', [path]);
    if (hit != null) return hit;
    return __chlorisJava('importScript', [path]);
  },
  getWebViewUA: function() { return __chlorisJava('getWebViewUA', []); },
  toURL: function(url, baseUrl) { return __chlorisJava('toURL', [url, baseUrl]); },
  getSource: function() { return __chlorisJava('getSource', []); },
  getTag: function() { return __chlorisJava('getTag', []); },
  getThemeMode: function() { return __chlorisJava('getThemeMode', []); },
  getReadBookConfig: function() { return __chlorisJava('getReadBookConfig', []); },
  getReadBookConfigMap: function() {
    try { return JSON.parse(__chlorisJava('getReadBookConfigMap', [])); } catch (e) { return {}; }
  },
  getThemeConfig: function() { return __chlorisJava('getThemeConfig', []); },
  getThemeConfigMap: function() {
    try { return JSON.parse(__chlorisJava('getThemeConfigMap', [])); } catch (e) { return {}; }
  },
  longToast: function(msg) { return __chlorisJava('longToast', [msg]); },
  logType: function(type, msg) { return __chlorisJava('logType', [type, msg]); },
  openUrl: function(url, mimeType) { return __chlorisJava('openUrl', [url, mimeType]); },
  openVideoPlayer: function(url, title, isFloat) { return __chlorisJava('openVideoPlayer', [url, title, isFloat]); },
  startBrowser: function(url, title, html) { return __chlorisJava('startBrowser', [url, title, html]); },
  startBrowserAwait: function(url, title, refetch, html) {
    var hit = __respFromCache('startBrowserAwait', [url, title, refetch, html]);
    if (hit != null) return hit;
    return __chlorisJava('startBrowserAwait', [url, title, refetch, html]);
  },
  getVerificationCode: function(imageUrl) {
    var hit = __respFromCache('getVerificationCode', [imageUrl]);
    if (hit != null) return hit;
    return __chlorisJava('getVerificationCode', [imageUrl]);
  },
  ajaxTestAll: function(urls, timeout) {
    var hit = __respFromCache('ajaxTestAll', [urls, timeout]);
    if (hit != null) return hit;
    return __chlorisJava('ajaxTestAll', [urls, timeout]);
  },
  // The host returns an opaque handle; the wrapper preserves the script-facing
  // shape (`java.replaceFont(text, errorFont, correctFont)`) that Legado has.
  queryTTF: function(data, useCache) {
    var hit = __respFromCache('queryTTF', [data, useCache]);
    return { id: hit != null ? hit : __chlorisJava('queryTTF', [data, useCache]) };
  },
  queryBase64TTF: function(data) {
    var hit = __respFromCache('queryBase64TTF', [data]);
    return { id: hit != null ? hit : __chlorisJava('queryBase64TTF', [data]) };
  },
  replaceFont: function(text, errorQueryTTF, correctQueryTTF, filter) {
    return __chlorisJava('replaceFont', [
      text,
      errorQueryTTF ? errorQueryTTF.id : null,
      correctQueryTTF ? correctQueryTTF.id : null,
      filter === true
    ]);
  },
  encodeURI: function(s, enc) { return __chlorisJava('encodeURI', [s, enc]); },
  digestHex: function(data, algorithm) { return __chlorisJava('digestHex', [data, algorithm]); },
  digestBase64Str: function(data, algorithm) { return __chlorisJava('digestBase64Str', [data, algorithm]); },
  HMacHex: function(data, algorithm, key) { return __chlorisJava('HMacHex', [data, algorithm, key]); },
  HMacBase64: function(data, algorithm, key) { return __chlorisJava('HMacBase64', [data, algorithm, key]); },
  __sym: function(transformation, key, iv, data, op, kb, ib) {
    return __chlorisJava('symmetricCrypto', [transformation, key, iv, data, op, kb === true, ib === true]);
  },
  createSymmetricCrypto: function(transformation, key, iv) {
    var t = transformation, k = key, v = (iv == null ? null : iv);
    return {
      decrypt: function(data) { return java.__sym(t, k, v, data, 'decrypt', false, false); },
      decryptStr: function(data) { return java.__sym(t, k, v, data, 'decryptStr', false, false); },
      encrypt: function(data) { return java.__sym(t, k, v, data, 'encrypt', false, false); },
      encryptBase64: function(data) { return java.__sym(t, k, v, data, 'encryptBase64', false, false); },
      encryptHex: function(data) { return java.__sym(t, k, v, data, 'encryptHex', false, false); }
    };
  },
  aesDecodeToByteArray: function(str, key, transformation, iv) { return java.__sym(transformation, key, iv, str, 'decrypt', false, false); },
  aesDecodeToString: function(str, key, transformation, iv) { return java.__sym(transformation, key, iv, str, 'decryptStr', false, false); },
  aesDecodeArgsBase64Str: function(data, key, mode, padding, iv) { return java.__sym('AES/' + mode + '/' + padding, key, iv, data, 'decryptStr', true, true); },
  aesBase64DecodeToByteArray: function(str, key, transformation, iv) { return java.__sym(transformation, key, iv, str, 'decrypt', false, false); },
  aesBase64DecodeToString: function(str, key, transformation, iv) { return java.__sym(transformation, key, iv, str, 'decryptStr', false, false); },
  aesEncodeToByteArray: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encrypt', false, false); },
  aesEncodeToString: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encryptStr', false, false); },
  aesEncodeToBase64ByteArray: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encryptBase64', false, false); },
  aesEncodeToBase64String: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encryptBase64', false, false); },
  aesEncodeArgsBase64Str: function(data, key, mode, padding, iv) { return java.__sym('AES/' + mode + '/' + padding, key, iv, data, 'encryptBase64', false, false); },
  desDecodeToString: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'decryptStr', false, false); },
  desBase64DecodeToString: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'decryptStr', false, false); },
  desEncodeToString: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encryptStr', false, false); },
  desEncodeToBase64String: function(data, key, transformation, iv) { return java.__sym(transformation, key, iv, data, 'encryptBase64', false, false); },
  tripleDESDecodeStr: function(data, key, mode, padding, iv) { return java.__sym('DESede/' + mode + '/' + padding, key, iv, data, 'decryptStr', false, false); },
  tripleDESDecodeArgsBase64Str: function(data, key, mode, padding, iv) { return java.__sym('DESede/' + mode + '/' + padding, key, iv, data, 'decryptStr', true, false); },
  tripleDESEncodeBase64Str: function(data, key, mode, padding, iv) { return java.__sym('DESede/' + mode + '/' + padding, key, iv, data, 'encryptBase64', false, false); },
  tripleDESEncodeArgsBase64Str: function(data, key, mode, padding, iv) { return java.__sym('DESede/' + mode + '/' + padding, key, iv, data, 'encryptBase64', true, false); },
  t2s: function(s) { return __chlorisJava('t2s', [s]); },
  s2t: function(s) { return __chlorisJava('s2t', [s]); },
  randomUUID: function() { return __chlorisJava('randomUUID', []); },
  toNumChapter: function(s) { return __chlorisJava('toNumChapter', [s]); },
  cacheFile: function(url, saveTime) { return __chlorisJava('cacheFile', [url, saveTime]); },
  webView: function(html, url, js) { return __chlorisJava('webView', [html, url, js]); },
  webViewGetSource: function(html, url, js, regex) {
    return __chlorisJava('webViewGetSource', [html, url, js, regex]);
  },
  webViewGetOverrideUrl: function(html, url, js, regex) {
    return __chlorisJava('webViewGetOverrideUrl', [html, url, js, regex]);
  },
  getZipStringContent: function(url, path, charset) {
    return __chlorisJava('getZipStringContent', [url, path, charset]);
  },
  getZipByteArrayContent: function(url, path) {
    return __chlorisJava('getZipByteArrayContent', [url, path]);
  },
  androidId: function() { return __chlorisJava('androidId', []); },
  connect: function(url, header) {
    var args = arguments.length >= 2 ? [url, header] : [url];
    var hit = __respFromCache('connect', args);
    if (hit != null) return __asResp(hit);
    return __asResp(__chlorisJava('connect', args));
  },
  post: function(url, body, headers) {
    var args = [url, body, headers];
    var hit = __respFromCache('post', args);
    if (hit != null) return __asResp(hit);
    return __asResp(__chlorisJava('post', args));
  },
  head: function(url, headers) {
    var args = arguments.length >= 2 ? [url, headers] : [url];
    var hit = __respFromCache('head', args);
    if (hit != null) return __asResp(hit);
    return __asResp(__chlorisJava('head', args));
  }
};
''');
    return buf.toString();
  }

  static bool _safeIdent(String k) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(k);

  /// Evaluates [code] through [runtime] but guarantees the **caller** is never
  /// left hanging even when the underlying JS VM cannot be interrupted.
  ///
  /// ## Honest timeout contract
  /// * [timeout] is forwarded to [JsRuntime.eval] as a best-effort deadline
  ///   hint. A runtime that can interrupt its own VM SHOULD honour it and return
  ///   early.
  /// * Independently, the whole `eval` is wrapped in [Future.timeout]. If the
  ///   runtime does not (or cannot) honour the hint and the call is still
  ///   pending when the deadline elapses, [Future.timeout] fires and this method
  ///   throws a [DomainError] with code `js_deadline`.
  ///
  /// ## Boundary caveat -- releases the caller, does *not* necessarily stop the VM
  /// The engine holds no JS VM of its own; the VM is injected by the app and a
  /// synchronous `eval` cannot be force-cancelled from the Dart side. The
  /// underlying script may therefore keep running in the background after the
  /// deadline. That is a platform boundary we document rather than hide: the
  /// [JsDegradation] warning emitted here states so explicitly ("VM 可能仍在
  /// 后台执行"). Use it for visibility; do not assume the work has stopped.
  ///
  /// [rule] is the offending source rule, used for diagnostics and the warning.
  /// [onDegrade] defaults to [LenientJsRuntime.onDegrade] so the event joins the
  /// same degradation stream the rest of the engine observes.
  static Future<Object?> evalWithDeadline(
    JsRuntime runtime,
    String code,
    JsScope scope, {
    required Duration timeout,
    required String rule,
    JsDegradationSink? onDegrade,
  }) async {
    final sink = onDegrade ?? LenientJsRuntime.onDegrade;
    try {
      return await runtime
          .eval(code, scope, timeout: timeout)
          .timeout(timeout);
    } on TimeoutException {
      final message = [
        'JS 求值超过 ${timeout.inMilliseconds}ms 截止期限，调用方已释放；',
        '但运行中的 JS 虚拟机（QuickJS/浏览器）可能无法在引擎侧被立即中断，',
        '它可能仍在后台继续执行该脚本。',
        '（rule=${rule.trim().isEmpty ? '<empty>' : rule}）',
      ].join('');
      sink?.call(
        JsDegradation(
          code: 'js_deadline',
          message: message,
          rule: rule,
        ),
      );
      throw DomainError(
        code: 'js_deadline',
        stage: DomainErrorStage.render,
        message: message,
        cause: code,
        recoverable: true,
        retryable: true,
        suggestedAction:
            '该规则执行耗时过长；请检查书源规则是否存在死循环或耗时同步操作，或更换书源',
      );
    }
  }

  /// Prepends a book source's `jsLib` to a rule script so its top-level
  /// declarations are visible to **every** JS evaluation of that source.
  ///
  /// This is the engine's "minimal shared scope" (legado `SharedJsScope`):
  /// the lib source is re-evaluated at the top of each `evalJs` call, so
  /// declarations -- `function` / `const` / `var` at top level -- carry across
  /// evaluations within one rule-run session of a single source. The runtime
  /// evaluates this combined script after its own variable prelude, so the lib
  /// may freely reference `source`, `java`, `result`, etc.
  ///
  /// ## Boundary (out of scope, documented on purpose)
  /// Mutable global state assigned *inside* a rule (`x = 1` without `var`) is
  /// **not** shared across evaluations. Each `eval` is an independent script
  /// and the engine holds no persistent global object; whether a concrete
  /// runtime keeps implicit globals alive between `eval` calls is a runtime
  /// property, not something this engine guarantees. That mirrors legado's
  /// `scope.preventExtensions()` on the shared scope: implicit globals are
  /// rejected rather than leaked in. Do not rely on cross-eval mutable state.
  static String prependJsLib(String? jsLib, String code) {
    final lib = (jsLib ?? '').trim();
    if (lib.isEmpty) return code;
    return '$lib\n$code';
  }
}

/// Collects `java.ajax/get/connect` URLs that are only known after JS runs,
/// then fulfills them so a second eval sees real response bodies.
class JsHostSession {
  /// Methods whose real implementation is asynchronous and therefore cannot be
  /// served by [JavaHost.invokeSync].
  ///
  /// The bridge answers these with a placeholder on the first evaluation pass,
  /// collects the calls in [pending], resolves them in [fulfill], and lets the
  /// caller re-evaluate the script so the second pass sees real values.
  ///
  /// `getString`/`getStringList`/`getElement`/`getElements` are rule
  /// evaluators, not network calls, but they are just as async: leaving them
  /// out of this set sent them to `invokeSync`, which has no case for them and
  /// fell through to `default: return ''`. That made every book source using
  /// them silently resolve to an empty string.
  static const networkMethods = {
    'ajax',
    'get',
    'connect',
    'post',
    'head',
    'cacheFile',
    'webView',
    'webViewGetSource',
    'webViewGetOverrideUrl',
    'getZipStringContent',
    'getZipByteArrayContent',
    'getString',
    'getStringList',
    'getElement',
    'getElements',
    // File access is asynchronous for the same reason: the host port returns a
    // Future, so these ride the two-pass cycle rather than `invokeSync`.
    'readTxtFile',
    'readFile',
    'getFile',
    'downloadFile',
    'deleteFile',
    'getTxtInFolder',
    'unzipFile',
    'unArchiveFile',
    'un7zFile',
    'unrarFile',
    'getRarStringContent',
    'get7zStringContent',
    'getRarByteArrayContent',
    'get7zByteArrayContent',
    'importScript',
    // Host-environment calls that return data.
    'ajaxTestAll',
    'startBrowserAwait',
    'getVerificationCode',
    // Font parsing needs the bytes first, so it is async as well.
    'queryTTF',
    'queryBase64TTF',
  };

  static bool isNetwork(String name) => networkMethods.contains(name);

  JsHostSession(this.host);

  final JavaHost? host;
  final Map<String, String> cache = {};
  final List<List<Object?>> pending = [];

  Future<void> prefetchLiterals(String code) async {
    cache.addAll(await JsHostBridge.prefetchAjax(code, host));
  }

  String? ajaxHit(String url) => cache[url];

  void ajaxMiss(String url) {
    if (pending.any((call) => call.length >= 2 && call[0] == 'ajax' && call[1] == url)) {
      return;
    }
    pending.add(['ajax', url]);
  }

  String? objectHit(String method, List<Object?> args) =>
      cache['$method:${jsonEncode(args)}'];

  void objectMiss(String method, List<Object?> args) {
    final key = '$method:${jsonEncode(args)}';
    if (cache.containsKey(key)) return;
    if (pending.any((call) =>
        call.isNotEmpty &&
        call.first == method &&
        jsonEncode(call.skip(1).toList()) == jsonEncode(args))) {
      return;
    }
    pending.add([method, ...args]);
  }

  Future<bool> fulfill() async {
    if (host == null || pending.isEmpty) {
      pending.clear();
      return false;
    }
    final work = List<List<Object?>>.from(pending);
    pending.clear();
    for (final call in work) {
      final method = call.first.toString();
      final args = call.skip(1).toList();
      try {
        if (method == 'ajax') {
          final url = args.isEmpty ? '' : args.first.toString();
          cache[url] = (await host!.ajax(url)) ?? '';
        } else {
          final result = await host!.invoke(method, args);
          cache['$method:${jsonEncode(args)}'] = encodeResult(result);
        }
      } catch (_) {
        // A single failing rule must not abort the whole bridge pass: the
        // script then sees an empty string for that one call and the caller's
        // normal error handling decides what to do.
        cache['$method:${jsonEncode(args)}'] =
            method == 'getString' ? '""' : 'null';
      }
    }
    return true;
  }

  /// JSON-encodes a rule result, degrading parser nodes to their markup.
  ///
  /// `java.getElement` / `java.getElements` return parser nodes rather than
  /// strings. Legado hands the script a real jsoup `Element` on which it can
  /// call `.text()` / `.attr()`; this bridge is JSON-only, so nodes are
  /// serialised as their markup string. That keeps `getStringList` exact and
  /// makes the element helpers return usable markup instead of an empty
  /// placeholder. It also stops `jsonEncode` from throwing — which previously
  /// escaped [fulfill] and dropped the entire script into the lenient
  /// fallback.
  static String encodeResult(Object? result) {
    try {
      return jsonEncode(result);
    } on JsonUnsupportedObjectError {
      return jsonEncode(stringify(result));
    }
  }

  static Object? stringify(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is List) return [for (final e in value) stringify(e)];
    if (value is Map) {
      return {
        for (final e in value.entries) e.key.toString(): stringify(e.value),
      };
    }
    return value.toString();
  }
}
