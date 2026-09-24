# Oracle Fixture 常态化 — 双侧判题归因报告

本目录下的 fixture 从真实书源规则（`chloris/assets/sources/*.json` 的
`ruleSearch` / `ruleBookInfo` / `ruleToc` / `ruleContent`）取样，并被
`tool/legado_oracle_audit.dart` 加载，做一次**真·双侧**判题：

* **Oracle 侧**：`tool/legado_oracle` 这个独立 Gradle/Kotlin 进程桥，直接运行
  真实 Legado-E 后端 `AnalyzeByJSoup` / `AnalyzeByRegex` / `AnalyzeByJSonPath`
  （符号链接到 `reference/legado-E-main/...`，非副本，不漂移）。
* **Chloris 侧**：`lib/src/analyze/*` 的 Dart 移植实现。
* 比较字段为 `value`（与 `EquivalenceFixture.run()` 可比子集一致）。

> 重要：本报告的 16 条分歧**全部未改动 `lib/`** 来强行通过，仅做归因记录。
> 判题命令见文末「验收」。

---

## 1. 语料规模与覆盖

| 文件 | 条数 | 覆盖后端 | 边界覆盖 |
|---|---|---|---|
| `css.json` | 37 | css | `:contains` / `@attr`（含 `@data-url`、`@src`）/ 索引区间（`.0:2`、`[0:2]`、`-1`、`!.` 排除）/ `||` `&&` / `@ownText` `@textNodes` `@html` `@all` / `:has` `:matches` `:not(:has)` |
| `json.json` | 34 | json | 递归 `$..x` / 切片 `[1:3]` / 过滤 `[?(@.x op v)]` / 交错 `%%` / 负索引 / 深层路径 |
| `stage1-regex.json` | 30 | regex | 分组 / `%%` 链式 / 中文章节 / 邮箱 / URL / 日期 |
| `regex-multiline.json` | 33 | regex | 多行（无 `multiline` 标志）/ `[\s\S]` 跨行 / 竖线·逗号·方括号分组 / 反引用 |

> `xpath.json`（38 条）已由其它流程维护，本次**未改动**。

每条 fixture 形如：
```json
{ "id": "css-001", "kind": "css", "rule": "a@text",
  "content": "<div>...</div>", "expect": "提取全部 <a> 文本", "src": "真实书源规则出处" }
```

---

## 2. 判题结果（双侧）

```
oracle=legado-process  bilateral=true
totalCases=134  passedCases=118  failedCases=16  passRate=0.88
```

其中 **118 条两侧输出一致**（含全部常规选择器、`%%` 正则链式、JsonPath 数组/切片/过滤
的*语义*结果、以及已对齐的正则标志行为），**16 条存在输出分歧**。

### 2.1 已对齐、不再分歧的关键项（曾被旧注释误报）

* **正则多行/dotAll**：旧 `audit.dart` 注释称 `line (.*)` 两侧会分歧，但
  `lib/src/analyze/analyze_by_regex.dart:54` 的 `_compile` 已显式对齐
  `AnalyzeByRegex.kt:11` 的 `Pattern.compile(regs[index])`（**无任何标志**），
  `.` 不跨行、`^/$` 仅首尾。故 `regex-multiline`、`regex-001` 等多行用例现在**两侧一致**。
  相关说明见该文件 `:54-58` 注释（`§7 行 276`）。

---

## 3. 分歧归因（16 条）

> 分类：
> * **extension** — 属于 Chloris 侧扩展能力（或 oracle 桥接不完整，真实 Legado
>   同样支持，只是当前 `getString` 路径未暴露）。
> * **divergence** — 真实分歧，附 Legado 侧行为证据（文件:行号）。

### 3.1 extension（Chloris 扩展 / oracle 桥接局限）

| id | rule | 说明 |
|---|---|---|
| `json-012` | `$.a[*]%%$.b[*]` | Chloris 交错拼接；oracle 经 `getString` 路径未切分 `%%`。 |
| `json-028` | `$.a[*]%%$.b[*]%%$.c[*]` | 同上，三路交错。 |

证据：`tool/legado_oracle` 桥（`Main.kt`）仅调用 `AnalyzeByJSonPath(content).getString(rule)`；
而 Legado `AnalyzeByJSonPath.kt:35` 的 `getString` 只 `splitRule("&&","||")`，**不切分 `%%`**，
于是 `$.a[*]%%$.b[*]` 被当成单条非法 JsonPath → 抛异常被吞 → 返回 `""`。
但 **真实** Legado 在完整管线里会把 `%%` json 规则导向 `getStringList`（`:75`）/
`getList`（`:133`），这两处**明确 `splitRule("&&","||","%%")`**，是支持交错的。
因此这并非 Chloris 独有扩展，而是**判题桥只暴露了 `getString`、未暴露
`getStringList`/`getList` 的不完整所致**。Chloris 侧 `analyze_by_jsonpath.dart:78-79`
（`getString`→`getStringList`）和 `:104-113`（`%%` 交错分支）已正确实现。
→ 标记为 extension（oracle 局限型），非真实功能分歧。

