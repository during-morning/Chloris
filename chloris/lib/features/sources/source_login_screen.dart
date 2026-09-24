import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/persist/credentials.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import 'interactive_login_page.dart';

/// legado 登录：应用内登录页/验证码，Cookie 回写 CookieStore；系统浏览器 + 粘贴为兜底。
class SourceLoginScreen extends ConsumerStatefulWidget {
  const SourceLoginScreen({super.key, required this.source});

  final BookSource source;

  @override
  ConsumerState<SourceLoginScreen> createState() => _SourceLoginScreenState();
}

class _SourceLoginScreenState extends ConsumerState<SourceLoginScreen> {
  late final TextEditingController _cookie;
  String? _checkResult;
  bool _checking = false;
  final _fieldCtrls = <String, TextEditingController>{};
  List<Map<String, dynamic>> _fields = const [];

  @override
  void initState() {
    super.initState();
    final url = widget.source.bookSourceUrl;
    final existing = ref.read(cookieStoreProvider).get(url);
    _cookie = TextEditingController(text: existing);
    _parseLoginUi();
  }

  void _parseLoginUi() {
    final raw = widget.source.loginUi?.trim() ?? '';
    if (raw.isEmpty) return;
    try {
      final d = jsonDecode(raw);
      final list = d is List ? d : (d is Map ? [d] : const []);
      final fields = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final id = (m['id'] ?? m['name'] ?? '').toString();
        if (id.isEmpty) continue;
        fields.add(m);
        _fieldCtrls[id] = TextEditingController();
      }
      _fields = fields;
      // Login form values are credentials, so they live in the encrypted vault
      // rather than in nearby plain-text preferences entries.
      CredentialStore.loginFields(widget.source.bookSourceUrl).then((saved) {
        if (saved.isEmpty || !mounted) return;
        saved.forEach((k, v) {
          _fieldCtrls[k]?.text = v;
        });
        setState(() {});
      });
    } catch (_) {}
  }

  void _applyFields() {
    final parts = <String>[];
    for (final f in _fields) {
      final id = (f['id'] ?? f['name'] ?? '').toString();
      final v = _fieldCtrls[id]?.text.trim() ?? '';
      if (v.isEmpty) continue;
      parts.add(id + '=' + v);
    }
    if (parts.isEmpty) return;
    _cookie.text = parts.join('; ');
    final dump = <String, String>{};
    for (final e in _fieldCtrls.entries) {
      dump[e.key] = e.value.text;
    }
    CredentialStore.setLoginFields(widget.source.bookSourceUrl, dump);
  }

  @override
  void dispose() {
    _cookie.dispose();
    for (final c in _fieldCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _targetUrl =>
      widget.source.loginUrl ?? widget.source.bookSourceUrl;

  Future<void> _open() async {
    final uri = Uri.tryParse(_targetUrl);
    if (uri != null) await launchUrl(uri);
  }

  Future<void> _openInApp() async {
    final result = await Navigator.of(context).push<WebViewResult>(
      MaterialPageRoute(
        builder: (_) => InteractiveLoginPage(
          request: WebViewRequest(
            url: _targetUrl,
            interactive: true,
            title: widget.source.bookSourceName,
          ),
          http: ref.read(httpPortProvider),
          cookieStore: ref.read(cookieStoreProvider),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if ((result.cookie ?? '').isNotEmpty) {
      _cookie.text = result.cookie!;
    }
    _save(pop: false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录会话已写回该书源')));
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) return;
    setState(() => _cookie.text = t);
  }

  void _save({bool pop = true}) {
    final url = widget.source.bookSourceUrl;
    final cookies = ref.read(cookieStoreProvider);
    cookies.set(url, _cookie.text.trim());
    if (widget.source.loginUrl != null && widget.source.loginUrl!.isNotEmpty) {
      cookies.set(widget.source.loginUrl!, _cookie.text.trim());
    }
    if (pop && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cookie 已写入该书源')));
      Navigator.pop(context);
    }
  }

  Future<void> _verify() async {
    _save(pop: false);
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    try {
      final cookies = ref.read(cookieStoreProvider);
      final http = ref.read(httpPortProvider);
      final loginCheck = ref.read(loginCheckUseCaseProvider);
      final url = widget.source.bookSourceUrl;
      final httpRes = await http.send(HttpRequestSpec(url: url));
      final js = widget.source.loginCheckJs?.trim() ?? '';
      if (js.isEmpty) {
        setState(() {
          _checking = false;
          _checkResult =
              '已请求 ' +
              httpRes.code.toString() +
              '，正文 ' +
              (httpRes.body?.length ?? 0).toString() +
              ' 字。未配置 loginCheckJs。';
        });
        return;
      }
      final java = JavaHost(http: http, cookieStore: cookies);
      for (final e in _fieldCtrls.entries) {
        java.put(e.key, e.value.text);
      }
      final vars = <String, Object?>{
        'result': httpRes.body ?? '',
        'baseUrl': httpRes.url,
        'java': java,
        'source': widget.source,
        'cookie': _cookie.text.trim(),
      };
      for (final e in _fieldCtrls.entries) {
        vars[e.key] = e.value.text;
      }
      final lib = widget.source.jsLib?.trim() ?? '';
      final code = lib.isEmpty ? js : lib + String.fromCharCode(10) + js;
      final eval = await loginCheck.eval(code, JsScope(variables: vars));
      setState(() {
        _checking = false;
        _checkResult = 'loginCheckJs 结果：' + (eval?.toString() ?? '(空)');
      });
    } catch (e) {
      setState(() {
        _checking = false;
        _checkResult = '校验失败：' + e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = widget.source.loginCheckJs?.trim() ?? '';
    final ui = widget.source.loginUi?.trim() ?? '';
    return Scaffold(
      appBar: AppBar(title: Text('登录 · ' + widget.source.bookSourceName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SelectableText(_targetUrl),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openInApp,
            icon: const Icon(Icons.login),
            label: const Text('应用内登录 / 验证码'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('系统浏览器打开'),
          ),
          const SizedBox(height: 16),
          if (_fields.isNotEmpty) ...[
            Text('loginUi 表单', style: Theme.of(context).textTheme.titleSmall),
            for (final f in _fields)
              TextField(
                controller: _fieldCtrls[(f['id'] ?? f['name']).toString()],
                obscureText: (f['type']?.toString() ?? '') == 'password',
                decoration: InputDecoration(
                  labelText: (f['name'] ?? f['id'] ?? '').toString(),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(_applyFields),
                child: const Text('填入 Cookie 框'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Text('从浏览器复制 Cookie 后粘贴保存（Web 无内嵌 WebView 时的等效登录）'),
          const SizedBox(height: 8),
          TextField(
            controller: _cookie,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Cookie',
              hintText: 'name=value; name2=value2',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: const Text('从剪贴板粘贴'),
              ),
              OutlinedButton.icon(
                onPressed: _checking ? null : _verify,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: const Text('校验登录'),
              ),
            ],
          ),
          if (_checkResult != null) ...[
            const SizedBox(height: 12),
            Text(_checkResult!),
          ],
          if (ui.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('loginUi', style: Theme.of(context).textTheme.titleSmall),
            SelectableText(ui, style: const TextStyle(fontSize: 12)),
          ],
          if (check.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('loginCheckJs', style: Theme.of(context).textTheme.titleSmall),
            SelectableText(check, style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('保存 Cookie')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final store = ref.read(cookieStoreProvider);
              store.remove(widget.source.bookSourceUrl);
              if (widget.source.loginUrl != null &&
                  widget.source.loginUrl!.isNotEmpty) {
                store.remove(widget.source.loginUrl!);
              }
              _cookie.clear();
              setState(() => _checkResult = '已清除 Cookie');
            },
            child: const Text('清除 Cookie'),
          ),
        ],
      ),
    );
  }
}
