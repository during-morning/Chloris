#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate oracle fixtures for Chloris rule-engine bilateral parity.

Samples rule *patterns* from real book sources (chloris/assets/sources/*.json)
and crafts a realistic input sample (HTML / JSON / text) plus an expectation
note per fixture. Output: tool/legado_oracle/fixtures/{css,json,regex-multiline,
stage1-regex}.json as JSON arrays.

Only backend-pure rule fragments are kept (no `##` replace, no `@js:`, no
`{{}}`, no `@put`) so the partial Legado oracle (AnalyzeByJSoup/Regex/JSonPath,
which does NOT run the higher-level @js/## pipeline) and Chloris exercise the
same backend semantics. Divergences therefore reflect real engine differences.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
FIX = os.path.join(HERE, "fixtures")

# ---------------------------------------------------------------------------
# CSS fixtures
# Each: (id, rule, html, expect, src_real_rule)
# ---------------------------------------------------------------------------
CSS = [
    ("css-001", "a@text",
     "<div><a>Alpha</a><a>Beta</a><a>Gamma</a></div>",
     "提取全部 <a> 文本，按文档顺序返回。",
     "基础选择器 a@text（广泛见于 ruleSearch.bookList/name）"),

    ("css-002", "a@href",
     "<div><a href=\"/b/1\">一</a><a href=\"/b/2\">二</a></div>",
     "提取 <a> 的 href 属性值。",
     "a@href（ruleSearch.bookUrl 主流写法）"),

    ("css-003", "img@src",
     "<div><img src=\"https://x.co/a.jpg\"></div>",
     "提取 <img> 的 src 属性。",
     "img@src / @src（封面/图片规则）"),

    ("css-004", ".name@text",
     "<span class=\"name\">秦牧</span>",
     "按 class 选择元素并取文本。",
     ".name@text（ruleBookInfo.name 常见）"),

    ("css-005", "#title@text",
     "<h1 id=\"title\">诡秘之主</h1>",
     "按 id 选择并取文本。",
     "#title@text（详情页标题）"),

    ("css-006", "p@text",
     "<p>作者：爱潜水的乌贼</p><p>分类：玄幻</p>",
     "按标签取全部段落文本。",
     "p@text（简介/信息段落）"),

    ("css-007", ":contains(作者)@text",
     "<div><p>作者：爱潜水的乌贼</p><p>简介：一段文字</p></div>",
     "伪类 :contains 选择包含『作者』的元素并取文本。",
     "span:contains(作者：)@text（ruleBookInfo.author 源自真实书源）"),

    ("css-008", "dd:contains(最新章节：) > a@text",
     "<dl><dd>最新章节：<a>第1章 开端</a></dd></dl>",
     "复合：dd:contains 定位 + 子代 > a 取文本。",
     "dd:contains(最新章节：) > a@text（真实书源 tocUrl/lastChapter）"),

    ("css-009", "dt:contains(作者)+dd a@text",
     "<dl><dt>作者</dt><dd><a>猫腻</a></dd></dl>",
     "相邻兄弟 +dd 再取 descendant a 文本。",
     "dt:contains(作者)+dd a@text（真实书源 author 规则）"),

    ("css-010", "@css:a:contains(下一页)@href",
     "<div><a href=\"/p/2\">下一页</a><a href=\"/p/1\">上一页</a></div>",
     "@css: 前缀走原生 CSS 选择器，:contains 命中『下一页』取 href。",
     "@css:a:contains(下一页)@href（分页 nextUrl 规则）"),

    ("css-011", "span:contains(作者：)@text",
     "<div><span>作者：烽火戏诸侯</span><span>状态：连载</span></div>",
     ":contains 命中带冒号文本的元素取文本。",
     "span:contains(作者：)@text（真实书源）"),

    ("css-012", "tag.a.0@href",
     "<div><a href=\"/x/0\">零</a><a href=\"/x/1\">一</a><a href=\"/x/2\">二</a></div>",
     "tag.a 前缀 + 索引 0 取第一个 <a> 的 href。",
     "tag.a.0@href（真实书源 bookUrl）"),

    ("css-013", "a.0@text",
     "<p><a>零</a><a>一</a><a>二</a><a>三</a></p>",
     "索引 0 取第一个 <a> 文本。",
     "a.0@text（索引选择）"),

    ("css-014", "a.1@text",
     "<p><a>零</a><a>一</a><a>二</a></p>",
     "索引 1 取第二个 <a> 文本。",
     "a.1@text（索引选择）"),

    ("css-015", "a.0:2@text",
     "<p><a>zero</a><a>one</a><a>two</a><a>three</a></p>",
     "旧式索引 a.0:2 —— 取索引集合 {0,2} 两个元素（两引擎应一致）。",
     "a.0:2@text（索引区间，源自审计既有样例）"),

    ("css-016", "span.0:1@text",
     "<div><span>甲</span><span>乙</span><span>丙</span></div>",
     "span.0:1 取索引集合 {0,1}。",
     "span.0:1@text（真实书源 info 区间）"),

    ("css-017", "a[0:2]@text",
     "<p><a>zero</a><a>one</a><a>two</a><a>three</a></p>",
     "方括号区间 a[0:2] 取 0..2 闭区间（含两端），三个元素。",
     "tag.div[0:2]（方括号索引写法）"),

    ("css-018", "a[-1]@text",
     "<p><a>zero</a><a>one</a><a>two</a></p>",
     "负索引 -1 取最后一个元素。",
     "a.-1@text（负索引）"),

    ("css-019", "a[!0]@text",
     "<p><a>zero</a><a>one</a><a>two</a></p>",
     "排除式 [!0] 去掉索引 0，保留 1,2。",
     "a[!0]@text（排除索引，legado 方括号写法）"),

    ("css-020", "a@text||b@text",
     "<div><b>只有b</b></div>",
     "|| 回退：a 无命中则用 b。",
     "a@text||b@text（ruleSearch.name 常见回退）"),

    ("css-021", "a@text&&b@text",
     "<div><a>A</a><b>B</b></div>",
     "&& 合并两条规则结果。",
     "a@text&&b@text（信息合并）"),

    ("css-022", "p@ownText",
     "<p>直接文本<em>强调</em>更多</p>",
     "ownText 只取元素自身直接文本节点，不含子元素文本。",
     "class.book_other@ownText（真实书源）"),

    ("css-023", "div@textNodes",
     "<div>甲<em>乙</em>丙</div>",
     "textNodes 取文本节点（忽略子元素标签自身）。",
     "span.0@textNodes（真实书源）"),

    ("css-024", "div@html",
     "<div><span>内容</span></div>",
     "@html 取元素 outerHTML。",
     "id.jianjie-popup.0@class.content.0@tag.p.0@html（真实书源）"),

    ("css-025", "div@all",
     "<div><span>一</span><span>二</span></div>",
     "@all 取所有命中元素的 outerHTML 拼接。",
     "#TextContent@all（真实书源）"),

    ("css-026", "a@data-url",
     "<div><a data-url=\"https://x.co/1\">链接</a></div>",
     "自定义属性 @data-url 提取。",
     "a@data-xxx（真实书源自定义属性）"),

    ("css-027", "ul:has(>a)@text",
     "<ul><li><a>有链接</a></li></ul><ul><li>无链接</li></ul>",
     ":has(>a) 选择含直接子代 a 的 ul。",
     "*:has(>*:has(>a))（真实书源 toc 规则）"),

    ("css-028", "p:matches(第|章)@text",
     "<div><p>第1章 开端</p><p>无关段落</p></div>",
     ":matches 正则匹配元素文本。",
     "*:matches(第|章|Chapter)（真实书源）"),

    ("css-029", "div:not(:has(p))@text",
     "<div>无p</div><div><p>有p</p></div>",
     ":not(:has(p)) 排除含 p 的元素。",
     "*:not(:has(div))（真实书源）"),

    ("css-030", "ul li@text",
     "<ul><li>一</li><li>二</li></ul>",
     "后代选择器取全部 li 文本。",
     "ul.list_ul@li（真实书源 bookList）"),

    ("css-031", "div.box a.2@href",
     "<div class=\"box\"><a href=\"1\"></a><a href=\"2\"></a><a href=\"3\"></a></div>",
     "复合 class + 索引 2 取第三个 <a> 的 href。",
     ".box-artic div.2:1@text（真实书源索引）"),

    ("css-032", "p:contains(状态)@text",
     "<div><p>状态：连载</p><p>分类：玄幻</p></div>",
     ":contains 命中『状态』段落取文本。",
     "p:contains(状态)@text（真实书源）"),

    ("css-033", "class.info@text",
     "<div class=\"info\">简介内容</div>",
     "class 前缀取类元素文本。",
     "class.info@text（真实书源）"),

    ("css-034", "a[href]@href",
     "<div><a href=\"/a\">A</a><a>B</a></div>",
     "属性存在选择器 a[href] 取带 href 的链接。",
     "a[href]（属性选择器）"),

    ("css-035", ".list .item@text",
     "<div class=\"list\"><span class=\"item\">甲</span><span class=\"item\">乙</span></div>",
     "后代复合 class 选择器。",
     ".list .item（真实书源）"),

    ("css-036", "li:contains(免费)@text",
     "<ul><li>免费章节</li><li>VIP章节</li></ul>",
     ":contains 命中『免费』项。",
     "li:contains(免费)（真实书源章节过滤）"),

    ("css-037", "h2@text",
     "<section><h2>卷一 风起</h2></section>",
     "标签选择器取标题文本。",
     "h2@text（卷名规则）"),
]

# ---------------------------------------------------------------------------
# JSON fixtures
# ---------------------------------------------------------------------------
JSON = [
    ("json-001", "$.name",
     '{"name":"诡秘之主","author":"爱潜水的乌贼"}',
     "取根级字段 name。",
     "$.name（ruleBookInfo.name）"),

    ("json-002", "$.data.chapters",
     '{"data":{"chapters":["第1章","第2章","第3章"]}}',
     "嵌套路径取数组，换行连接。",
     "$.data.chapters（ruleToc 列表）"),

    ("json-003", "$.chapters[*]",
     '{"chapters":["ch1","ch2","ch3"]}',
     "通配 [*] 展开数组元素。",
     "$.chapters（既有样例）"),

    ("json-004", "$.data.list[*].title",
     '{"data":{"list":[{"title":"甲"},{"title":"乙"}]}}',
     "数组内取每个对象的 title 字段。",
     "$.results.list[*].title（真实书源）"),

    ("json-005", "$..title",
     '{"book":{"title":"主标题"},"data":{"title":"副标题"}}',
     "递归下降 $.. 收集所有 title。",
     "$..title（递归路径）"),

    ("json-006", "$.data.chapters[0]",
     '{"data":{"chapters":["第1章","第2章"]}}',
     "数组下标 0 取首个元素。",
     "$.data.chapters[0]（首章）"),

    ("json-007", "$.data.chapters[1:3]",
     '{"data":{"chapters":["c0","c1","c2","c3"]}}',
     "切片 [1:3) 取索引 1、2。",
     "$.data.chapters[1:3]（切片）"),

    ("json-008", "$.data.chapters[*].name",
     '{"data":{"chapters":[{"name":"a"},{"name":"b"}]}}',
     "[*].name 取每个元素 name。",
     "$.data.chapters[*].name（真实书源）"),

    ("json-009", "$.results.list[*]",
     '{"results":{"list":["x","y"]}}',
     "嵌套 results.list 数组展开。",
     "$.results.list[*]（真实书源）"),

    ("json-010", "$..list[*].list[*]",
     '{"list":[{"list":["a","b"]},{"list":["c"]}]}',
     "递归 + 多重数组展开。",
     "$..list[*].list[*]（真实书源嵌套）"),

    ("json-011", "$.data||$.data.data[*]",
     '{"data":{"data":["d1","d2"]}}',
     "|| 回退：$.data 命中则用之。",
     "$.data||$.data.data[*]||$.data[*]（真实书源回退）"),

    ("json-012", "$.a[*]%%$.b[*]",
     '{"a":["a1","a2"],"b":["b1","b2"]}',
     "%% 交错：a1 b1 a2 b2。",
     "$.a[*]%%$.b[*]（交错拼接，真实书源）"),

    ("json-013", "$.category&&$..score",
     '{"category":"玄幻","data":{"score":9.2}}',
     "&& 合并 category 与递归 score。",
     "$.category&&$..score（真实书源组合）"),

    ("json-014", "$[?(@.type=='book')].name",
     '{"items":[{"type":"book","name":"书A"},{"type":"movie","name":"片B"}]}',
     "过滤表达式保留 type==book 的 name。",
     "$[?(@.type=='book')]（JsonPath 过滤）"),

    ("json-015", "$.data.chapters[?(@.vip==true)]",
     '{"data":{"chapters":[{"vip":true,"t":"v1"},{"vip":false,"t":"v2"}]}}',
     "过滤 vip==true 的章节。",
     "$.chapters[?(@.vip)]（真实书源 VIP 过滤）"),

    ("json-016", "$.books[?(@.price < 10)]",
     '{"books":[{"price":8,"n":"a"},{"price":20,"n":"b"}]}',
     "数值比较过滤。",
     "$.books[?(@.price<10)]（JsonPath 过滤）"),

    ("json-017", "$..authors[*]",
     '{"a":{"authors":["张三","李四"]},"b":{"authors":["王五"]}}',
     "递归收集所有 authors 数组。",
     "$..authors[*]（递归数组）"),

    ("json-018", "$.store.book[*].price",
     '{"store":{"book":[{"price":10},{"price":20}]}}',
     "嵌套数组字段。",
     "$.store.book[*].price（标准 JsonPath 示例）"),

    ("json-019", "$.data.images[*]",
     '{"data":{"images":["i1.jpg","i2.jpg"]}}',
     "图片数组展开。",
     "$.model.images[*]（真实书源图集）"),

    ("json-020", "$.list[0:2]",
     '{"list":["e0","e1","e2","e3"]}',
     "切片 [0:2) 取前两个。",
     "$.list[0:2]（切片）"),

    ("json-021", "$.menu[*].items[*].title",
     '{"menu":[{"items":[{"title":"甲"}]},{"items":[{"title":"乙"}]}]}',
     "深嵌套数组字段提取。",
     "$.menu[*].items[*].title（真实书源）"),

    ("json-022", "$.a.b.c.d",
     '{"a":{"b":{"c":{"d":"深值"}}}}',
     "深层路径取值。",
     "$.a.b.c.d（深层路径）"),

    ("json-023", "$['book name']",
     '{"book name":"带空格键","other":1}',
     "带空格键需用 [''] 语法。",
     "$['key with space']（特殊键）"),

    ("json-024", "$.numbers[-1]",
     '{"numbers":[1,2,3,4]}',
     "负索引取末位元素。",
     "$.numbers[-1]（负索引）"),

    ("json-025", "$.users[*].name",
     '{"users":[{"name":"甲"},{"name":"乙"}]}',
     "用户数组取 name。",
     "$.users[*].name（真实书源）"),

    ("json-026", "$.data.content",
     '{"data":{"content":"正文内容"}}',
     "取正文内容字段。",
     "$.data.content（ruleContent）"),

    ("json-027", "$.results[?(@.score > 90)]",
     '{"results":[{"score":95,"n":"a"},{"score":80,"n":"b"}]}',
     "大于比较过滤。",
     "$.results[?(@.score>90)]（过滤）"),

    ("json-028", "$.a[*]%%$.b[*]%%$.c[*]",
     '{"a":["a1"],"b":["b1"],"c":["c1"]}',
     "三路交错拼接。",
     "$.a[*]%%$.b[*]%%$.c[*]（多路交错）"),

    ("json-029", "$.x.y[*].z",
     '{"x":{"y":[{"z":"v1"},{"z":"v2"}]}}',
     "数组内取 z 字段。",
     "$.x.y[*].z（真实书源）"),

    ("json-030", "$..*",
     '{"a":1,"b":{"c":2}}',
     "递归取所有叶子值。",
     "$..*（递归全部）"),

    ("json-031", "$.data.list[?(@.status=='active')]",
     '{"data":{"list":[{"status":"active","v":"x"},{"status":"dead","v":"y"}]}}',
     "状态过滤。",
     "$.data.list[?(@.status=='active')]（真实书源）"),

    ("json-032", "$.items[?(@.qty >= 2)]",
     '{"items":[{"qty":3,"n":"a"},{"qty":1,"n":"b"}]}',
     "大于等于过滤。",
     "$.items[?(@.qty>=2)]（过滤）"),

    ("json-033", "$.books[*].author",
     '{"books":[{"author":"甲"},{"author":"乙"}]}',
     "数组对象字段提取。",
     "$.books[*].author（真实书源）"),

    ("json-034", "$.data.chapters.length()",
     '{"data":{"chapters":["c1","c2","c3"]}}',
     "length() 函数取数组长度。",
     "$.x.length()（JsonPath 函数）"),
]

# ---------------------------------------------------------------------------
# REGEX fixtures  (regex-multiline.json + stage1-regex.json combined pool)
# ---------------------------------------------------------------------------
REGEX = [
    ("regex-001", r"Chapter (\d+): (.*)",
     "Chapter 1: The Beginning\nChapter 2: The Middle",
     "分组提取：全匹配 + 章节号 + 标题（无 dotAll，仅首行）。",
     "Chapter (\\d+): (.*)（既有 stage1 样例）"),

    ("regex-002", r"line (.*)",
     "line one\nline two\nline three",
     "无标志：. 不匹配换行，仅命中首行 line one（两引擎应一致）。",
     "line (.*)（既有 multiline 样例）"),

    ("regex-003", r"(https?://\S+)",
     "见 https://example.com/book/1 与 http://x.co/2 结尾",
     "提取 URL（首个匹配全串 + 分组）。",
     "(https?://\\S+)（url 提取）"),

    ("regex-004", r"(\d{4})-(\d{2})-(\d{2})",
     "更新于 2024-09-13 发布",
     "日期分组：年/月/日。",
     "(\\d{4})-(\\d{2})-(\\d{2})（日期解析）"),

    ("regex-005", r"第(\d+)章",
     "最新 第1024章 大结局",
     "章节号分组。",
     "第(\\d+)章（章节号）"),

    ("regex-006", r"(\w+)@(\w+)\.(\w+)",
     "联系 mailto:user@example.com 即可",
     "邮箱三段分组。",
     "(\\w+)@(\\w+)\\.(\\w+)（邮箱）"),

    ("regex-007", r"(\d+)%%(\w+)",
     "id=42 name=alpha",
     "%% 链式：第一阶段取数字，拼接后第二阶段取单词。",
     "(\\d+)%%(\\w+)（链式提取）"),

    ("regex-008", r"(\w+)%%(\d+)",
     "a1b2c3",
     "%% 链式：首段单词，次段取其内首个数字。",
     "(\\w+)%%(\\d+)（链式提取）"),

    ("regex-009", r"[\s\S]*?\"content\":\s*\"([^\"]+)\"",
     '前缀 {"content": "正文第一段"} 后缀',
     "用 [\s\S] 跨行匹配（替代 dotAll）。",
     "[\s\S]*?\"x\":\"([^\"]+)\"（跨行提取）"),

    ("regex-010", r"([^|]+)\|([^|]+)\|([^|]+)",
     "甲|乙|丙",
     "竖线分隔三段分组。",
     "([^|]+)\\|([^|]+)\\|([^|]+)（管道分隔）"),

    ("regex-011", r"《([^》]+)》",
     "推荐《诡秘之主》与《亵渎》两本书",
     "书名号内文分组。",
     "《([^》]+)》（书名提取）"),

    ("regex-012", r"【(.+?)】(.+)",
     "【作者】爱潜水的乌贼",
     "方括号内分组 + 余下内容。",
     "【(.+?)】(.+)（标签提取）"),

    ("regex-013", r"^\s*([一-龥]+):\s*(.+)$",
     "作者: 猫腻",
     "多行键值：^ $ 仅整串首尾（无 multiline），仅首行。",
     "^\s*([\\u4e00-\\u9fa5]+):\\s*(.+)$（键值）"),

    ("regex-014", r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})",
     "服务器 192.168.1.1 已启动",
     "IP 地址分组。",
     "(\\d{1,3}\\.){3}\\d{1,3}（IP 提取）"),

    ("regex-015", r"var\s+(\w+)\s*=\s*(\d+)",
     "var count = 42",
     "变量声明分组：名 + 值。",
     "var\\s+(\\w+)\\s*=\\s*(\\d+)（变量解析）"),

    ("regex-016", r"<([a-zA-Z]+)>",
     "文本 <span> 内容 </span> 结束",
     "标签名分组。",
     "<([^>]+)>（标签提取）"),

    ("regex-017", r"(\d+)\s*px",
     "宽度 320px 高度 480px",
     "数值 + 单位分组（首个匹配）。",
     "(\\d+)\\s*px（像素值）"),

    ("regex-018", r"([A-Za-z]+)\d+",
     "版本 v2 alpha3 beta9",
     "字母 + 数字前缀分组。",
     "([A-Za-z]+)\\d+（版本片段）"),

    ("regex-019", r"第([零一二三四五六七八九十]+)章",
     "最新更新 第十章 风云起",
     "中文数字章节分组。",
     "第([零一二三四五六七八九十]+)章（中文章节）"),

    ("regex-020", r"(\$\{[^}]+\})",
     "模板 ${name} 与 ${title} 占位",
     "模板变量 ${...} 分组。",
     "(\\$\\{[^}]+\\})（模板变量）"),

    ("regex-021", r"a(\d+)b(\d+)c",
     "a12b34c 之后 a56b78c",
     "两段数字分组（首个匹配）。",
     "a(\\d+)b(\\d+)c（成对数字）"),

    ("regex-022", r"/\*([\s\S]*?)\*/",
     "代码 /* 注释\n跨行 */ 结束",
     "非贪婪块注释，[\s\S] 跨行。",
     "/\\*([\\s\\S]*?)\\*/（块注释）"),

    ("regex-023", r"(\w+):\s*(.+)",
     "title: 诡秘之主\nsub: 副标题",
     "无 multiline：. 不跨行，仅命中首行 title: 诡秘之主。",
     "(\\w+):\\s*(.+)（无 multiline 首行）"),

    ("regex-024", r"第(.+?)章",
     "第1卷第3章 开端",
     "非贪婪章节分组。",
     "第(.+?)章（非贪婪）"),

    ("regex-025", r"data-(id|name)=\"([^\"]+)\"",
     "节点 data-id=\"42\" data-name=\"x\" 属性",
     "属性名枚举 + 值分组。",
     "data-(id|name)=\"([^\"]+)\"（属性提取）"),

    ("regex-026", r"(\d+)\s*[×x]\s*(\d+)",
     "画布 1920 × 1080 分辨率",
     "乘号分隔两段数字分组。",
     "(\\d+)\\s*[×x]\\s*(\\d+)（尺寸）"),

    ("regex-027", r"([A-Z]{2,})\s+([0-9]+)",
     "编号 ISBN 9787 出版",
     "大写字母串 + 数字分组。",
     "([A-Z]{2,})\\s+([0-9]+)（编号）"),

    ("regex-028", r"(\w+)%%([a-z]+)",
     "num7 word=hello",
     "%% 链式：首段单词，次段取其内首个小写词。",
     "(\\w+)%%([a-z]+)（链式）"),

    ("regex-029", r"\((\d{3})\)\s*(\d{3}-\d{4})",
     "电话 (021) 123-4567 联系",
     "区号 + 号码分组。",
     "\\((\\d{3})\\)\\s*(\\d{3}-\\d{4})（电话）"),

    ("regex-030", r"([^,]+),([^,]+),([^,]+)",
     "北京,上海,广州",
     "逗号分隔三段分组。",
     "([^,]+),([^,]+),([^,]+)（逗号分隔）"),

    ("regex-031", r"src=\"([^\"]+)\"",
     "图片 <img src=\"https://x.co/a.jpg\"> 显示",
     "HTML 属性 src 值分组。",
     "src=\"([^\"]+)\"（src 提取）"),

    ("regex-032", r"【作话】\s*(.+)",
     "【作话】感谢投喂的小天使",
     "作话标记后内容分组。",
     "【作话】\\s*(.+)（作者有话）"),

    ("regex-033", r"(\d{2}:\d{2})",
     "更新时间 09:27 已发布",
     "时间 HH:MM 分组。",
     "(\\d{2}:\\d{2})（时间）"),

    ("regex-034", r"([一-龥]+)：(.+)",
     "作者：猫腻 字数：120万",
     "全角冒号 + 中文键值分组。",
     "([一-龥]+)：(.+)（全角冒号键值）"),

    ("regex-035", r"\"(\w+)\":\s*\"([^\"]*)\"",
     '{"title": "诡秘之主", "author": "乌贼"}',
     "JSON 风格键值分组（无 dotAll，首行）。",
     "\"(\\w+)\":\\s*\"([^\"]*)\"（json 字段）"),

    ("regex-036", r"卷(\d+)",
     "正文 卷12 风云变幻",
     "卷号分组。",
     "卷(\\d+)（卷号）"),

    ("regex-037", r"\$(\d+\.\d+)",
     "售价 $12.99 包月",
     "价格分组。",
     "\\$(\\d+\\.\\d+)（价格）"),

    ("regex-038", r"#(\w+)",
     "话题 #xuanhuan #xiuzhen 热门",
     "话题标签分组（首匹配 #xuanhuan）。",
     "#(\\w+)（标签）"),

    ("regex-039", r"(\d{3}-\d{4}-\d{4})",
     "手机 138-1234-5678 联系",
     "手机号分组。",
     "(\\d{3}-\\d{4}-\\d{4})（手机）"),

    ("regex-040", r"\[([^\]]+)\]",
     "标签 [玄幻][热血][连载] 列表",
     "方括号内分组。",
     "\\[([^\\]]+)\\]（方括号）"),

    ("regex-041", r"(\d+)年(\d+)月(\d+)日",
     "上架 2024年9月13日 发行",
     "中文日期三段分组。",
     "(\\d+)年(\\d+)月(\\d+)日（中文日期）"),

    ("regex-042", r"([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})",
     "反馈请发 user@example.com 或 admin@x.co",
     "完整邮箱分组（首匹配）。",
     "([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})（邮箱）"),

    ("regex-043", r"chapter-(\d+)",
     "链接 chapter-1024 下一章",
     "英文章节号分组。",
     "chapter-(\\d+)（英文章节）"),

    ("regex-044", r"(\d+)\.(\d+)\.(\d+)",
     "版本 v1.2.3 已发布",
     "版本号三段分组。",
     "(\\d+)\\.(\\d+)\\.(\\d+)（版本号）"),

    ("regex-045", r"url=([^\s&]+)",
     "跳转 url=https://x.co/a 完成",
     "查询参数值分组。",
     "url=([^\\s&]+)（参数）"),

    ("regex-046", r"(\d+)(px|em|rem)",
     "字号 16px 行距 1.5em",
     "数值 + CSS 单位分组。",
     "(\\d+)(px|em|rem)（单位）"),

    ("regex-047", r"^\s*-\s*(.+)",
     "- 第一项\n- 第二项",
     "列表项：无 multiline，仅首行命中。",
     "^\\s*-\\s*(.+)（列表项）"),

    ("regex-048", r"\b(\w{5,})\b",
     "characterization paragraph document",
     "长单词（≥5）分组（首匹配）。",
     "\\b(\\w{5,})\\b（长单词）"),

    ("regex-049", r"(\d{2}/\d{2}/\d{4})",
     "日期 13/09/2024 记录",
     "斜杠日期分组。",
     "(\\d{2}/\\d{2}/\\d{4})（斜杠日期）"),

    ("regex-050", r"(TODO|FIXME):(.+)",
     "TODO: 补充正文清洗逻辑",
     "标记 + 内容分组。",
     "(TODO|FIXME):(.+)（标记）"),

    ("regex-051", r"0x([0-9a-fA-F]+)",
     "颜色 0x1a2b3c 定义",
     "十六进制值分组。",
     "0x([0-9a-fA-F]+)（hex）"),

    ("regex-052", r"(\d+)\s*-\s*(\d+)",
     "页数 12 - 34 区间",
     "范围两段分组。",
     "(\\d+)\\s*-\\s*(\\d+)（范围）"),

    ("regex-053", r"%([a-zA-Z]+)%",
     "模板 %name% 与 %title% 占位",
     "百分号占位符分组。",
     "%([a-zA-Z]+)%（占位符）"),

    ("regex-054", r"(\d+)%%(\d+)",
     "a7b9 链式",
     "%% 链式两组数字。",
     "(\\d+)%%(\\d+)（链式数字）"),

    ("regex-055", r"<title>([^<]+)</title>",
     "<title>诡秘之主</title> 结束",
     "title 标签内文分组。",
     "<title>([^<]+)</title>（title）"),

    ("regex-056", r"(\d{1,2}):(\d{1,2}):(\d{1,2})",
     "时长 01:23:45 播放",
     "时分秒三段分组。",
     "(\\d{1,2}):(\\d{1,2}):(\\d{1,2})（时分秒）"),

    ("regex-057", r"【(.*?)】",
     "【类别】玄幻【进度】连载",
     "方括号内容分组（首匹配）。",
     "【(.*?)】（方括号）"),

    ("regex-058", r"第\s*([0-9]+)\s*卷",
     "第 3 卷 风起云涌",
     "带空白卷号分组。",
     "第\\s*([0-9]+)\\s*卷（卷号）"),

    ("regex-059", r"([a-z]+)_([a-z]+)",
     "snake_case_name 变量",
     "下划线命名两段分组。",
     "([a-z]+)_([a-z]+)（下划线）"),

    ("regex-060", r"(\d{4})年",
     "始于 2024年 连载",
     "年份分组。",
     "(\\d{4})年（年份）"),

    ("regex-061", r"\"content\":\"([^\"]+)\"",
     '结果 "content":"正文第一段" 显示',
     "JSON content 字段分组。",
     "\"content\":\"([^\"]+)\"（content）"),

    ("regex-062", r"(\+?\d{1,3}-?\d{3,})",
     "电话 +86-1380000 联系",
     "带区号电话分组。",
     "(\\+?\\d{1,3}-?\\d{3,})（电话）"),

    ("regex-063", r"(https?://[^\s]+)",
     "访问 https://example.com/path?q=1 获取",
     "完整 URL 分组（首匹配）。",
     "(https?://[^\\s]+)（url）"),
]


def dump(name, rows, kind):
    out = []
    for (fid, rule, content, expect, src) in rows:
        out.append({
            "id": fid,
            "kind": kind,
            "rule": rule,
            "content": content,
            "expect": expect,
            "src": src,
        })
    path = os.path.join(FIX, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"{name}: {len(out)} entries")


if __name__ == "__main__":
    dump("css.json", CSS, "css")
    dump("json.json", JSON, "json")
    # 既有两份 regex 样例文件分别存放，内容合并自真实书源规则
    dump("stage1-regex.json", REGEX[:30], "regex")
    dump("regex-multiline.json", REGEX[30:], "regex")
    # 校验数量
    for fn in ["css.json", "json.json", "stage1-regex.json", "regex-multiline.json"]:
        data = json.load(open(os.path.join(FIX, fn), encoding="utf-8"))
        print(f"  {fn}: {len(data)}")