### 3.2 divergence（真实分歧，附 Legado 证据）

#### CSS 后端

**`css-007` `:contains(作者)@text`**
* Chloris：`作者：爱潜水的乌贼简介：一段文字`（单串、无分隔符、无空白）
* Legado ：`作者：爱潜水的乌贼 简介：一段文字` ×5（以 `\n` 连接）
* 三重根因：
  1. **连接符**：Chloris `getString`→`collapseJoinedStrings`（`network_utils.dart:245`）
     多匹配用 `""` 拼接；Legado `AnalyzeByJSoup.kt:59` `list.joinToString("\n")`。
  2. **文本空白**：Chloris `_text`（`analyze_by_css.dart:326-348`）直接拼接文本节点、
     不补空白；Legado `Element.text()`（`AnalyzeByJSoup.kt:233-237`）在块级子元素间插入空格。
  3. **`:contains` 命中集**：Legado 由 jsoup 原生 `:contains` 命中祖先+自身多个节点
     （`AnalyzeByJSoup.kt:144` `temp.select(ruleStrX)`）；Chloris 自定义谓词
     （`analyze_by_css.dart:386-492`）作用在最终候选上，命中集不同。

**`css-008` `dd:contains(最新章节：) > a@text`**
* Chloris：`''`（空）　Legado：`第1章 开端`
* 根因：Chloris 把 `:contains(...)` 谓词**作用在最后一段选择器（`> a`）的元素上**，
  而 `<a>` 文本不含「最新章节：」被过滤空（`analyze_by_css.dart:474-491` 对候选 `<a>` 做
  `element.text.contains(pattern)`）；Legado 由 jsoup 在组合选择器 `dd:contains(...) > a`
  内把 `:contains` 正确绑定到 `dd`（`AnalyzeByJSoup.kt:144`）。

**`css-009` `dt:contains(作者)+dd a@text`**
* Chloris：`''`　Legado：`猫腻`
* 同上 `:contains` 作用域问题，叠加相邻兄弟 `+` 组合子，Chloris 谓词落在末端 `<a>` 上。

**`css-024` `div@html` / `css-025` `div@all`**
* Chloris：`<div><span>内容</span></div>`（保留原始序列化）
* Legado ：`<div>\n <span>内容</span>\n</div>`（jsoup 重新序列化、插入换行缩进）
* 根因：outerHtml 序列化差异。Chloris `analyze_by_css.dart:260-312` 用
  `element.outerHtml` 原样输出；Legado `AnalyzeByJSoup.kt:263-266`
  `elements.outerHtml()` 经 jsoup 美化输出。属序列化格式分歧。

**`css-027` `ul:has(>a)@text`**
* Chloris：`''`　Legado：`None`（无结果，因内容不符，但语法被支持）
* 根因：**能力缺口**。Chloris `_CssPredicates.parse`（`analyze_by_css.dart:401`）
  仅识别 `:contains/containsOwn/matches/matchesOwn` 伪类，**不识别 `:has`**；
  整条选择器被原样交给 `querySelectorAll`，html 包不支持 `:has` → 抛异常被吞 → `[]`。
  Legado 由 jsoup 原生支持 `:has`（`AnalyzeByJSoup.kt:144`）。

**`css-029` `div:not(:has(p))@text`**
* Chloris：`''`　Legado：`无p`
* 同上 `:has` 缺口（`:not(:has(p))` 同样依赖 `:has`）。

#### JSON 后端

**`json-011` `$.data||$.data.data[*]`**
* Chloris：`{"data":["d1","d2"]}`（JSON 编码）
* Legado ：`{data=["d1","d2"]}`（Jayway toString）
* 两引擎均正确回退命中 `$.data`，仅**对象 toString 格式**不同：
  Chloris `analyze_by_jsonpath.dart:176` `jsonEncode(e)`；
  Legado `AnalyzeByJSonPath.kt:46-50` `ob.toString()`（Jayway `DefaultJson*` 格式）。

**`json-015/016/027/031/032`（过滤 `[?(@.x op v)]`）**
* 例 `json-015` `$.data.chapters[?(@.vip==true)]`：
  Chloris `{"vip":true,"t":"v1"}`　Legado `{vip=true, t=v1}`
