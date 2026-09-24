import 'dart:convert';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'source_library_provider.dart';

class SourceEditScreen extends ConsumerStatefulWidget {
  const SourceEditScreen({super.key, required this.source});

  final BookSource source;

  @override
  ConsumerState<SourceEditScreen> createState() => _SourceEditScreenState();
}

class _SourceEditScreenState extends ConsumerState<SourceEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _group;
  late final TextEditingController _search;
  late final TextEditingController _explore;
  late final TextEditingController _login;
  late final TextEditingController _loginUi;
  late final TextEditingController _loginCheck;
  late final TextEditingController _header;
  late final TextEditingController _jsLib;
  late final TextEditingController _rate;
  late final TextEditingController _comment;
  late final TextEditingController _pattern;
  late final TextEditingController _coverJs;
  late final TextEditingController _ruleSearch;
  late final TextEditingController _ruleExplore;
  late final TextEditingController _ruleInfo;
  late final TextEditingController _ruleToc;
  late final TextEditingController _ruleContent;
  late final TextEditingController _json;
  bool _enabled = true;
  bool _exploreOn = true;
  bool _cookieJar = true;
  int _type = BookSourceType.text;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _name = TextEditingController(text: s.bookSourceName);
    _url = TextEditingController(text: s.bookSourceUrl);
    _group = TextEditingController(text: s.bookSourceGroup ?? '');
    _search = TextEditingController(text: s.searchUrl ?? '');
    _explore = TextEditingController(text: s.exploreUrl ?? '');
    _login = TextEditingController(text: s.loginUrl ?? '');
    _loginUi = TextEditingController(text: s.loginUi ?? '');
    _loginCheck = TextEditingController(text: s.loginCheckJs ?? '');
    _header = TextEditingController(text: s.header ?? '');
    _jsLib = TextEditingController(text: s.jsLib ?? '');
    _rate = TextEditingController(text: s.concurrentRate ?? '');
    _comment = TextEditingController(text: s.bookSourceComment ?? '');
    _pattern = TextEditingController(text: s.bookUrlPattern ?? '');
    _coverJs = TextEditingController(text: s.coverDecodeJs ?? '');
    final enc = const JsonEncoder.withIndent('  ');
    _ruleSearch = TextEditingController(
      text: s.ruleSearch == null ? '' : enc.convert(s.ruleSearch!.toJson()),
    );
    _ruleExplore = TextEditingController(
      text: s.ruleExplore == null ? '' : enc.convert(s.ruleExplore!.toJson()),
    );
    _ruleInfo = TextEditingController(
      text: s.ruleBookInfo == null ? '' : enc.convert(s.ruleBookInfo!.toJson()),
    );
    _ruleToc = TextEditingController(
      text: s.ruleToc == null ? '' : enc.convert(s.ruleToc!.toJson()),
    );
    _ruleContent = TextEditingController(
      text: s.ruleContent == null ? '' : enc.convert(s.ruleContent!.toJson()),
    );
    _json = TextEditingController(text: enc.convert(s.toJson()));
    _enabled = s.enabled;
    _exploreOn = s.enabledExplore;
    _cookieJar = s.enabledCookieJar != false;
    _type = s.bookSourceType;
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _group.dispose();
    _search.dispose();
    _explore.dispose();
    _login.dispose();
    _loginUi.dispose();
    _loginCheck.dispose();
    _header.dispose();
    _jsLib.dispose();
    _rate.dispose();
    _comment.dispose();
    _pattern.dispose();
    _coverJs.dispose();
    _ruleSearch.dispose();
    _ruleExplore.dispose();
    _ruleInfo.dispose();
    _ruleToc.dispose();
    _ruleContent.dispose();
    _json.dispose();
    super.dispose();
  }

  void _save() {
    Map<String, dynamic> raw;
    try {
      raw = jsonDecode(_json.text) as Map<String, dynamic>;
    } catch (_) {
      raw = Map<String, dynamic>.from(widget.source.toJson());
    }
    raw['bookSourceName'] = _name.text.trim();
    raw['bookSourceUrl'] = _url.text.trim();
    raw['bookSourceGroup'] = _group.text.trim();
    raw['searchUrl'] = _search.text.trim();
    raw['exploreUrl'] = _explore.text.trim();
    raw['loginUrl'] = _login.text.trim();
    raw['loginUi'] = _loginUi.text.trim();
    raw['loginCheckJs'] = _loginCheck.text.trim();
    raw['header'] = _header.text.trim();
    raw['jsLib'] = _jsLib.text.trim();
    raw['concurrentRate'] = _rate.text.trim();
    raw['bookSourceComment'] = _comment.text.trim();
    raw['bookUrlPattern'] = _pattern.text.trim();
    raw['coverDecodeJs'] = _coverJs.text.trim();
    void putRule(String key, String text) {
      final t = text.trim();
      if (t.isEmpty) return;
      try {
        raw[key] = jsonDecode(t);
      } catch (_) {}
    }
    putRule('ruleSearch', _ruleSearch.text);
    putRule('ruleExplore', _ruleExplore.text);
    putRule('ruleBookInfo', _ruleInfo.text);
    putRule('ruleToc', _ruleToc.text);
    putRule('ruleContent', _ruleContent.text);
    raw['enabled'] = _enabled;
    raw['enabledExplore'] = _exploreOn;
    raw['enabledCookieJar'] = _cookieJar;
    raw['bookSourceType'] = _type;
    final src = BookSource.fromJson(raw);
    ref.read(importedSourcesProvider.notifier).upsert(src);
    ref.read(sourceEnabledOverrideProvider.notifier).setEnabled(src.bookSourceUrl, _enabled);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑书源'),
        actions: [
          IconButton(
            tooltip: '粘贴覆盖 JSON',
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final t = data?.text;
              if (t == null || t.trim().isEmpty) return;
              setState(() => _json.text = t);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已粘贴到完整 JSON，保存后生效')),
                );
              }
            },
            icon: const Icon(Icons.content_paste),
          ),
          IconButton(
            tooltip: '复制 JSON',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _json.text));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制书源 JSON')),
                );
              }
            },
            icon: const Icon(Icons.copy),
          ),
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('启用'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          SwitchListTile(
            title: const Text('启用发现'),
            value: _exploreOn,
            onChanged: (v) => setState(() => _exploreOn = v),
          ),
          InputDecorator(
            decoration: const InputDecoration(labelText: '书源类型'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _type,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: BookSourceType.text, child: Text('文本')),
                  DropdownMenuItem(value: BookSourceType.audio, child: Text('音频')),
                  DropdownMenuItem(value: BookSourceType.image, child: Text('图片/漫画')),
                  DropdownMenuItem(value: BookSourceType.file, child: Text('文件')),
                  DropdownMenuItem(value: BookSourceType.video, child: Text('视频')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
            ),
          ),
          TextField(controller: _name, decoration: const InputDecoration(labelText: '名称')),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL')),
          TextField(controller: _group, decoration: const InputDecoration(labelText: '分组')),
          TextField(controller: _search, decoration: const InputDecoration(labelText: 'searchUrl')),
          TextField(controller: _explore, maxLines: 3, decoration: const InputDecoration(labelText: 'exploreUrl')),
          TextField(controller: _login, decoration: const InputDecoration(labelText: 'loginUrl')),
          TextField(
            controller: _loginUi,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'loginUi'),
          ),
          TextField(
            controller: _loginCheck,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'loginCheckJs'),
          ),
          TextField(controller: _header, maxLines: 2, decoration: const InputDecoration(labelText: 'header')),
          TextField(
            controller: _jsLib,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'jsLib'),
          ),
          TextField(
            controller: _rate,
            decoration: const InputDecoration(
              labelText: 'concurrentRate',
              hintText: '如 0/1000 或 8',
            ),
          ),
          SwitchListTile(
            title: const Text('CookieJar'),
            value: _cookieJar,
            onChanged: (v) => setState(() => _cookieJar = v),
          ),
          TextField(controller: _comment, maxLines: 2, decoration: const InputDecoration(labelText: '注释')),
          TextField(
            controller: _pattern,
            decoration: const InputDecoration(labelText: 'bookUrlPattern'),
          ),
          TextField(
            controller: _coverJs,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'coverDecodeJs'),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('ruleSearch JSON'),
            children: [
              TextField(
                controller: _ruleSearch,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('ruleExplore JSON'),
            children: [
              TextField(
                controller: _ruleExplore,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('ruleBookInfo JSON'),
            children: [
              TextField(
                controller: _ruleInfo,
                maxLines: 6,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('ruleToc JSON'),
            children: [
              TextField(
                controller: _ruleToc,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('ruleContent JSON'),
            children: [
              TextField(
                controller: _ruleContent,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
          ExpansionTile(
            title: const Text('完整 JSON'),
            children: [
              TextField(
                controller: _json,
                maxLines: 16,
                style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
