import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;

import '../widgets/meow.dart';

Future<WebViewResult?> evaluateInBrowser(WebViewRequest request) async {
  return null;
}

class LoginWebEmbed extends StatefulWidget {
  const LoginWebEmbed({
    super.key,
    required this.html,
    required this.baseUrl,
    required this.onMessage,
  });

  final String html;
  final String baseUrl;
  final void Function(Map<String, dynamic> message) onMessage;

  @override
  State<LoginWebEmbed> createState() => _LoginWebEmbedState();
}

class _LoginWebEmbedState extends State<LoginWebEmbed> {
  late Map<String, TextEditingController> _ctrls;
  late _ParsedForm? _form;

  @override
  void initState() {
    super.initState();
    _form = _parseLoginForm(widget.html, widget.baseUrl);
    _ctrls = {
      for (final f in _form?.fields ?? const <_Field>[])
        f.name: TextEditingController(text: f.value),
    };
  }

  @override
  void didUpdateWidget(LoginWebEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _form = _parseLoginForm(widget.html, widget.baseUrl);
      _ctrls = {
        for (final f in _form?.fields ?? const <_Field>[])
          f.name: TextEditingController(text: f.value),
      };
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final form = _form;
    if (form == null) return;
    final data = <String, String>{};
    for (final e in _ctrls.entries) {
      data[e.key] = e.value.text;
    }
    widget.onMessage({
      'type': 'chloris-wv-submit',
      'action': form.action,
      'method': form.method,
      'data': data,
    });
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    if (form == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('未解析到登录表单。可用系统浏览器打开后粘贴 Cookie。'),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (form.captchaUrl != null && form.captchaUrl!.isNotEmpty) ...[
          const Text('验证码'),
          const SizedBox(height: 8),
          Image.network(
            proxiedImageUrl(form.captchaUrl!),
            height: 64,
            errorBuilder: (_, _, _) => const Text('验证码图片加载失败'),
          ),
          const SizedBox(height: 12),
        ],
        for (final f in form.fields)
          TextField(
            controller: _ctrls[f.name],
            obscureText: f.type == 'password',
            decoration: InputDecoration(
              labelText: f.label.isEmpty ? f.name : f.label,
            ),
          ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _submit, child: const Text('提交登录')),
      ],
    );
  }
}

class _Field {
  _Field({
    required this.name,
    required this.type,
    required this.value,
    required this.label,
  });
  final String name;
  final String type;
  final String value;
  final String label;
}

class _ParsedForm {
  _ParsedForm({
    required this.action,
    required this.method,
    required this.fields,
    this.captchaUrl,
  });
  final String action;
  final String method;
  final List<_Field> fields;
  final String? captchaUrl;
}

_ParsedForm? _parseLoginForm(String html, String baseUrl) {
  final doc = html_parser.parse(html);
  final forms = doc.querySelectorAll('form');
  if (forms.isEmpty) return null;
  var picked = forms.first;
  for (final f in forms) {
    final raw = f.outerHtml.toLowerCase();
    if (raw.contains('password') ||
        raw.contains('captcha') ||
        raw.contains('验证码') ||
        raw.contains('login')) {
      picked = f;
      break;
    }
  }
  final actionRaw = picked.attributes['action'] ?? baseUrl;
  final action = Uri.parse(baseUrl).resolve(actionRaw).toString();
  final method = (picked.attributes['method'] ?? 'POST').toUpperCase();
  final fields = <_Field>[];
  for (final input in picked.querySelectorAll('input, select, textarea')) {
    final type = (input.attributes['type'] ?? 'text').toLowerCase();
    if (type == 'hidden' ||
        type == 'submit' ||
        type == 'button' ||
        type == 'image') {
      if (type == 'hidden') {
        final name = input.attributes['name'] ?? '';
        if (name.isEmpty) continue;
        fields.add(
          _Field(
            name: name,
            type: type,
            value: input.attributes['value'] ?? '',
            label: name,
          ),
        );
      }
      continue;
    }
    final name = input.attributes['name'] ?? '';
    if (name.isEmpty) continue;
    fields.add(
      _Field(
        name: name,
        type: type,
        value: input.attributes['value'] ?? '',
        label:
            input.attributes['placeholder'] ??
            input.attributes['aria-label'] ??
            name,
      ),
    );
  }
  String? captcha;
  for (final img in doc.querySelectorAll('img')) {
    final src = img.attributes['src'] ?? '';
    final alt = (img.attributes['alt'] ?? '').toLowerCase();
    final blob = (src + alt + (img.id) + (img.className)).toLowerCase();
    if (blob.contains('captcha') ||
        blob.contains('vcode') ||
        blob.contains('verify') ||
        blob.contains('验证码')) {
      captcha = Uri.parse(baseUrl).resolve(src).toString();
      break;
    }
  }
  return _ParsedForm(
    action: action,
    method: method,
    fields: fields,
    captchaUrl: captcha,
  );
}

bool get loginEmbedIsRealWebView => false;