* 过滤**语义两侧一致**（都筛出匹配元素），仅 toString 格式分歧（同上
  `analyze_by_jsonpath.dart:176` vs `AnalyzeByJSonPath.kt:46-50`）。
  覆盖 `==`/`<`/`>`/`>=`/`==` 各类比较，结论一致。

**`json-030` `$..*`**
* Chloris：`''`（空）　Legado：`1\n{c=2}\n2`
* 根因：**能力缺口**。Chloris 的 `$..` 递归（`analyze_by_jsonpath.dart:193-204`）
  仅支持**具名键**递归（如 `$..title`，见 `json-005` 通过），`_recursive`
  （`:724-735`）只在 `k.toString() == key` 时收集，**不识别通配 `*`**；
  故 `$..*`（递归取全部叶子）返回空。Legado 由 Jayway `JsonPath`
  （`AnalyzeByJSonPath.kt:18` `JsonPath.parse`）原生支持 `$..*`。

---

## 4. 修复过的 fixture 内容（非分歧，仅确保用例有效）

以下条目首轮因「规则在任一侧都不命中」而呈 `chloris=[] | legado=null`（空 vs null 的
假分歧），已修正内容使其两侧均可命中、转化为有效用例（现均已 PASS）：

* `regex-008`：链式 `(\w+)%%(\d+)` + 内容 `a1b2c3`（首段单词，次段取首个数字）。
* `regex-023`：去掉 `^$` 锚点改 `(\w+):\s*(.+)`，演示无 `multiline` 仅命中首行。
* `regex-028`：`(\w+)%%([a-z]+)` + `num7 word=hello`（首段单词含后续小写词）。
* `regex-034`：`([一-龥]+)：(.+)` 覆盖全角冒号 + 中文键值。
* `regex-038`：内容改 ASCII `#xuanhuan`，使 `\w` 可命中。
* `css-019`：`a.!.0@text`（旧 `.` 排除写法 Legado 不识别）改为方括号排除
  `a[!0]@text`，两侧均返回 `one\ntwo`。

---

## 5. 验收

* 双侧判题：
  ```bash
  cd packages/chloris_engine/tool/legado_oracle && bash run_oracle.sh   # 单条直判
  cd packages/chloris_engine && \
    ../../reference/flutter-sdk/flutter/bin/dart run tool/legado_oracle_audit.dart
  ```
* 单测（**未改动 `lib/`**）应仍为全绿：
  ```bash
  ../../reference/flutter-sdk/flutter/bin/dart test
  ```
* 报告产物：`artifacts/verification/20260912-rule-engine-parity/equivalence-bilateral.json`
  （`oracle=legado-process, bilateral=true, 134 cases, 118 pass, 16 fail`）。

---

## 6. 第二轮收口（2026-09-13）

四类真实分歧已修复（详见 `test/divergence_fix_test.dart`，10 项回归）：

| 项 | 修复 |
|---|---|
| css-008/009 谓词作用域 | `_queryCss` 重写为**逐段求值**（`evalSelector`/`evalSegment`）：选择器按组合子（空格/`>`/`+`/`~`）切段，谓词绑定所在段，对齐 `AnalyzeByJSoup.kt:144` |
| css-027/029 `:has` | `_CssPredicates` 新增 `has` 谓词（`:has(>a)` 直接子代 / `:has(a)` 后代），支持 `:not(:has(...))`，对齐 jsoup StructuralEvaluator |
| css-007 连接符+空白 | CSS/XPath `getString` 改为纯 `\n` 连接（对齐 `AnalyzeByJSoup.kt:59`，废弃 Chloris 旧的包含式折叠——简介去重职责归 `sanitizeBookIntro`）；`_text` 块级子元素间补空格（对齐 jsoup `Element.text()`） |
| json-030 `$..*` | `_recursive` 支持通配 `*`（容器+叶子全收集，对齐 Jayway） |

**双侧一致率：118/134 (0.880) → 121/134 (0.903)**。

剩余 13 条 FAIL 归因（均为不做项）：
- `css-024/025`：outerHtml 序列化空白格式（jsoup 美化输出 vs 原样保留）——语义一致。
- `json-011/015/016/027`：Jayway `toString` 格式（`{a=b}` vs `{"a":"b"}`）——语义一致。
- `json-012/028`：`%%` 交错——oracle 桥只暴露 `getString` 的局限（§3.1），真实 legado 管线支持。
- `json-030`：Chloris `{"c":2}`（jsonEncode）vs legado `{c=2}`（toString）——语义已一致，仅格式。
- `css-027`：legado `null` vs Chloris `''` 的判题归一问题——能力已一致。
- `css-007`：祖先命中集边界（jsoup select 从文档根起算，含 html/body 自身；Chloris 从 documentElement 后代起算）——3 行 vs 5 行，真实书源不用裸 `:contains` 提正文，影响可忽略。
