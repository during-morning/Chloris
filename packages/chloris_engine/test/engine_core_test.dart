import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:chloris_engine/chloris_engine.dart';
import 'package:chloris_engine/src/analyze/analyze_by_regex.dart';
import 'package:test/test.dart';

void main() {
  test('RuleAnalyzer splits && || without breaking brackets', () {
    final a = RuleAnalyzer('class.item&&class.row');
    expect(a.splitRule(['&&', '||', '%%']), ['class.item', 'class.row']);
    expect(a.elementsType, '&&');
    final b = RuleAnalyzer(r'$.data[?(@.id==1)]||$.list');
    final parts = b.splitRule(['&&', '||', '%%']);
    expect(parts.first.contains('data'), isTrue);
    expect(b.elementsType, '||');
  });

  test('RuleAnalyzer honors escaped quotes inside nested groups', () {
    final rule = r'''$.data[?(@.label=="a\"&&b")]||$.fallback''';
    final analyzer = RuleAnalyzer(rule);
    expect(analyzer.splitRule(['&&', '||', '%%']), [
      r'''$.data[?(@.label=="a\"&&b")]''',
      r'$.fallback',
    ]);
    expect(analyzer.elementsType, '||');
  });

  test('RuleAnalyzer keeps template literals and mixed groups atomic', () {
    final rule = r'`value && ${items[0]["name"]}`&&tail';
    expect(RuleAnalyzer(rule).splitRule(['&&']), [
      r'`value && ${items[0]["name"]}`',
      'tail',
    ]);
  });

  test('RuleCompiler ignores markers inside balanced selector arguments', () {
    final program = const RuleCompiler().compile(
      'div:contains(@js:literal)@text',
    );
    expect(program.steps, hasLength(1));
    expect(program.steps.single.mode, RuleMode.css);
    expect(program.steps.single.expression, 'div:contains(@js:literal)@text');
  });

  test(
    'regex groups keep embedded && inside the balanced expression',
    () async {
      final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
        ..setContent('a&&b');
      expect(await rule.getElements(':(a&&b)'), [
        ['a&&b', 'a&&b'],
      ]);
    },
  );

  test('CSS analyzer extracts list and text', () {
    const html = '''
    <div id="list">
      <div class="item"><a href="/b/1">书A</a><span class="author">甲</span></div>
      <div class="item"><a href="/b/2">书B</a><span class="author">乙</span></div>
    </div>
    ''';
    final css = AnalyzeByCss(html);
    final items = css.getElements('class.item');
    expect(items.length, 2);
    expect(css.getString('class.item@tag.a@text').split('\n').first, '书A');
    expect(css.getStringList('class.item@tag.a@href'), ['/b/1', '/b/2']);
  });

  test('@text preserves <br> as newline (换行消失回归)', () {
    // 多数站点正文靠 <br> 分行；e.text 只拼文本节点会把多行正文压成一行。
    const html =
        '<div id="content">　　段一第一行。<br>段一第二行。<br><br>'
        '　　段二第一行。</div>';
    final css = AnalyzeByCss(html);
    final out = css.getString('id.content@text');
    expect(out.contains('\n'), isTrue, reason: '换行应保留：$out');
    expect(out.contains('段一第二行。\n'), isTrue, reason: '行级换行应保留：$out');
  });

  test('CSS analyzer supports Legado :contains selector', () {
    const html = '''
    <div class="item">普通内容</div>
    <div class="item">目标内容<span>附加</span></div>
    ''';
    final css = AnalyzeByCss(html);
    expect(css.getElements('@css:div.item:contains(目标)').length, 1);
    expect(css.getString('@css:div.item:contains("目标")@text'), '目标内容附加');
    expect(css.getElements('div.item:contains(目标)').length, 1);
    expect(css.getElements('@css:div.item:contains(目标), div.item').length, 2);
    final page = AnalyzeByCss(
      '<div class="page"><a href="/next">下一页</a></div>',
    );
    expect(page.getStringList('div.page a:contains(下一页)@href'), ['/next']);
    expect(page.getStringList('tag.a:contains(下一页)@href'), ['/next']);
    expect(page.getStringList('@css:a:contains(下一页)@href'), ['/next']);
    expect(page.getStringList('@css:div:containsOwn(下一页)@text'), isEmpty);
    expect(page.getStringList('@css:a:containsOwn(下一页)@text'), ['下一页']);
    expect(page.getStringList('@css:a:not(:contains(下一页))@text'), isEmpty);
  });

  test('CSS result operator ignores @ inside selector values', () {
    final css = AnalyzeByCss(
      '<a data-label="@" href="/at">at</a>'
      '<a data-label="other" href="/other">other</a>',
    );
    expect(css.getStringList('@css:a[data-label="@"]@href'), ['/at']);
    expect(css.getStringList('@css:a[data-label="@"]:contains("at")@href'), [
      '/at',
    ]);
  });

  test('CSS attribute selectors are not mistaken for index operators', () {
    final css = AnalyzeByCss('<a href="/a">A</a><a href="/b">B</a>');
    expect(css.getStringList('a[href]@text'), ['A', 'B']);
  });

  test('CSS index ranges expand inclusively with negative indexes', () {
    final css = AnalyzeByCss(
      '<ul><li>0</li><li>1</li><li>2</li><li>3</li></ul>',
    );
    expect(css.getStringList('tag.li[1:2]'), ['1', '2']);
    expect(css.getStringList('tag.li[-1]'), ['3']);
  });

  test('JSONPath reads nested arrays', () {
    final json = jsonEncode({
      'Data': {
        'Items': [
          {'BookName': '仙逆', 'Author': '耳根'},
          {'BookName': '求魔', 'Author': '耳根'},
        ],
      },
    });
    final jp = AnalyzeByJsonPath(json);
    expect(jp.getStringList(r'$.Data.Items[*].BookName'), ['仙逆', '求魔']);
    expect(jp.getString(r'$.Data.Items[0].Author'), '耳根');
  });

  test('XPath reads links', () {
    const html =
        '<html><body><div class="c"><a href="/x">T</a></div></body></html>';
    final xp = AnalyzeByXPath(html);
    expect(xp.getStringList('//a/@href'), ['/x']);
    expect(xp.getString('//a/text()'), 'T');
  });

  test('XPath following-sibling and class predicate', () {
    const html = '''
    <div>
      <span class="name">仙逆</span>
      <span class="author">耳根</span>
    </div>
    ''';
    final xp = AnalyzeByXPath(html);
    expect(xp.getString("//span[@class='name']/text()"), '仙逆');
    expect(
      xp.getString("//span[@class='name']/following-sibling::span/text()"),
      '耳根',
    );
  });

  test('XPath text equality and child-exists predicates', () {
    final xp = AnalyzeByXPath(
      '<ul><li><span>目标</span></li><li><span>其他</span></li></ul>',
    );
    expect(xp.getString('//li[span][text()="目标"]'), '目标');
  });

  test('XPath supports chained predicates, functions and positions', () {
    const html = '''
    <ul>
      <li class="entry">  Chapter 1  </li>
      <li class="entry skip" data-skip="1">Chapter 2</li>
      <li class="entry">Chapter 3</li>
    </ul>
    ''';
    final xp = AnalyzeByXPath(html);
    expect(
      xp.getStringList("//li[contains(@class, 'entry')][position()>1]/text()"),
      ['Chapter 2', 'Chapter 3'],
    );
    expect(
      xp.getStringList(
        '''//li[contains(@class, "entry") and not(@data-skip)]/text()''',
      ),
      ['Chapter 1', 'Chapter 3'],
    );
    expect(xp.getString('//li[last()-1]/text()'), 'Chapter 2');
    expect(
      xp.getStringList("//li[normalize-space(text())='Chapter 3']/text()"),
      ['Chapter 3'],
    );
    final slashXp = AnalyzeByXPath('<div>Chapter/3</div>');
    expect(
      slashXp.getString("//div[contains(text(), 'Chapter/3')]/text()"),
      'Chapter/3',
    );
  });

  test('XPath supports absolute document root and descendant-or-self axes', () {
    final xp = AnalyzeByXPath(
      '<html><body><div><span>正文</span></div></body></html>',
    );
    expect(xp.getString('/html/body/div/span/text()'), '正文');
    expect(xp.getString('descendant-or-self::html/body/div/span/text()'), '正文');
    expect(xp.getString('//span/ancestor::div/@class'), '');
  });

  test('Regex && chains through successive patterns', () {
    const html = '''
    <li><a href="/b/1">仙逆</a></li>
    <li><a href="/b/2">求魔</a></li>
    <p>noise</p>
    ''';
    final groups = AnalyzeByRegex.getElements(html, [
      r'<li[\s\S]*?</li>',
      r'href="([^"]+)"[^>]*>([^<]+)',
    ]);
    expect(groups.length, 2);
    expect(groups.first[1], '/b/1');
    expect(groups.first[2], '仙逆');
    expect(groups.last[2], '求魔');
  });

  test('AnalyzeRule getString CSS', () async {
    const html = '<div id="intro">你好&amp;世界</div>';
    final rule = AnalyzeRule(jsRuntime: const NoJsRuntime())
      ..setContent(html, 'https://ex.com');
    expect(await rule.getString('id.intro@text'), '你好&世界');
  });

  test('htmlUnescape supports HTML4 named and hexadecimal entities', () {
    expect(htmlUnescape('&#x4E2D; &mdash; &hellip; &copy;'), '中 — … ©');
    expect(htmlUnescape('&#x1F600;'), '😀');
    expect(htmlUnescape('&doesnotexist;'), '&doesnotexist;');
  });

  test('Legado embedded rules are evaluated instead of erased', () async {
    final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent('<div class="chapter">嵌套正文</div>');
    expect(await rule.getString('{{@@div.chapter@text}}'), '嵌套正文');
    expect(await rule.getString(r'{{@@.chapter@text}}'), '嵌套正文');
  });

  test('@put evaluates selector value before @get reads it', () async {
    final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent('<div id="content">变量正文</div>');
    expect(await rule.getString('@put:{x:"id.content@text"}@get:{x}'), '变量正文');
  });

  test('nested JSONPath interpolation preserves extracted value', () async {
    final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent('{"items":[{"title":"JSON正文"}]}');
    expect(await rule.getString(r'{{$.items[0].title}}'), 'JSON正文');
  });

  test('layout pos round-trip', () {
    final layout = TextChapterLayout(width: 360, height: 640, fontSize: 18);
    final pages = layout.layout('${'字' * 800}\n${'行' * 400}');
    expect(pages.length, greaterThan(1));
    final idx = layout.pageIndexForPos(pages, pages[1].startPos);
    expect(idx, 1);
  });

  test('TXT splits by heading regex', () {
    final text = StringBuffer();
    for (var i = 1; i <= 5; i++) {
      text.writeln('第$i章 标题$i');
      // 章节间隔必须 >1000 字：legado 的规则评分把 <100 字间隔判为误报、
      // <1000 字间隔不计入正样本，短章节会被整条规则否决回退按大小分章。
      text.writeln('内容' * 600);
    }
    final bytes = Uint8List.fromList(utf8.encode(text.toString()));
    final book = Book(bookUrl: 'file://a.txt', originName: 'a.txt', name: '测');
    final tf = TextFile(book, bytes);
    final chapters = tf.getChapterList([
      TxtTocRule(name: '目录', rule: r'^第.+章.*$', enable: true),
    ]);
    expect(chapters.length, greaterThanOrEqualTo(3));
    expect(tf.getContent(chapters.first), contains('内容'));
  });

  test('EPUB accepts single-quoted metadata and resolves NCX spine paths', () {
    final archive = Archive();
    void add(String path, String text) {
      final data = utf8.encode(text);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    add(
      'META-INF/container.xml',
      "<container><rootfile full-path='OPS/package.opf'/></container>",
    );
    add('OPS/package.opf', """
      <package xmlns:dc='http://purl.org/dc/elements/1.1/'>
        <metadata><dc:title>测试 EPUB</dc:title><dc:creator>测试作者</dc:creator></metadata>
        <manifest>
          <item id='ncx' media-type='application/x-dtbncx+xml' href='toc.ncx'/>
          <item id='c1' media-type='application/xhtml+xml' href='text/ch1.xhtml'/>
        </manifest>
        <spine toc='ncx'><itemref idref='c1'/></spine>
      </package>
      """);
    add('OPS/toc.ncx', """
      <ncx><navMap><navPoint><navLabel><text>第一章</text></navLabel>
        <content src='text/ch1.xhtml'/></navPoint></navMap></ncx>
      """);
    add('OPS/text/ch1.xhtml', '<html><body><p>这是正文</p></body></html>');

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final book = Book(bookUrl: 'file://test.epub');
    final epub = EpubFile(book, bytes);
    final chapters = epub.getChapterList();

    expect(book.name, '测试 EPUB');
    expect(book.author, '测试作者');
    expect(chapters, hasLength(1));
    expect(chapters.first.title, '第一章');
    expect(chapters.first.url, 'OPS/text/ch1.xhtml');
    expect(epub.getContent(chapters.first), contains('这是正文'));
  });

  test('EPUB NCX fragments split chapters sharing one XHTML resource', () {
    final archive = Archive();
    void add(String path, String text) {
      final data = utf8.encode(text);
      archive.addFile(ArchiveFile(path, data.length, data));
    }

    add(
      'META-INF/container.xml',
      '<container><rootfile full-path="package.opf"/></container>',
    );
    add('package.opf', '''
      <package xmlns:dc="http://purl.org/dc/elements/1.1/">
        <metadata><dc:title>片段书</dc:title></metadata>
        <manifest><item id="ncx" media-type="application/x-dtbncx+xml" href="toc.ncx"/></manifest>
      </package>
    ''');
    add('toc.ncx', '''
      <ncx><navMap>
        <navPoint><navLabel><text>一</text></navLabel><content src="book.xhtml#one"/></navPoint>
        <navPoint><navLabel><text>二</text></navLabel><content src="book.xhtml#two"/></navPoint>
      </navMap></ncx>
    ''');
    add(
      'book.xhtml',
      '<html><body><h1 id="one">一</h1><p>A</p><h1 id="two">二</h1><p>B</p></body></html>',
    );

    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    final epub = EpubFile(Book(bookUrl: 'file://fragments.epub'), bytes);
    final chapters = epub.getChapterList();
    expect(chapters, hasLength(2));
    expect(epub.getContent(chapters[0]), contains('A'));
    expect(epub.getContent(chapters[0]), isNot(contains('B')));
    expect(epub.getContent(chapters[1]), contains('B'));
  });

  test('flowImages extracts img src', () {
    final ch = BookChapter(
      url: 'https://ex.com/c/1',
      baseUrl: 'https://ex.com/c/1',
      title: '1',
    );
    final urls = flowImages(
      ch,
      '<p><img src="/p/1.jpg"><img src="https://cdn/x.png"></p>',
    );
    expect(urls.length, 2);
    expect(urls.first, startsWith('https://ex.com'));
  });

  test('ContentProcessor removes ads', () async {
    final book = Book(bookUrl: 'u', name: '书', origin: 'o');
    final chapter = BookChapter(url: 'c', title: '第一章', bookUrl: 'u');
    final p = ContentProcessor.forBook(
      book,
      allRules: [
        ReplaceRule(name: 'ad', pattern: '广告', replacement: '', isRegex: false),
      ],
    );
    final out = await p.process(book: book, chapter: chapter, content: '第一章\n正文广告内容');
    expect(out.text.contains('广告'), isFalse);
  });

  test('formatJs rewrites chapter titles', () async {
    const html = '''
    <div id="list">
      <a href="/1.html">第一章</a>
      <a href="/2.html">第二章</a>
    </div>
    ''';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
        formatJs: 'result',
      ),
    );
    final book = Book(
      bookUrl: 'https://ex.com/book/1',
      origin: 'https://ex.com',
    );
    final chapters = await web.getChapterList(source, book);
    expect(chapters.length, 2);
    expect(chapters.first.title, '第一章');
  });

  test('TOC removes site navigation links from normal-sized lists', () async {
    final links = [
      ('第一章 开始', '/c/1'),
      ('第二章 继续', '/c/2'),
      ('第三章 转折', '/c/3'),
      ('第四章 结果', '/c/4'),
      ('第五章 结尾', '/c/5'),
      ('登录账号', '/login'),
      ('桌面快捷', '/shortcut'),
      ('名家文集', '/category/famous'),
    ];
    final html =
        '<div id="list">' +
        links.map((e) => '<a href="${e.$2}">${e.$1}</a>').join() +
        '</div>';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/book/1');
    final chapters = await web.getChapterList(source, book);
    expect(chapters.map((e) => e.title), [
      '第一章 开始',
      '第二章 继续',
      '第三章 转折',
      '第四章 结果',
      '第五章 结尾',
    ]);
  });

  test('short TOC still drops leading homepage chrome', () async {
    const html = '''
    <div id="list">
      <a href="/">首页</a>
      <a href="/1.html">第一章</a>
      <a href="/2.html">第二章</a>
    </div>
    ''';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/book/1');
    final chapters = await web.getChapterList(source, book);
    expect(chapters.map((e) => e.title), ['第一章', '第二章']);
  });

  test('TOC reuses page rule and keeps vip/volume flags', () async {
    const html = '''
    <div id="list">
      <div class="vol"><a href="/v">卷一</a></div>
      <div class="vip"><a href="/1.html">第一章</a></div>
      <div><a href="/2.html">第二章</a></div>
      <div><a href="/3.html">第三章</a></div>
      <div><a href="/4.html">第四章</a></div>
    </div>
    ''';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: r'@css:#list > div',
        chapterName: 'tag.a@text',
        chapterUrl: 'tag.a@href',
        isVolume: 'class.vol@text',
        isVip: 'class.vip@text',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/book/1', origin: 'https://ex.com');
    final chapters = await web.getChapterList(source, book);
    expect(chapters.map((e) => e.title), [
      '卷一',
      '第一章',
      '第二章',
      '第三章',
      '第四章',
    ]);
    expect(chapters[0].isVolume, isTrue);
    expect(chapters[1].isVip, isTrue);
    expect(chapters[2].isVip, isFalse);
  });

  test('first-page multi next TOC URLs stay ordered', () async {
    final web = WebBook(
      http: _PagedHttp({
        '/toc':
            '<div id="list">'
            '<a href="/c/1">第一章</a><a href="/c/2">第二章</a>'
            '<a href="/c/3">第三章</a><a href="/c/4">第四章</a>'
            '<a href="/c/5">第五章</a><a href="/c/6">第六章</a>'
            '<a href="/c/7">第七章</a><a href="/c/8">第八章</a>'
            '</div>'
            '<a class="next" href="/toc2">下一页</a>'
            '<a class="next" href="/toc3">下下页</a>',
        '/toc2': '<div id="list"><a href="/c/9">第九章</a></div>',
        '/toc3': '<div id="list"><a href="/c/10">第十章</a></div>',
      }),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
        nextTocUrl: 'class.next@href',
      ),
    );
    final book = Book(
      bookUrl: 'https://ex.com/book/1',
      tocUrl: 'https://ex.com/toc',
      origin: 'https://ex.com',
    );
    final seen = <int>[];
    final chapters = await web.getChapterList(
      source,
      book,
      maxPages: 8,
      onPartial: (part) => seen.add(part.length),
    );
    expect(chapters.map((e) => e.title).toList(), [
      '第一章',
      '第二章',
      '第三章',
      '第四章',
      '第五章',
      '第六章',
      '第七章',
      '第八章',
      '第九章',
      '第十章',
    ]);
    expect(seen, isNotEmpty);
    expect(seen.first, lessThanOrEqualTo(chapters.length));
  });

  test('cache-busting next TOC URLs do not walk the same page', () async {
    var hits = 0;
    final web = WebBook(
      http: _PagedHttp(
        {
          '/toc':
              '<div id="list"><a href="/c/1">第一章</a><a href="/c/2">第二章</a></div>'
              '<a class="next" href="/toc?t=2">下一页</a>',
          '/toc?t=2':
              '<div id="list"><a href="/c/1">第一章</a><a href="/c/2">第二章</a></div>'
              '<a class="next" href="/toc?t=3">下一页</a>',
        },
        onSend: () => hits++,
      ),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
        nextTocUrl: 'class.next@href',
      ),
    );
    final book = Book(
      bookUrl: 'https://ex.com/book/1',
      tocUrl: 'https://ex.com/toc',
      origin: 'https://ex.com',
    );
    final chapters = await web.getChapterList(source, book, maxPages: 8);
    expect(chapters.map((e) => e.title), ['第一章', '第二章']);
    expect(hits, 1);
  });

  test('compiled rule programs are reused across splitSourceRule calls', () {
    final a = AnalyzeRule(jsRuntime: const LenientJsRuntime());
    final first = a.splitSourceRule('id.list@tag.a@text');
    final second = a.splitSourceRule('id.list@tag.a@text');
    expect(first.single.rule, second.single.rule);
    expect(
      identical(
        RuleCompileCache.program('id.list@tag.a@text'),
        RuleCompileCache.program('id.list@tag.a@text'),
      ),
      isTrue,
    );
  });

  test('SearchMerge groups same name+author', () {
    final a = SearchBook(bookUrl: '1', origin: 'a', name: '仙逆', author: '耳根');
    final b = SearchBook(bookUrl: '2', origin: 'b', name: '仙逆', author: '耳根');
    final merged = SearchMerge.merge(existing: [a], incoming: [b], key: '仙逆');
    expect(merged.length, 1);
    expect(merged.first.origins, containsAll(['a', 'b']));
  });

  test(
    'search list keeps per-item variables inherited from request rules',
    () async {
      final web = WebBook(
        http: _HtmlHttp('''
        <div class="seed">继承作者</div>
        <ul>
          <li><a href="/1">书一</a></li>
          <li><a href="/2">书二</a></li>
        </ul>
      '''),
        jsRuntime: const LenientJsRuntime(),
      );
      final source = BookSource(
        bookSourceUrl: 'https://vars.example',
        searchUrl: 'https://vars.example/search?q={{key}}',
        ruleSearch: SearchRule(
          bookList: '@put:{seed:"class.seed@text"}tag.li',
          name: 'tag.a@text',
          author: '@get:{seed}',
          bookUrl: 'tag.a@href',
        ),
      );
      // Request-level @put values are inherited by every list item.
      final result = await web.searchBook(source, '书');
      expect(result, hasLength(2));
      expect(result.map((b) => b.author), everyElement('继承作者'));
    },
  );

  test('searchBook applies BookList-style name/author filter', () async {
    final web = WebBook(
      http: _HtmlHttp('''
        <ul>
          <li><a href="/1">仙逆</a><span class="author">耳根</span></li>
          <li><a href="/2">无关长篇</a><span class="author">路人</span></li>
        </ul>
      '''),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://filter.example',
      searchUrl: 'https://filter.example/search?q={{key}}',
      ruleSearch: SearchRule(
        bookList: 'tag.li',
        name: 'tag.a@text',
        author: 'class.author@text',
        bookUrl: 'tag.a@href',
      ),
    );
    final all = await web.searchBook(source, '仙逆');
    expect(all.map((b) => b.name), ['仙逆', '无关长篇']);
    final filtered = await web.searchBook(
      source,
      '仙逆',
      filter: (name, author, kind) => name.contains('仙逆') || author.contains('仙逆'),
    );
    expect(filtered.map((b) => b.name), ['仙逆']);
  });

  test('JSON bookList without \$ prefix', () async {
    final json = jsonEncode({
      'data': {
        'books': [
          {'name': '仙逆', 'id': 1},
          {'name': '求魔', 'id': 2},
        ],
      },
    });
    final rule = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent(json, 'https://ex.com');
    final items = await rule.getElements('data.books');
    expect(items.length, 2);
    final item = AnalyzeRule(jsRuntime: const LenientJsRuntime())
      ..setContent(items.first, 'https://ex.com');
    expect(await item.getString('name'), '仙逆');
  });

  test('ExploreKind.parse skips decorative tag headers', () {
    const raw = '''
[{"title":"----------     🏷标签     ----------","url":""},{"title":"玄幻","url":"https://ex.com/xuan"},{"title":"————","url":"https://ex.com/x"}]
''';
    final kinds = ExploreKind.parse(raw);
    expect(kinds.map((k) => k.title), ['玄幻']);
  });

  test('Lenient JS extracts search URL', () async {
    final js = const LenientJsRuntime();
    final url = await js.evalToString(
      "var key=key; 'https://ex.com/s?q='+key;",
      JsScope(variables: {'key': '仙逆', 'page': 1, 'result': ''}),
    );
    expect(url, contains('https://ex.com/s'));
  });

  test('AnalyzeUrl page alternatives vs numeric step', () async {
    final alt1 = AnalyzeUrl(
      mUrl: '<search.html,/search/{{key}}/{{page}}.html>',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      key: '仙逆',
      page: 1,
      baseUrl: 'https://ex.com',
    );
    await alt1.init();
    expect(alt1.url, contains('search.html'));
    expect(alt1.url.contains('/search/'), isFalse);

    final alt2 = AnalyzeUrl(
      mUrl: '<search.html,/search/{{key}}/{{page}}.html>',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      key: '仙逆',
      page: 2,
      baseUrl: 'https://ex.com',
    );
    await alt2.init();
    expect(alt2.url, contains('/search/'));
    expect(alt2.url, contains('2.html'));

    final num = AnalyzeUrl(
      mUrl: 'https://ex.com/s/<1,2,3>.html',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      key: 'k',
      page: 2,
      baseUrl: 'https://ex.com',
    );
    await num.init();
    // 对齐 Legado-E AnalyzeUrl.kt:206-216：页模板按索引 pages[page-1]，不做步长外推 → pages[1] = '2'
    expect(num.url, contains('/s/2.html'));
  });

  test('XPath combinators &&', () {
    const html = '''
    <div>
      <span class="name">仙逆</span>
      <span class="author">耳根</span>
    </div>
    ''';
    final xp = AnalyzeByXPath(html);
    final list = xp.getStringList(
      "//span[@class='name']/text()&&//span[@class='author']/text()",
    );
    expect(list, containsAll(['仙逆', '耳根']));
  });

  test('AnalyzeUrl interpolates key and page', () async {
    final url = AnalyzeUrl(
      mUrl: 'https://ex.com/s?q={{key}}&p={{page}}',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      key: '仙逆',
      page: 2,
      baseUrl: 'https://ex.com',
    );
    await url.init();
    expect(url.url, contains('p=2'));
    expect(url.url, contains(Uri.encodeQueryComponent('仙逆')));
  });

  test('AnalyzeUrl encodes search key with option charset', () async {
    final url = AnalyzeUrl(
      mUrl:
          'https://ex.com/s,{"method":"POST","charset":"gbk","body":"searchkey={{key}}"}',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      key: '中文',
      page: 1,
      baseUrl: 'https://ex.com',
    );
    await url.init();
    expect(url.charset, 'gbk');
    expect(url.body, contains(encodeQueryWithCharset('中文', 'gbk')));
    expect(url.body, isNot(contains(Uri.encodeQueryComponent('中文'))));
  });

  test('getAbsoluteUrl keeps legado page tokens', () {
    expect(
      getAbsoluteUrl('https://wodushu.com', '/fenlei/xuanhuan/{{page}}/'),
      'https://wodushu.com/fenlei/xuanhuan/{{page}}/',
    );
    expect(
      getAbsoluteUrl('https://a.com', '/s/<1,1>.html'),
      'https://a.com/s/<1,1>.html',
    );
    expect(
      restoreLegadoPlaceholders('https://a.com/x/%7B%7Bpage%7D%7D/'),
      'https://a.com/x/{{page}}/',
    );
    final withOpt = getAbsoluteUrl(
      'https://ex.com',
      '/api,{"method":"POST","body":"p={{page}}"}',
    );
    expect(withOpt.startsWith('https://ex.com/api,'), isTrue);
    expect(withOpt, contains('{{page}}'));
    expect(withOpt, contains('"method"'));
  });

  test('htmlFormat strips tags and keeps text', () {
    final t = htmlFormat('<div><script>x</script><p>你好&amp;世界</p></div>');
    expect(t, contains('你好'));
    expect(t, contains('世界'));
    expect(t, isNot(contains('<p>')));
    expect(t, isNot(contains('script')));
  });

  test('ExploreKind.parse && and pair arrays', () {
    final kinds = ExploreKind.parse(
      '全部::https://wap.ciweimao.com/book_list/0/{{page}}&&玄幻::https://wap.ciweimao.com/book_list/x/{{page}}',
    );
    expect(kinds.length, 2);
    expect(kinds.first.title, '全部');
    expect(kinds.last.url, contains('{{page}}'));

    final pairs = ExploreKind.parse(
      r'@js:JSON.stringify([["连载","/lianzai/{{page}}"],["玄幻","/xuanhuan/{{page}}"]]);',
    );
    expect(pairs.map((k) => k.title), ['连载', '玄幻']);
    expect(pairs.first.url, contains('{{page}}'));
  });

  test('CSS tag.a on the <a> itself', () {
    const html =
        '<div id="list"><a href="/c/1">第一章</a><a href="/c/2">第二章</a></div>';
    final css = AnalyzeByCss(html);
    final items = css.getElements('id.list@tag.a');
    expect(items.length, 2);
    final item = AnalyzeByCss(items.first);
    expect(item.getString('tag.a@text'), '第一章');
    expect(item.getString('href'), '/c/1');
  });

  test('AnalyzeUrl restores encoded {{page}}', () async {
    final url = AnalyzeUrl(
      mUrl: 'https://ex.com/fenlei/%7B%7Bpage%7D%7D/',
      http: _FakeHttp(),
      jsRuntime: const NoJsRuntime(),
      page: 3,
      baseUrl: 'https://ex.com',
    );
    await url.init();
    expect(url.url, 'https://ex.com/fenlei/3/');
  });

  test('AnalyzeUrl applies bodyJs to response body, not request body', () async {
    final http = _RecordingHttp();
    final analyze = AnalyzeUrl(
      mUrl:
          'https://ex.com/api,{"method":"POST","body":"v=old","bodyJs":"result.replace(\'old\',\'new\')"}',
      http: http,
      jsRuntime: const LenientJsRuntime(),
    );
    final response = await analyze.getStrResponse();
    expect(http.last?.method, 'POST');
    // 对齐 Legado-E AnalyzeUrl.kt:507-510：bodyJs 作用于响应 body，请求 body 保持不变
    expect(http.last?.body, 'v=old');
    expect(response.body, 'response-new');
  });

  test('AnalyzeUrl encodes form values once', () async {
    final http = _RecordingHttp();
    final analyze = AnalyzeUrl(
      mUrl:
          'https://ex.com/api,{"method":"POST","headers":{"Content-Type":"application/x-www-form-urlencoded"},"body":"q=你好&x=a%20b"}',
      http: http,
      jsRuntime: const LenientJsRuntime(),
    );
    await analyze.getStrResponse();
    expect(http.last?.body, contains('q=%E4%BD%A0%E5%A5%BD'));
    expect(http.last?.body, contains('x=a%20b'));
  });

  test('AnalyzeUrl type option returns Legado hex bytes', () async {
    final http = _RecordingHttp();
    final analyze = AnalyzeUrl(
      mUrl: 'https://ex.com/file,{"type":"binary"}',
      http: http,
      jsRuntime: const LenientJsRuntime(),
    );
    final response = await analyze.getStrResponse();
    expect(response.body, '000fff');
    expect(http.last, isNull);
  });

  test('AnalyzeUrl forwards routing metadata to HttpPort', () async {
    final http = _RecordingHttp();
    final analyze = AnalyzeUrl(
      mUrl:
          'https://ex.com/a,{"origin":"https://origin.test","dnsIp":"1.2.3.4","serverID":"edge","proxy":"http://proxy"}',
      http: http,
      jsRuntime: const LenientJsRuntime(),
    );
    await analyze.getStrResponse();
    expect(http.last?.origin, 'https://origin.test');
    expect(http.last?.dnsIp, '1.2.3.4');
    expect(http.last?.serverID, 'edge');
    expect(http.last?.proxy, 'http://proxy');
  });

  test('chapter list from raw <a> items', () async {
    const html = '''
    <div id="list">
      <dl>
        <dt>正文</dt>
        <dd><a href="/1.html">第一章 起</a></dd>
        <dd><a href="/2.html">第二章 承</a></dd>
        <dd><a href="/3.html">第三章 转</a></dd>
      </dl>
    </div>
    ''';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
      ),
    );
    final book = Book(
      bookUrl: 'https://ex.com/book/1',
      origin: 'https://ex.com',
    );
    final chapters = await web.getChapterList(source, book);
    expect(chapters.length, 3);
    expect(chapters.first.title, contains('第一章'));
    expect(chapters.first.url, contains('/1.html'));
  });

  test('book info and first TOC page reuse the same fetched HTML', () async {
    var calls = 0;
    final http = _HtmlHttp(
      '<div id="info"><h1>书名</h1></div>'
      '<div id="list">'
      '<a href="/1.html">第一章</a>'
      '<a href="/2.html">第二章</a>'
      '<a href="/3.html">第三章</a>'
      '</div>',
      onSend: () => calls++,
    );
    final web = WebBook(http: http, jsRuntime: const LenientJsRuntime());
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleBookInfo: BookInfoRule(name: 'id.info@tag.h1@text'),
      ruleToc: TocRule(
        chapterList: 'id.list@tag.a',
        chapterName: 'text',
        chapterUrl: 'href',
      ),
    );
    final book = Book(
      bookUrl: 'https://ex.com/book/1',
      origin: 'https://ex.com',
    );
    await web.getBookInfo(source, book);
    final chapters = await web.getChapterList(source, book);
    expect(book.name, '书名');
    expect(chapters.length, 3);
    expect(calls, 1);
  });

  test('content fallback from #content', () async {
    const html = '''
    <html><body>
      <div id="content"><p>这是正文第一段，需要足够长才能通过兜底阈值。这是正文第二段。后文继续。</p></div>
    </body></html>
    ''';
    final web = WebBook(
      http: _HtmlHttp(html),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final ch = BookChapter(
      url: 'https://ex.com/c/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    final text = await web.getContent(source, book, ch);
    expect(text, contains('正文第一段'));
  });

  test('content rule miss is classified as ContentEmpty', () async {
    final web = WebBook(
      http: _HtmlHttp('<html><body><p>无匹配节点</p></body></html>'),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(content: 'id.does-not-exist@text'),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final chapter = BookChapter(
      url: 'https://ex.com/c/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    expect(
      () => web.getContent(source, book, chapter),
      throwsA(isA<ContentEmptyException>()),
    );
  });

  test('content pagination keeps extracted pages when hop limit is reached', () async {
    final web = WebBook(
      http: _PagedHttp({
        '/1': '<div id="content">第一页足够长的正文AAA。</div><a class="next" href="/2">下一页</a>',
        '/2': '<div id="content">第二页足够长的正文BBB。</div><a class="next" href="/3">下一页</a>',
        '/3': '<div id="content">第三页足够长的正文CCC。</div>',
      }),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(
        content: 'id.content@text',
        nextContentUrl: 'class.next@href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final chapter = BookChapter(
      url: 'https://ex.com/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    final text = await web.getContent(source, book, chapter, maxHops: 1);
    expect(text, contains('AAA'));
    expect(text, isNot(contains('BBB')));
  });

  test('cache-busting next URLs do not walk the same page to the hop limit', () async {
    var hits = 0;
    final web = WebBook(
      http: _PagedHttp(
        {
          '/1':
              '<div id="content">同一页足够长的正文AAA。</div>'
              '<a class="next" href="/1?t=2">下一页</a>',
          '/1?t=2':
              '<div id="content">同一页足够长的正文AAA。</div>'
              '<a class="next" href="/1?t=3">下一页</a>',
          '/1?t=3':
              '<div id="content">同一页足够长的正文AAA。</div>'
              '<a class="next" href="/1?t=4">下一页</a>',
        },
        onSend: () => hits++,
      ),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(
        content: 'id.content@text',
        nextContentUrl: 'class.next@href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final chapter = BookChapter(
      url: 'https://ex.com/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    final text = await web.getContent(source, book, chapter);
    expect(text, contains('AAA'));
    expect(hits, 1);
  });

  test('content pagination throws only when hop limit yields no text', () async {
    final web = WebBook(
      http: _PagedHttp({
        '/1': '<div id="empty"></div><a class="next" href="/2">下一页</a>',
        '/2': '<div id="empty"></div><a class="next" href="/3">下一页</a>',
        '/3': '<div id="empty"></div><a class="next" href="/4">下一页</a>',
      }),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(
        content: 'id.missing@text',
        nextContentUrl: 'class.next@href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final chapter = BookChapter(
      url: 'https://ex.com/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    await expectLater(
      web.getContent(source, book, chapter, maxHops: 2),
      throwsA(
        isA<DomainError>().having(
          (e) => e.code,
          'code',
          'content_pagination_limit',
        ),
      ),
    );
  });

  test('first-page multi next URLs stay ordered and skip next chapter', () async {
    final web = WebBook(
      http: _PagedHttp({
        '/1':
            '<div id="content">第一页足够长的正文AAA。</div>'
            '<a class="next" href="/2">2</a>'
            '<a class="next" href="/3">3</a>'
            '<a class="next" href="/next-chapter">下一章</a>',
        '/2': '<div id="content">第二页足够长的正文BBB。</div>',
        '/3': '<div id="content">第三页足够长的正文CCC。</div>',
        '/next-chapter': '<div id="content">下一章不该出现DDD。</div>',
      }),
      jsRuntime: const LenientJsRuntime(),
    );
    final source = BookSource(
      bookSourceUrl: 'https://ex.com',
      ruleContent: ContentRule(
        content: 'id.content@text',
        nextContentUrl: 'class.next@href',
      ),
    );
    final book = Book(bookUrl: 'https://ex.com/b', origin: 'https://ex.com');
    final chapter = BookChapter(
      url: 'https://ex.com/1',
      title: '1',
      bookUrl: book.bookUrl,
    );
    final text = await web.getContent(
      source,
      book,
      chapter,
      nextChapterUrl: 'https://ex.com/next-chapter',
    );
    expect(text, contains('AAA'));
    expect(text, contains('BBB'));
    expect(text, contains('CCC'));
    expect(text, isNot(contains('DDD')));
    expect(text.indexOf('AAA'), lessThan(text.indexOf('BBB')));
    expect(text.indexOf('BBB'), lessThan(text.indexOf('CCC')));
  });

  test('htmlFormat keeps multiline img src as a canonical tag', () {
    const raw = '''<p>段</p><img src="http://rs.sfacg.com/web/novel/images/Upload
Pic/2018/08/c3d63e50-cd4e-49d6-b6e9-a892d8b4a469.jpg"
>''';
    final out = htmlFormat(raw);
    expect(out, contains('段'));
    expect(out, contains('<img src="'));
    expect(out, contains('UploadPic/2018/08/'));
    expect(out.contains('\nPic'), isFalse);
    expect(out.contains('Upload Pic'), isFalse);
    final ch = BookChapter(
      url: 'https://book.sfacg.com/c/1',
      baseUrl: 'https://book.sfacg.com/c/1',
      title: '1',
    );
    final urls = flowImages(ch, out);
    expect(urls, hasLength(1));
    expect(urls.first, contains('UploadPic'));
    final blocks = splitContentBlocks(out, baseUrl: ch.baseUrl);
    expect(blocks.any((b) => b.isImage), isTrue);
    expect(
      blocks.firstWhere((b) => b.isImage).value,
      contains('http://rs.sfacg.com'),
    );
  });

  test('collapseRepeatedText drops intro tripled by nested CSS matches', () {
    expect(collapseRepeatedText('简介甲\n简介甲\n简介甲'), '简介甲');
    expect(collapseRepeatedText('你好世界你好世界你好世界'), '你好世界');
    expect(collapseRepeatedText('第一段\n第二段\n第一段\n第二段\n第一段\n第二段'), '第一段\n第二段');
    expect(collapseJoinedStrings(['第一段\n第二段', '第一段', '第二段']), '第一段\n第二段');
  });

  test('CSS 多命中按 legado 语义 \\n 连接（父/子命中各自保留，不再折叠）', () {
    const html = '''
    <div class="intro"><p class="intro">这是一本很长的玄幻小说简介。主角从凡间崛起。</p></div>
    ''';
    final css = AnalyzeByCss(html);
    final intro = css.getString('class.intro@text');
    // 对齐 legado AnalyzeByJSoup.kt:59：多命中 joinToString("\\n")——
    // div 与 p 都命中 class.intro，各自输出一次（父文本含子文本）。
    // 简介去重由 sanitizeBookIntro 在 webBook 层负责。
    expect(RegExp('崛起。').allMatches(intro).length, 2);
    expect(intro.split('\n'), hasLength(2));
    expect(intro, contains('玄幻小说简介'));
  });

  test('regex replacement expands \$1 instead of leaving it literal', () async {
    const html = '<div id="intro">前言这是一个不正经的模拟器文，嗯，就这样</div>';
    final rule = AnalyzeRule(jsRuntime: const NoJsRuntime())
      ..setContent(html, 'https://ex.com');
    final out = await rule.getString(r'id.intro@text##.*(不正经.+)$##$1');
    expect(out, contains('不正经的模拟器文'));
    expect(out.contains(r'$1'), isFalse);
  });

  test('sanitizeBookIntro drops title, metadata, \$1 and copies', () {
    const raw = '''
我的模拟不对劲
综合信息：依文洛华/2025/5/420:23:03
这是一个不正经的模拟器文，嗯，就这样我的模拟不对劲
\$1
这是一个不正经的模拟器文，嗯，就这样
''';
    final out = sanitizeBookIntro(raw, name: '我的模拟不对劲');
    expect(out, '这是一个不正经的模拟器文，嗯，就这样');
    expect(out.contains(r'$1'), isFalse);
    expect(out.contains('综合信息'), isFalse);
    expect(out.contains('我的模拟不对劲'), isFalse);
  });

  test('formatBookName collapses doubled title', () {
    expect(formatBookName('我的模拟不对劲我的模拟不对劲'), '我的模拟不对劲');
    expect(formatBookName('你也想来我的模拟战败馆?\n签约\n奇幻世界主题征文'), '你也想来我的模拟战败馆?');
  });

  test('chrome sort tabs are not books', () {
    expect(isChromeBookName('最多收藏'), isTrue);
    expect(isChromeBookName('综合排序'), isTrue);
    expect(isChromeBookName('全部显示'), isTrue);
    expect(isChromeBookName('最多援力'), isTrue);
    expect(isChromeBookName('归档'), isTrue);
    expect(isChromeBookName('分类'), isTrue);
    expect(isChromeBookName('标签'), isTrue);
    expect(isChromeBookName('斗破苍穹'), isFalse);
    expect(isChromeBookName('全部成为F'), isFalse);
    expect(isChromeBookUrl('https://a.com/sort?order=hot'), isTrue);
    expect(isChromeBookUrl('https://a.com/book/123'), isFalse);
  });

  test('extractPlayableUrl reads first http line', () {
    expect(
      extractPlayableUrl('　　\nhttps://cdn.ex/a.mp3\nlyric'),
      'https://cdn.ex/a.mp3',
    );
  });

  test('RateLimiter.shared reuses the instance for a source', () {
    RateLimiter.resetShared();
    final a = RateLimiter.shared('https://ex.com', '1000');
    final b = RateLimiter.shared('https://ex.com', '1000');
    expect(identical(a, b), isTrue);
    expect(
      identical(a, RateLimiter.shared('https://other.com', '1000')),
      isFalse,
    );
  });

  test('RateLimiter serializes windowed acquires', () async {
    RateLimiter.resetShared();
    final limiter = RateLimiter.shared('https://ex.com/p', '20/60000');
    final started = DateTime.now();
    await Future.wait(List.generate(8, (_) => limiter.acquire()));
    expect(DateTime.now().difference(started).inMilliseconds, lessThan(500));
  });

  test('ParallelChapterFetch fills a pool and retries failures', () async {
    final have = <int>{};
    var fetches = 0;
    final chapters = [for (var i = 0; i < 12; i++) (index: i, title: 'c$i')];
    have.addAll({0, 1, 2});
    final failedOnce = <int>{};
    final snap = await ParallelChapterFetch.run(
      chapters: chapters,
      pool: 4,
      retries: 1,
      isCancelled: () => false,
      isDone: (i) async => have.contains(i),
      fetch: (i) async {
        fetches++;
        if (i == 11 && failedOnce.add(i)) return false;
        have.add(i);
        return true;
      },
    );
    expect(snap.total, 12);
    expect(snap.done, 12);
    expect(snap.failed, 0);
    expect(have.length, 12);
    expect(fetches, greaterThanOrEqualTo(9));
  });

  test('ParallelChapterFetch stops scheduling after cancel', () async {
    var started = 0;
    var cancel = false;
    final chapters = [for (var i = 0; i < 20; i++) (index: i, title: 'c$i')];
    await ParallelChapterFetch.run(
      chapters: chapters,
      pool: 2,
      retries: 0,
      isCancelled: () => cancel,
      isDone: (i) async => false,
      fetch: (i) async {
        started++;
        if (started >= 2) cancel = true;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return true;
      },
    );
    expect(started, lessThan(20));
  });

  test('JSONPath getString/getStringList honor && ||', () {
    final jp = AnalyzeByJsonPath(jsonEncode({'a': '1', 'b': '2'}));
    expect(jp.getStringList(r'$.a&&$.b'), ['1', '2']);
    expect(jp.getString(r'$.a&&$.b'), '1\n2');
    expect(jp.getString(r'$.missing||$.a'), '1');
    expect(jp.getStringList(r'$.missing||$.b'), ['2']);
  });

  test('DebugLog buffers events and caps', () {
    EngineLimits.debugVerbose = true;
    DebugLog.clear();
    DebugLog.log('a', 'one');
    DebugLog.error('a', 'bad');
    expect(DebugLog.buffer.length, 2);
    expect(DebugLog.buffer.last.state, -1);
    expect(DebugLog.forTag('a').length, 2);
  });
}

class _FakeHttp implements HttpPort {
  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    return StrResponse(url: spec.url, body: '<html></html>');
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    return Uint8List(0);
  }

  @override
  void cancelInFlight() {}
}

class _RecordingHttp implements HttpPort {
  HttpRequestSpec? last;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    last = spec;
    return StrResponse(url: spec.url, body: 'response-old');
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    return Uint8List.fromList([0, 15, 255]);
  }

  @override
  void cancelInFlight() {}
}

class _HtmlHttp implements HttpPort {
  _HtmlHttp(this.html, {this.onSend});
  final String html;
  final void Function()? onSend;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    onSend?.call();
    return StrResponse(url: spec.url, body: html);
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    return Uint8List(0);
  }

  @override
  void cancelInFlight() {}
}

class _PagedHttp implements HttpPort {
  _PagedHttp(this.pages, {this.onSend});
  final Map<String, String> pages;
  final void Function()? onSend;

  @override
  Future<StrResponse> send(HttpRequestSpec spec) async {
    onSend?.call();
    final path = Uri.tryParse(spec.url)?.path ?? spec.url;
    return StrResponse(
      url: spec.url,
      body: pages[spec.url] ?? pages[path] ?? '',
    );
  }

  @override
  Future<Uint8List> getBytes(String url, {Map<String, String>? headers}) async {
    return Uint8List(0);
  }

  @override
  void cancelInFlight() {}
}
