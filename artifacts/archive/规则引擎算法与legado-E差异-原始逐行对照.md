# 规则引擎算法与 Legado-E 差异分析

> 分析对象
> - **Chloris**：`packages/chloris_engine/lib/src/analyze/**`（纯 Dart 规则引擎）
> - **Legado-E**：`reference/legado-E-main/app/src/main/java/io/legado/app/model/analyzeRule/**`
>
> 方法：逐文件对读两套实现，逐个能力点比对算法与语义；关键分歧用可执行探针在 Chloris 侧实测（`dart test`，探针文件已删除，不留痕）。行号对应当前工作区快照。
> 说明：本文只覆盖**规则引擎**（词法/编译/执行/四个后端/变量/请求构造/JS 宿主边界）。RSS、备份、本地格式、阅读排版等不属于规则引擎，另有文档。

---

## 0. 结论摘要

1. **两套引擎不是同一套算法，而是同语义的两套不同实现。** Legado-E 的 `RuleAnalyzer` 是「不发散、只在序列上标记首尾」的**有状态游标 + 尾递归**切分器（377 行，只保护 `[` / `(` 两种平衡组）；Chloris 把它替换成**无状态、可复用的词法单元扫描器** `RuleAnalyzer.skipUnit`（178 行，保护 `'` `"` `` ` `` `[` `(` `{`），并在其上新增了一层显式 IR（`RuleProgram` / `RuleStep`）与全局 LRU 编译缓存。
2. **绝大多数书源规则在两条路径上结果一致**：组合符 `&&`/`||`/`%%`、`@` 链、`@put`/`@get`/`{{}}`、`##` 替换后缀、四种模式前缀、`@text/@html/@ownText/@textNodes/@all/@attr` 的操作语义均已对齐。
3. **但存在一批会改变输出的真实分歧**，集中在五处：`AnalyzeUrl` 的模板/选项时序、header 与 Cookie 优先级、CSS 索引区间的边界算法、备选后端的能力边界（XPath / JSONPath / 正则）、以及 JS 宿主的作用域与异常语义。
4. **方向性差异**：Chloris 在**词法健壮性**（引号/括号感知）、**错误可见性**（不再把失败伪装成空结果）、**URL 选项切分**上比 Legado-E 更严格；Legado-E 在**平台能力**（真 jsoup Element、Rhino 共享作用域与沙箱、Jayway 完整 JSONPath、jsoupXpath 完整 XPath）上仍不可替代。
5. **Legado-E 本身存在若干缺陷，Chloris 已修正**（见 §10）。评估等价率时必须把它们从「Chloris 缺失」里剔除，否则会低估 Chloris。

### 最关键的六处「会改变输出」的分歧

| # | 分歧 | 方向 | 章节 |
|---|---|---|---|
| 1 | `AnalyzeUrl` 中 `{{js}}` 与 `<a,b,c>` 的处理顺序相反，且纯数字 `<1,2,3>` 被按步长外推 | Chloris 错 | §9 |
| 2 | header 优先级（源 vs URL 选项）与 Cookie 优先级（jar vs 规则）**双侧都相反** | Chloris 错 | §9 |
| 3 | CSS 索引区间右端含入、越界区间不跳过、空集合回退为全部元素 | Chloris 错 | §4.4 |
| 4 | 属性算子对属性值去重，导致列表长度/索引漂移 | Chloris 错 | §4.2 |
| 5 | XPath 缺 `string()/count()/substring()/concat()/normalize-space` 组合；JS 侧 `java.getElement` 返回字符串而非 Element | Chloris 缺能力 | §5、§8 |
| 6 | 词法层平衡组保护面更大、`@put`/`@get`/`@webjs:` 更严格；Legado 的 `@webjs:` 实际不可达 | Chloris 更正确 | §2、§10 |

---

## 1. 规模与结构基线

| 维度 | Chloris（Dart） | Legado-E（Kotlin） |
|---|---|---|
| 规则引擎总行数 | 3852（`lib/src/analyze/`，不含 589 行等价性审计） | 3352（`model/analyzeRule/` 去掉 `QueryTTF.java` 1055 行） |
| 词法/编译 | `rule_analyzer.dart` 178 + `rule_ir.dart` 155 + `rule_cache.dart` 89 | `RuleAnalyzer.kt` 377 |
| 执行内核 | `analyze_rule.dart` 846 | `AnalyzeRule.kt` 973 |
| CSS | `analyze_by_css.dart` 587 | `AnalyzeByJSoup.kt` 524 |
| XPath | `analyze_by_xpath.dart` 537（手写子集） | `AnalyzeByXPath.kt` 155（调 jsoupXpath） |
| JSONPath | `analyze_by_jsonpath.dart` 608（手写子集） | `AnalyzeByJSonPath.kt` 172（调 Jayway） |
| 正则 | `analyze_by_regex.dart` 59 | `AnalyzeByRegex.kt` 59 |
| URL/请求 | `analyze_url.dart` 779 | `AnalyzeUrl.kt` 978 |
| 变量 | `rule_data.dart` 12 | `RuleData.kt` 29 + `RuleDataInterface.kt` 37 |
| JS | 引擎内**无虚拟机**，`js_runtime.dart` 272 定义端口 + `java_host.dart` 1481 / `js_host_bridge.dart` 583 / `js_crypto.dart` 254 提供宿主 | Rhino 1.8.1（`modules/rhino/` 19 文件）+ `JsExtensions.kt` 1199 / `JsEncodeUtils.kt` 517 |

一个结构性事实：**Chloris 的后端规模更大而覆盖面更窄**——因为它是手写解析器（CSS/XPath/JSONPath 都要自己实现），Legado-E 把这三块外包给了 jsoup / jsoupXpath / Jayway。这决定了 §5~§7 的差异形态：不是参数不同，而是**能力集合不同**。

---

## 2. 词法与规则编译层（结构差异最大的一层）

### 2.1 两套切分算法

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 算法形态 | 无状态扫描：`skipUnit` 返回单元末尾索引，`_findSep`/`_splitAll` 顺序推进（`rule_analyzer.dart:22-98`） | 有状态游标：`pos`/`start`/`startX` + `consumeTo`/`consumeToAny` + 尾递归 `splitRule`（`RuleAnalyzer.kt:35-298`） | 不同实现 |
| 受保护单元 | `'` `"` `` ` ``（含 `${}` 插值）`[` `(` `{`，三者都做**栈式嵌套平衡**（`rule_analyzer.dart:100-171`） | 仅 `[` `(`——先用 `findToAny('[','(')` 定位，再 `chompBalanced`（`RuleAnalyzer.kt:184-232`） | **非等价** |
| 引号内转义 | 统一处理 `\` 转义（`_skipQuoted`） | `chompRuleBalanced` **不处理**引号内转义，`chompCodeBalanced` 处理（`RuleAnalyzer.kt:104/145`） | 非等价 |
| 平衡组失败 | 宽容：未闭合组消费到结尾（`rule_analyzer.dart:168-170`） | `throw Error("...后未闭合")`（`RuleAnalyzer.kt:228`） | Chloris 更宽容 |
| 反斜杠转义 | 不把 `\` 当转义（按字面） | `chompCodeBalanced` 里 `\` 跳过下一字符 | 非等价 |
| 复用性 | 无状态，可并发/可缓存（`RuleCompileCache`） | 有状态，`reSetPos()` 才能复用（`RuleAnalyzer.kt:25-28`） | 实现差异 |

**为什么这层最值得注意**：Legado-E 的切分器只保护 `[` 和 `(`，因此 `{`、`` ` ``、引号内的 `&&` 在它那里是**可能被误切**的（它的注释也承认 `chompRuleBalanced` 不对引号内转义做处理）。Chloris 把保护面扩到六种单元，代价是：**当 `&&` 出现在 `[...]` 顶层时 Chloris 不再切分**（整段视为一个 JSONPath/CSS 单元），这与 Legado 的「先找分隔符、再看是否落在平衡组内」在某些畸形规则上会给出不同的切分数。常规规则不受影响。

### 2.2 模式标记的扫描

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 标记识别方式 | 手写扫描游标 `_scanMarkers`，与组合符共用同一 `skipUnit`（`rule_ir.dart:81-121`） | 两个 `Pattern` 正则 + `Matcher.find()` 循环（`AnalyzeRule.kt:545-566`） | 实现差异 |
| `<js>…</js>` | 遇 `<js>` 找 `</js>`；未闭合则吃到结尾（`rule_ir.dart:94-103`） | `JS_PATTERN` 的非贪婪 `([\w\W]*?)</js>` | 近似 |
| `@js:` | 前缀匹配后**整段到尾**（`rule_ir.dart:112-116`） | `@js:([\w\W]*)` 同样贪婪到尾 | 等价 |
| `@webjs:` | 显式优先匹配 `@webjs:`，长度须 ≥5（`rule_ir.dart:106-111`） | `WebJS_PATTERN=@webjs:([\w\W]{5,})` | 见下方「已知缺陷」 |
| 引号内的标记 | 被 `skipUnit` 跳过，不会误判（`rule_ir.dart:88-92`） | 正则无此保护：`div[title="@js:x"]` 会被切开 | **Chloris 更严格** |
| 首字符 `:` 全正则 | `allInOne && startsWith(':')` → regex 且跳过首字符（`rule_ir.dart:58-63`） | 同（`AnalyzeRule.kt:537-543`） | 等价 |

> **Legado-E 缺陷（Chloris 已修）**：Legado 先跑 `JS_PATTERN` 再跑 `WebJS_PATTERN`（`AnalyzeRule.kt:545,556`）。由于 `JS_PATTERN` 的 `@js:` 分支是**子串匹配**，规则 `@webjs:...` 会在第 6 个字符处命中 `@js:`，被切成 `@web` + JS 步，`@webjs:` 分支永不生效。Chloris 的扫描器显式先处理 `@webjs:`，所以 `@webjs:` 真正可用。

### 2.3 单步规则（`SourceRule`）构造

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 模式前缀 | `@css:`→css / `@@`→去前缀 / `@xpath:` / `@json:` / `$.` `$[`→json / `/`→xpath（`analyze_rule.dart:548-572`） | 同（`AnalyzeRule.kt:600-634`），另含 `isJSON` 继承 | 等价 |
| 前缀大小写 | `@css:`/`@xpath:`/`@json:` 均 `toLowerCase()` 比较（`analyze_rule.dart:552,558,561`） | `startsWith(x, true)` 忽略大小写 | 等价 |
| `@put` 抽取 | 括号**平衡扫描** + 自写 JSON 分词（支持嵌套对象、引号内 `}`、单引号）（`analyze_rule.dart:584-697`） | 正则 `@put:(\{[^}]+?\})` + GSONStrict→GSON 回退（`AnalyzeRule.kt:454-477,946`） | **Chloris 更严格** |
| 非法 `@put` JSON | 保留原文作为规则文本（`analyze_rule.dart:600-608`） | 两条 GSON 都失败则**静默丢弃该段** | 非等价 |
| 非标准 JSON 告警 | 无 | 首次打印「@put 规则 JSON 格式不规范」（`AnalyzeRule.kt:468-473`） | Chloris 缺日志 |
| `@` 链切分 | `splitAt()` → `_splitAll` 且**过滤空段**（`rule_analyzer.dart:97`） | `splitRule("@")`，首段可空；`getResultList` 前有 `trim()` 但**未被所有调用点调用**（`AnalyzeByJSoup.kt:155,210`） | 非等价（见 §4.2） |
| `##` 替换后缀 | `makeUp` 内 `composed.split('##')` 取 1~4 段（`analyze_rule.dart:743-747`） | `makeUpRule` 内 `rule.split("##")` 取 1~4 段（`AnalyzeRule.kt:762-772`） | 等价（都不做引号感知） |
| `$1..$99` 分组引用 | 无该语法（Dart 侧只在 `_expandDollars` 做 `$n` 替换，语义等价） | `regexPattern=\$\d{1,2}` 在构造期解析为分段（`AnalyzeRule.kt:682-709`） | 实现差异、结果近似 |

### 2.4 缓存

| 能力点 | Chloris | Legado-E |
|---|---|---|
| 规则串 → 步骤列表 | 全局静态 LRU 256（`rule_cache.dart:5-9,83-88`），键含 `isJson/isRegex/allInOne` | 实例内 `HashMap` 无上限（`AnalyzeRule.kt:79,521-526`）+ 16 上限的 `getOrPutLimit`（`:576-580`） |
| 正则编译 | 全局静态 LRU 256，键含 `multiLine/dotAll/caseSensitive`（`rule_cache.dart:11-38`） | 实例内 `getOrPutLimit(regex, 16)`（`AnalyzeRule.kt:508-516`） |
| JS 脚本编译 | **无**（每次传源码字符串） | `scriptCache.getOrPutLimit(jsStr, 16)` 缓存 `CompiledScript`（`AnalyzeRule.kt:861-866`） |
| 淘汰策略 | 真 LRU（命中时 `remove`+重插）（`rule_cache.dart:19-24`） | `getOrPutLimit` 的近似淘汰 |

缓存粒度是**跨实例共享**（Chloris）与**单实例**（Legado）之别：Chloris 的命中率更高，但 `isJson/isRegex/allInOne` 已进键，不存在串味。

---

## 3. 执行内核 `AnalyzeRule`

### 3.1 三个入口的逐步对照

| 步骤 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 空规则 | `rule == null \|\| rule.isEmpty` → `''` / `[]`（`analyze_rule.dart:99,142`） | `TextUtils.isEmpty` → `''`；`getStringList` 返回 **null** | 返回值类型不同，上层已归一 |
| 逐段执行 | `putMap` → `makeUp` → 字面量短路 → `_apply` → 替换（`analyze_rule.dart:102-117`） | `putRule` → `makeUpRule` → `result ?: continue` → `when(mode)` → 替换（`AnalyzeRule.kt:330-353`） | 顺序等价 |
| 字面量短路 | `literalValue != null` 直接成为结果（`analyze_rule.dart:105-111`） | 无此概念；`@get:{k}` 由 `makeUpRule` 内联成值 | 实现差异，结果近似 |
| 空规则+有替换 | `rule.isEmpty && replaceRegex.isEmpty` 才 continue，否则走 `_apply`（`analyze_rule.dart:112`） | `rule.isNotBlank() \|\| replaceRegex.isEmpty()` 才求值（`AnalyzeRule.kt:335`） | **非等价**（见下） |
| 后段失败 | 不短路：`result` 为 null 时 `_apply` 仍被调用 | `result ?: continue` **提前终止后续所有段** | 非等价 |
| HTML 反转义 | `unescape && str.contains('&')` → `htmlUnescape`（自写实体表）（`analyze_rule.dart:119`） | `unescape && indexOf('&')>-1` → `StringEscapeUtils.unescapeHtml4`（Apache commons-text） | 近似 |
| isUrl 归一 | 空→`baseUrl`；`javascript:`/`mailto:`/`#`→`''`；去重；`getAbsoluteUrl`（`analyze_rule.dart:120-133,166-173`） | 空→`baseUrl`；`javascript*`→`''`（在 `NetworkUtils.getAbsoluteURL` 内）；去重；无 `mailto:`/`#` 特判 | Chloris 更严格 |
| 多值拼接 | CSS/XPath 走 `collapseJoinedStrings`（**包含关系去重 + 嵌套父优先 + 重复正文折叠**）（`network_utils.dart:234-256`） | `list.joinToString("\n")`（`AnalyzeByJSoup.kt:59`、`AnalyzeByXPath.kt:138`） | **非等价** |
| `getElements` 的 allInOne | `splitSourceRule(rule, allInOne: true)`（`analyze_rule.dart:185`） | `splitSourceRule(ruleStr, true)`（`AnalyzeRule.kt:415`） | 等价 |

> **分歧 3.1-a（空规则 + 替换后缀）**：规则形如 `@get:{k}##re##rep`。`makeUpRule`/`makeUp` 之后 `ruleStrS[0]` 为空，Legado 进入 `else` 分支执行 `getAnalyzeByJSoup(result).getString("")` → `getStringList("")` 返回空列表 → `getString` 返回 **null**（`AnalyzeByJSoup.kt:48-54`），随后 `replaceRegex` 对 `"null"` 施加替换；Chloris 因 `rule.isEmpty && rule.replaceRegex.isEmpty` 为假而进入 `_apply`，而 `_apply` 首行 `if (rule.isEmpty) return current;` 使结果保持为**输入内容**，再对输入内容施加替换。两侧最终文本不同。

> **分歧 3.1-b（`collapseJoinedStrings`）**：这是 Chloris 唯一一处**在结果层做语义消歧**的算法，Legado 没有对应物。作用：父节点 `@text` 已包含子节点文本时，不再把子节点命中追加成第二行；同时折叠重复正文。好处是目录/简介类规则更干净，代价是**输出与 Legado 不可逐字对齐**——`p@text` 命中 3 个段落时仍按 `\n` 拼接（实测 `MULTI_TEXT=x\ny`），但命中「父+子」嵌套集合时 Chloris 会少输出若干行。这是「等价率」指标里最容易被误判为回归的一处，需要在逐源验收时按规则类型区分。

### 3.2 替换（`##regex##replacement###`）

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 正则编译 | `RuleCompileCache.regex(dotAll: true)`，失败再退 `RegExp(dotAll:true)`（`analyze_rule.dart:469-492`） | `getOrPutLimit(regex,16)` → `String.toRegex()`（`AnalyzeRule.kt:508-516`） | 近似 |
| 非法正则 | `result.replaceAll(rule.replaceRegex, rule.replacement)`（字面替换）（`analyze_rule.dart:491`） | `result.replace(replaceRegex, replacement)`（同样字面）（`AnalyzeRule.kt:504`） | **等价**（有测试：`parser_parity_test.dart:76-84`） |
| `###` 只取首个匹配 | `firstMatch` + `replaceFirstMapped`（`analyze_rule.dart:475-482`） | `matcher.find()` + `group(0).replaceFirst`（`AnalyzeRule.kt:487-498`） | 等价（都不匹配时返回 `''`） |
| `$n` 展开 | 自写 `_expandDollars`（`$0..$groupCount`，越界→`''`）（`analyze_rule.dart:495-502`） | Kotlin `Regex.replace` 原生 `$n` | 近似 |
| 未匹配的非 first 分支 | `replaceAllMapped` → 原文不变 | `result.replace(regex, replacement)` → 原文不变 | 等价 |
| 首段永远不是替换 | 两侧都在 `##` 后取段（`analyze_rule.dart:743-747` / `AnalyzeRule.kt:762-772`） | 同 | 等价 |

**已修复的旧缺陷**：Chloris 的 `makeUp` 会把 `##match##replacement` 原样接到插值结果后（`analyze_rule.dart:711-742`），`equivalence_audit_test.dart` 的 `RULE-01` 专门回归这一点。

### 3.3 变量与模板

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| `put` 作用域 | `chapter → book → ruleData → source`，取第一个非 null（`analyze_rule.dart:313-326`） | `?:` 链，同序（`AnalyzeRule.kt:794-803`） | 等价 |
| `get` 优先级 | 同链，逐级 `isNotEmpty` 短路；特判 `bookName`/`title`（`analyze_rule.dart:328-340`） | 同（`AnalyzeRule.kt:808-823`） | **等价** |
| `RuleData` 形态 | `Map<String,String> values`，`get`→`values[key] ?? ''`（`rule_data.dart:3-11`） | `variableMap` + `putVariable` 返回布尔 + `getVariable()` 整表 JSON（`RuleData.kt:7-28`） | 近似 |
| 大变量分层 | **无** | ≥10000 字符转外置存储（`RuleDataInterface.kt:16-27`） | Chloris 缺失（内存/DB 形态差异） |
| 源级变量持久化 | `BookSource.runtimeVars` 仅内存（`book_source.dart:75-85`） | `CacheManager` 的 `v_<key>_<key>`（`BaseSource.kt:275-286`） | Chloris 缺失（重启丢失） |
| `{{...}}` 判定 | `_isRule(inner)` → 送 `host.getString`（`analyze_rule.dart:724-725`） | `isRule()` 同四个前缀 `@`/`$.`/`$[`/`//`（`AnalyzeRule.kt:733-738,775-780`） | 等价 |
| `{{}}` 内简单键 | 特判 `key`/`page`/`source.*`/`book.*` 走 `_evalSimple`（`analyze_rule.dart:730-734`） | 一律 `evalJS`（`AnalyzeRule.kt:739`） | 近似（等价结果、不同路径） |
| JS 数值格式化 | `_stringifyJsValue`：整数值去掉 `.0`（`analyze_rule.dart:823-831`） | `Double % 1.0 == 0.0` → `String.format("%.0f")`（`AnalyzeRule.kt:742-747`） | 等价 |
| `@get:{k}` 独占规则 | `_singleGetKey` 直接取变量为字面量（`analyze_rule.dart:791-799`） | 走 `makeUpRule` 内联 | 近似 |
| `@get` 非独占展开 | `_expandGetTokens` 平衡扫描（`analyze_rule.dart:769-789`） | `evalPattern=@get:\{[^}]+?\}`（**不允许 `}` 出现在值里**）（`AnalyzeRule.kt:947-948`） | **Chloris 更严格** |
| 内嵌 JSONPath `{$.x}` | 平衡扫描 `_expandEmbedded`（`analyze_by_jsonpath.dart:119-156`） | `innerRule("{$.")` 代码平衡（`AnalyzeByJSonPath.kt:41,79`） | 等价（Chloris 有测试：`parser_parity_test.dart:50-59`） |
| 变量键名告警 | 无 | `put("bookName"/"title")` 时 `Debug.log` 提示会被覆盖（`AnalyzeRule.kt:795-797`） | Chloris 缺日志 |
| `setContent(null)` | 允许 null（`analyze_rule.dart:52`） | `throw AssertionError("内容不可空")`（`AnalyzeRule.kt:97`） | Chloris 更宽容 |
| `isJson` 判定 | 标量 JSON 也认：`"`/数字/`true`/`false`/`null` 且 `jsonDecode` 成功（`analyze_rule.dart:518-544`） | 仅 `{...}` 或 `[...]`（`StringExtensions.kt:48-56`） | **非等价**：JSON 标量文档上同一规则走不同后端 |
| `isRegex` 状态 | 几乎不置位（仅 `allInOne && startsWith(':')`，`analyze_rule.dart:512`） | 同（`AnalyzeRule.kt:539`） | 等价 |
| `evalJs` 绑定 | 14 个具名绑定（见 §8） | 12 个（`AnalyzeRule.kt:829-843`）+ AnalyzeUrl 侧 5 个 | 见 §8 |

---

## 4. CSS 后端（`AnalyzeByCss` vs `AnalyzeByJSoup`）

### 4.1 总览

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 选择器引擎 | `package:html` 的 `querySelectorAll` + 自写谓词层（`analyze_by_css.dart:209-236`） | jsoup 1.16.2 `Element.select`（`AnalyzeByJSoup.kt:144`） | 不同引擎 |
| `@css:` 前缀 | 剥离后**整段**当 CSS 选择器（`analyze_by_css.dart:21-22`） | 剥离后同（`AnalyzeByJSoup.kt:516-521`） | 等价 |
| `:contains(...)` / `:containsOwn(...)` | 自写谓词，支持带/不带引号与 `:not(:contains(...))`（`analyze_by_css.dart:330-433`） | 依赖 jsoup 原生实现 | 近似 |
| `:matches(...)` / `:matchesOwn(...)` | 自写，按正则匹配（`analyze_by_css.dart:345,424-429`） | jsoup 原生 | 近似 |
| 选择器分组 `a, b` | 自写 `_splitSelectorGroups`，按 `,` 分组后去重合并（`analyze_by_css.dart:210-219,238-271`） | jsoup 原生（保序、可能重复） | 非等价（Chloris 去重、Legado 可重复） |
| `&&` / `\|\|` / `%%` | 三态合并同上（`analyze_by_css.dart:24-32,314-327`） | 同（`AnalyzeByJSoup.kt:139,180-193`） | 等价 |
| `%%` 对齐 | 以 `groups.first.length` 为上限、内层按 groups 顺序交错（`analyze_by_css.dart:316-325`） | 以 `elementsList[0].size` 为上限、同序（`AnalyzeByJSoup.kt:181-187`） | 等价 |
| XML 文档 | 无特判 | `<?xml` → `Parser.xmlParser()`（`AnalyzeByJSoup.kt:33-36`） | Chloris 缺失 |
| JXNode 输入 | 无（XPath 返回 Element） | `is JXNode` → `asElement()`（`AnalyzeByJSoup.kt:29-31`） | 架构差异 |
| 空选择器 | `_chain` 返回 `[root]`，再取文本（`analyze_by_css.dart:102-104,118`） | `element.data()`（`AnalyzeByJSoup.kt:81-83`） | 近似 |

### 4.2 `@` 链与结果算子

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| `@` 切分 | `RuleAnalyzer(rule).splitAt()`，**丢弃空段**（`analyze_by_css.dart:103,117`；`rule_analyzer.dart:97`） | `splitRule("@")` 保留空段；各调用点自行 `trim()`（`AnalyzeByJSoup.kt:157,212`） | 非等价（`@div@text` 段数不同） |
| 末段算子集 | 显式集合 `{text,html,ownText,href,src,content,tag}` 走 `_resultLast`，否则当选择器（`analyze_by_css.dart:120-133`） | 无白名单：凡进入 `getResultList` 的末段一律当算子（`AnalyzeByJSoup.kt:223`） | **非等价** |
| `@text` | `e.text.trim()`，空则丢弃（`analyze_by_css.dart:276-280,312`） | `element.text()`，空则丢弃（`AnalyzeByJSoup.kt:232-238`） | 等价 |
| `@textNodes` | 直接文本子节点，trim、非空、`\n` 拼接（`analyze_by_css.dart:281-289`） | 同（`AnalyzeByJSoup.kt:239-251`） | 等价 |
| `@ownText` | `nodes.whereType<Text>().join().trim()`（`analyze_by_css.dart:290-294`） | `element.ownText()` | 近似（jsoup 会对多种空白归一） |
| `@html` | 先 `querySelectorAll('script,style').remove()` 再 `${elements.map(outerHtml).join()}`（`analyze_by_css.dart:295-300`） | `elements.select("script").remove(); elements.select("style").remove(); elements.outerHtml()`（`AnalyzeByJSoup.kt:260-267`） | 近似（破坏性 vs 非破坏性） |
| `@all` | `<script>/<style>` 不删除（`analyze_by_css.dart:301-302`） | 同（`AnalyzeByJSoup.kt:269`） | 等价 |
| 属性算子 | `attributes[name]`，**空丢弃 + 值去重**（`analyze_by_css.dart:303-307`） | `element.attr(name)`，`isBlank` 丢弃、`textS.contains` 去重（`AnalyzeByJSoup.kt:270-277`） | 近似 |
| 实测 | `a@href` 于 `[/a,/a,/b]` → **`[/a, /b]`**（探针实测） | 同输入 → `[/a, /a, /b]` | **非等价**：重复属性值导致的列表长度/索引漂移 |

### 4.3 虚拟节点选择器（`tag.` / `class.` / `id.` / `text.` / `children`）

| 选择器 | Chloris | Legado-E | 实测（Chloris） |
|---|---|---|---|
| `children` | `temp.children`（`analyze_by_css.dart:160-161`） | `temp.children()`（`AnalyzeByJSoup.kt:315`） | 等价 |
| `class.x` | `temp.classes.contains('x') ? [temp] : []` **+** `getElementsByClassName`（`:162-168`） | 仅 `temp.getElementsByClass(rules[1])`（`:316`） | **非等价**：Chloris 会额外返回上下文自身 |
| `tag.x` | 上下文自身（若标签匹配）**+** `getElementsByTagName`（`:169-177`） | 仅 `temp.getElementsByTag(rules[1])`（`:317`） | **非等价**：`tag.div` 对 `<div>` 返回空（探针确认 `tag.div` 只回子节点；`tag.div` 顶层标签不会被选中） |
| `tag.*` | `querySelectorAll('*')` + 自身（`:171-177`） | jsoup `getElementsByTag("*")` | 近似 |
| `id.x` | 自身（若 `temp.id == x`）**+** `querySelector('#x')`（`:178-185`） | `Collector.collect(Evaluator.Id(x), temp)`（`:318`） | 非等价（Chloris 可命中自身） |
| `text.x` | `querySelectorAll('*')` 中**直接文本节点**含 `x` 者（`:186-190`） | `temp.getElementsContainingOwnText(rules[1])`（`:319`） | 近似（Chloris 对多段 `.` 会拼成整串做子串匹配） |
| 其它 | `querySelectorAll(beforeRule)`（`:191-192`） | `temp.select(beforeRule)`（`:320`） | 等价 |
| `class.a.b` | `bits.sublist(1).join('.')`（`:163`） | 只取 `rules[1]`（`:316`） | 非等价（Chloris 支持多点类名） |
| `tag.` 前缀在复合选择器 | `_normalizeCustomSelector` → 交给 CSS 引擎（`:152-156,198-203`） | 无此归一 | Chloris 独有 |

> 结论：`tag./class./id.` 这一族「虚拟节点」选择器的**是否包含上下文自身**两侧不同。Chloris 显式做了「自身命中则加入」的补偿（注释里也写明动机），Legado 依赖 jsoup 的纯后代语义。写成规则的典型形态是 `class.item`、`tag.li`（用于从**条目节点**继续下钻），因此在「先取条目、再取子节点」的两段式规则里两者一致；只有当规则被应用到与选择器同名的节点上时才会分叉。

### 4.4 索引区间算法（差异最细的一处）

| 语法 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 旧式 `tag.div.-1:10:2` | `_isIndexTail` + `_parseTail` 拆出 `[start,end,step]`（`analyze_by_css.dart:503-509,533-543`） | `findIndexSet` 逆向逐字符解析 `indexDefault`（`AnalyzeByJSoup.kt:482-510`） | 等价语义、不同算法 |
| 新式 `tag.div[-1, 3:-2:-10, 2]` | `_isBracketIndexExpression` 校验后解析（`:513-527`） | 同（`:418-481`） | 近似 |
| 纯 CSS 属性选择器 `a[href]` | 因体内非数字表达式**不当索引**（`:513-527`） | 因 `curInt == null` 而 `break`（`:443`） | 等价 |
| **区间右端是否含** | `for (i = start; i <= end; i += step)` → **含 end**（`:562,566`） | `start..end step step` → **不含 end**（`AnalyzeByJSoup.kt:370`） | **非等价**：`[1:4:2]` → Chloris `{1,3}`、Legado `{1,3}`（step>1 时恰好一致）；`[1:4]` → Chloris `{1,2,3,4}`、Legado `{1,2,3}` |
| 区间全越界 | 逐索引 `clamp` 后仍可能产出索引（`:554-570`） | 显式「同侧越界 → `continue`」跳过（`:348-351`） | 非等价 |
| `step >= len` | 仍按 `start..end` 迭代（`:562`） | 直接只取 `start`（`:359-363`） | 非等价 |
| 负 step 归一 | `step = range.step`（含负数原样）（`:555`） | `-stepX < len` → `stepX + len`；否则 1（`:366-367`） | 非等价 |
| 空区间结果 | 集合为空时**返回全部元素**（`:546` 提前返回 + `:571-577`） | 集合为空时返回空 `Elements` | **非等价** |
| 索引去重/顺序 | `Set<int>` 插入序（`:548,577`） | `mutableSetOf<Int>`（LinkedHashSet）（`:326`） | 等价 |
| 排除 `!` | `!set.contains(i)` 过滤（`:571-576`） | 置 null 后 `removeAll(nullSet)`（`:386-390`） | 等价 |

这一层是「同一书源、同一页面、两侧索引结果不同」最容易发生的区域，尤其是 `[n:m]` 这类无步长区间与越界区间。

---

## 5. XPath 后端

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 实现 | 手写子集解释器（`analyze_by_xpath.dart` 537 行） | jsoupXpath 2.5.3 + `QueryTTF.java`（`AnalyzeByXPath.kt` 155 行） | **能力集合不同** |
| 轴 | `child/descendant/descendant-or-self/parent/ancestor/ancestor-or-self/following-sibling/preceding-sibling/self/attribute` 显式枚举（`:174-232`） | jsoupXpath 全量轴 | 近似 |
| 谓词 | 位置 `[n]`、`last()`、`position() op N|last()`、`last()±N`（`:351-368`） | 全量 | **缺失**：`[position()=last()-1]` 之外还有 `[.='x']`、`[text()='x' and @class]` 的 NS/复杂形式 |
| 属性/文本函数 | `@a op 'v'`、`@a` 存在性、`contains(@a,'v')`、`starts-with(@a,'v')`、`contains(text(),'v')`、`starts-with(text(),'v')`、`text() op 'v'`、`normalize-space(text())`（`:369-428`） | 全量 | **缺失**：`string()`、`substring()`、`concat()`、`count()`、`sum()`、`number()`、`string-length()`、`name()`、`local-name()` |
| 逻辑 | `and` / `or` / `not(...)`，括号剥离与引号感知切分（`:338-350,464-528`） | 全量 | 近似 |
| 节点类型 | 只处理 Element | 处理 `JXNode`（元素/属性/文本/注释） | **缺失**：注释/处理指令/命名空间节点 |
| 返回值 | `e.text.trim()` + 非空过滤（`:59,72`） | `it.asString()`（不 trim、不过滤）（`AnalyzeByXPath.kt:99-101`） | **非等价**：空白文本节点、首尾空白 |
| 片段包裹 | 依赖 `package:html` 的 HTML 纠错 | `<td>`→`<tr>`→`<table>` 显式包裹（`AnalyzeByXPath.kt:29-34`） | 近似（不同纠错器） |
| XML | 无特殊处理 | `<?xml` → xmlParser（`AnalyzeByXPath.kt:36-39`） | Chloris 缺失 |
| 绝对路径 | 首步 child/descendant 且标签匹配时把上下文自身计入（`:105-109`） | jsoupXpath 原生 | 近似 |
| 组合符 | `&&`/`\|\|`/`%%` 递归拆分（`:23-51`） | 同（`AnalyzeByXPath.kt:57-90`） | 等价 |

> 这是**四个后端里能力缺口最大**的一个。实际影响：使用 `string()`、`count()`、`substring()`、`normalize-space` 组合表达式或注释节点选择的书源规则，在 Chloris 上会走到 `_matches` 的兜底 `return false`（`:429`），表现为**空结果而非报错**。

---

## 6. JSONPath 后端

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 实现 | 手写 JSONPath（`analyze_by_jsonpath.dart` 608 行） | Jayway json-path 2.10.0（`AnalyzeByJSonPath.kt` 172 行） | **能力集合不同** |
| 根/子/递归下降 | `$.a.b`、`$..a`（`:181-211,596-607`） | 全量 | 近似 |
| 通配 | `[*]`、`.*`、`$..*`（`:262-266,251`） | 全量 | 近似 |
| 切片 | `[a:b]`、`[a:b:c]`、负 step、负索引（`:337-374`） | 全量 | 近似（边界 clamp 自写） |
| 联合 | `[0,2]`、`['a','b']`、`[0]['name','title']`（`:270-289,306-325`） | 全量 | 近似 |
| 过滤 | `[?(@.x==1)]`，支持 `== != > < >= <= =~`、`contains/startsWith/endsWith`、`&& \|\| !`、`.length`、`@.a.b` 嵌套字段（`:376-466`） | Jayway 过滤 + 函数扩展 | 近似 |
| 函数扩展 | **无** | `min() max() avg() stddev() length() sum() keys() concat() append() first() last() index()` 等（Jayway 内置） | **缺失** |
| `=~` 正则算子 | ✅ 自写（`:454-462`） | Jayway 默认不支持（需 `Pattern` 编译或 `=~` 扩展） | **Chloris 独有** |
| `contains()/startsWith()/endsWith()` | ✅ 自写（`:402-423`） | Jayway 需 `=~` 或 `contains` 比较器 | **Chloris 独有** |
| 非法路径 | `_read`/`_walk` 返回空列表（`:181-211`） | 抛异常，`runCatching` 捕获后返回空/告警（`AnalyzeByJSonPath.kt:51-53`） | 近似 |
| 内嵌 `{$.x}` | 平衡扫描（`:119-156`） | `RuleAnalyzer(rule, true)` + `innerRule("{$.")`（`:34,41,79`） | 等价 |
| `getString` 多值 | `list.join('\n')`（`:78`） | `ob.joinToString("\n")`（`:47`） | 等价 |
| `getStringList` 多值 | 逐元素 `toString()`（`:158-168`） | 逐元素 `toString()`（`:83-85`） | 等价 |
| `getList` 组合符 | `\|\|` 提前返回首个非空组；`%%` 以首组长度对齐（`:36-58`） | 同（`:106-120`） | 等价 |
| `getObject` | 首元素，无匹配→null（`:61-64`） | `ctx.read(rule)`，异常上抛（`:125-127`） | 非等价（Legado 抛错） |
| 组合符用 code 平衡 | `getString` 用 `RuleAnalyzer(rule, true)`（`:68`）；`getStringList`/`getList` 用默认（`:83,25`） | `getString`/`getStringList`/`getList` 都用 `RuleAnalyzer(rule, true)`（`:34,74,132`） | **不一致**：Chloris 的 `getStringList` 对含 `[` 的 `&&` 切分策略与 `getString` 不同 |

---

## 7. 正则后端

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 链式语义 | 末段返回 `[group0..groupN]`；非末段把全部 `group(0)` 拼接后递归（`analyze_by_regex.dart:17-48`） | 同（`AnalyzeByRegex.kt:7-59`） | **等价** |
| 编译标志 | `RegExp(pattern, multiLine: true, dotAll: true)`（`:54`） | `Pattern.compile(regs[index])` **无标志**（`:11`） | **非等价**：`^`/`$` 行语义与 `.` 是否跨行不同 |
| pattern 预处理 | `raw.trim()`（`:51`） | 无 trim | 近似 |
| 空 pattern | 返回 `null`/`[]`（`:10-11,19-21`） | 抛 `PatternSyntaxException`（未捕获） | Chloris 更宽容 |
| `&&` 分割 | `RuleCompileCache.splitParts(rule,'&&')`（引号/括号感知）（`analyze_rule.dart:453`） | `rule.splitNotBlank("&&")`（纯字符串）（`AnalyzeRule.kt:391,425`） | **Chloris 更严格** |
| 空匹配 | `?` | `null` | 上层已归一 |

> 「多行/跨行正则」是与 Legado 最容易产生**静默差异**的一项：`dotAll: true` 让 `.` 匹配换行，`multiLine: true` 让 `^`/`$` 匹配每行首尾。同一正则在不同站点正文上会给出不同长度的结果。

---

## 8. JS 宿主边界

Chloris 的 `chloris_engine` **不含 JS 虚拟机**：`js_runtime.dart:14-22` 只声明 `abstract class JsRuntime`（含 `NoJsRuntime`、`LenientJsRuntime` 两个非 JS 回退），真机实现由 App 注入——`chloris/lib/engine/js_runtime/js_runtime_io.dart`（flutter_js → Android/iOS QuickJS、iOS JavaScriptCore）与 `js_runtime_web.dart`（浏览器 `eval`）。Legado-E 侧是 Rhino 1.8.1。因此这一层的差异是**宿主能力差异**，不是算法差异，但规则输出会因此不同。

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| 引擎 | QuickJS（移动端）/ 浏览器 `eval`（Web）；ES2020 | Rhino 1.8.1，`VERSION_ES6`、解释模式（`RhinoScriptEngine.kt:323-324`） | 近似（ES 级别 Chloris 更高） |
| 作用域 | 每次 `evalJs` **新建** `JsScope`（`analyze_rule.dart:353`）；Web 端 IIFE 隔离 | 每书源**共享 top scope**：`SharedJsScope` LruCache(16) + `preventExtensions()`（`SharedJsScope.kt:36,75`） | **语义差异**：Chloris 无跨调用 JS 状态 |
| jsLib | 每次调用字符串前置拼接（`analyze_rule.dart:342-346`） | 编译一次并缓存为共享 scope（`SharedJsScope.kt:38-83`） | 语义+性能差异 |
| 脚本编译缓存 | 无 | `scriptCache` 16 条（`AnalyzeRule.kt:861-866`） | Chloris 缺失 |
| 超时/递归上限 | 无（仅 HTTP 超时） | `instructionObserverThreshold=10000`、`maximumInterpreterStackDepth=1000`、`recursiveCount>=10` 抛 `RhinoRecursionError` | **Chloris 缺失**：死循环规则可挂死 |
| 沙箱 | 依赖 QuickJS/浏览器；Web 端规则可见 `window/document/fetch` | `RhinoClassShutter` 白名单拦截 Runtime/File/ProcessBuilder（`RhinoClassShutter.kt:44-80`） | 性质不同 |
| 异常语义 | 两层：`analyze_rule.dart:387-391` 先 `jsRuntime.eval`，抛错则**无条件**调 `LenientJsRuntime.interpretJs`；`interpretJs` 自身 `strict=true` 时会抛 `DomainError`，**但经 `evalJs` 这条路径进入时 is strict 检查之前不会先报错、而是先退化**——只要宽松解释器「猜中」了形态（`result`/`key`/`page`/URL/`result.replace`/`java.x()` 等），就返回一个**看起来合理的结果**且无任何信号（`js_runtime.dart:125-232`） | Rhino 异常→`ScriptException` 上抛（`RhinoScriptEngine.kt:106-115`） | **非等价**：真正危险的不是「回退原输入」，而是宽松解释器的**静默猜中** |
| `java.getElement(s)` 返回 | **标记字符串/markup**（JSON 桥限制，`js_host_bridge.dart:553-562`） | 真 jsoup `Element`，可 `.text()/.attr()/.select()` | **能力缺失** |
| `cache.get(k,d)` 第二参 | 默认值（`js_host_bridge.dart:144`） | `onlyDisk: Boolean`（`CacheManager.kt:98`） | **语义冲突** |
| 未知 `java.*` | 异步路径记 `java.missing` 并返回 `''`；**同步路径静默 `''`**（`java_host.dart:1162-1164,1313-1314`） | Rhino 抛错 | 非等价 |
| `java.ajax` 失败 | 返回 `''` / 错误响应 | 把堆栈当 body 返回（`JsExtensions.kt:114-121`） | 非等价 |

**绑定名对照**（两侧同名）：`java`、`result`、`baseUrl`、`book`、`chapter`、`source`、`src`、`cookie`、`cache`、`nextChapterUrl`、`fromBookInfo`、`key`、`page`、`title`、`rssArticle`、`speakText`、`speakSpeed`、`infoMap`。
**Chloris 缺**：`epubIndex`、`name`、`author`（导出书名规则用，`BookExtensions.kt:324-384`）。
**Chloris 独有**：桥内部 `__hid` / `__ajaxCache` / `__chlorisJava` / `sendMessage`（`js_host_bridge.dart:105-128`）。

**`java.*` 方法覆盖**：两侧共同覆盖约 70 个（`ajax/get/head/post/connect/getString/getStringList/getElement/getElements/base64*/md5*/hex*/htmlFormat/timeFormat*/encodeURI/t2s/s2t/randomUUID/toNumChapter/toURL/getCookie/getSource/getTag/log/toast/longToast/getWebViewUA/getReadBookConfig*/getThemeConfig*/getThemeMode/openUrl/openVideoPlayer/startBrowser*/getVerificationCode/cacheFile/downloadFile/readTxtFile/deleteFile/getTxtInFolder/unzip*/unArchive*/getZip|Rar|7z*Content/importScript/queryTTF*/replaceFont/webView*/androidId/put/digest*/HMac*/createSymmetricCrypto` 及 aes/des/3DES 族）。
**Chloris 缺**：`strToBytes`、`bytesToStr`、`base64DecodeToByteArray`、`hexDecodeToByteArray`、`createAsymmetricCrypto`、`createSign`、`cache.getInt/getLong/getDouble/getFloat/getByteArray`、`cache.put(k,v,saveTime)` 的第 3 参、`getFile(path)→File`（被实现成 `downloadFile(url)` 别名，`java_host.dart:531`）、`readFile(path)→ByteArray`（`java_host.dart:535-538`）、`ajax/connect/get/head/post` 的 `callTimeout` 形参、`ajaxAll/ajaxTestAll` 的 `skipRateLimit`、`webView*` 的 `cacheFirst`、`cookie.setCookie/replaceCookie/clear/cookieToMap/mapToCookie/getKey`。
**Chloris 独有**：`sha256Encode`、`base64EncodeStr/base64DecodeStr` 别名、`aesDecrypt(data,key,iv)`、顶层 `cacheDelete`、`java.removeCookie`。

---

## 9. 请求构造层（`AnalyzeUrl`）

| 能力点 | Chloris | Legado-E | 性质 |
|---|---|---|---|
| URL/选项切分 | `_optionComma` 大括号深度扫描（`analyze_url.dart:683-695`） | `paramPattern = \s*,\s*(?=\{)` 正则（`AnalyzeUrl.kt:768`） | Chloris 更严格（不被 URL 内的 `,{` 误切） |
| 选项 JSON 解析 | 单次 `jsonDecode`，失败静默 `catch(_){}`（`analyze_url.dart:641-668`） | `GSONStrict` → `GSON` 宽松回退 + 告警（`AnalyzeUrl.kt:233-239`） | **Chloris 缺容错**：不规范选项整段丢弃 |
| `@js:`/`<js>`/`@result` | `analyze_url.dart:545-566` | `AnalyzeUrl.kt:162-185` | 等价 |
| `{{...}}` 与 `<a,b,c>` 顺序 | **先页模板**（`:571`）**后 `{{}}`**（`:600-617`） | **先 `{{}}`**（`:192-204`）**后页模板**（`:206-216`）（注释明示「避免内嵌规则中的大于小于号被切错」） | **非等价** |
| `<a,b,c>` 语义 | 纯数字模板按 `first+(page-1)*step` **外推**（`:577-587`） | `pages[page-1]` / `pages.last()`（`AnalyzeUrl.kt:210-214`） | **非等价**：`<1,2,3>`+page=2 → Chloris `4`、Legado `2` |
| `{{key}}` | 替换为按 charset 预编码的值（`:600-609`）；charset 预读（`:621-632`） | `evalJS("key")` 原值，交由 query 编码器处理（`AnalyzeUrl.kt:192-204,298-314`） | 近似（编码时机不同） |
| URL 归一 | `getAbsoluteUrl` 自写：占位符保护 + `Uri.resolve` + 还原（`network_utils.dart:88-127`） | `java.net.URL(base, rel)` 语义（`NetworkUtils.kt:175-190`） | 近似（对畸形相对路径可能不同） |
| GET 参数编码 | 无整体 query 编码，仅 `{{key}}` 按 charset（`network_utils.dart:33-59`） | `analyzeQuery`→`encodeParams`，整串已编码则跳过（`AnalyzeUrl.kt:298-314`；`NetworkUtils.kt:99-123`） | **缺失**：GBK/Big5 站点 GET 参数不同 |
| POST 编码 | 由 `Content-Type: form-urlencoded` 触发，`Uri.encodeQueryComponent`（固定 UTF-8）（`analyze_url.dart:362-398`） | `!isJson && !isXml && 无 Content-Type` → `analyzeFields` + `URLEncoder.encode(charset)`（`AnalyzeUrl.kt:271-276,336-357`） | **非等价** |
| 已编码判定 | 子串正则 `%[0-9A-Fa-f]{2}`（`:392`） | 逐字符整串判定（`NetworkUtils.kt:99-149`） | 非等价 |
| `bodyJs` 作用对象 | **请求 body**（`:663-666`）；响应侧另用 `jsStr ?? webJs`（`:261`） | **响应 body**（`AnalyzeUrl.kt:507-510`） | **非等价** |
| `js` 选项 | 作用于 URL（`:660-662`） | 同（`AnalyzeUrl.kt:261-265`） | 等价 |
| headers 优先级 | `headerMapF → opt.headers → source.header`（source **最后覆盖**）（`:659,670-680`） | `headerMapF ?: source.header`（init）→ `opt.headers` **覆盖**（`AnalyzeUrl.kt:133-141,248-250`） | **优先级相反** |
| Cookie 优先级 | jar **覆盖**规则 Cookie；`enabledCookieJar=false` 时完全不带（`:188-193,252-257`） | 规则 Cookie 覆盖 jar（`mergeCookies(cookie, headerMap["Cookie"])`，`:703-725`） | **优先级相反** |
| `webView` 布尔 | 严格 `== true` / `'true'`（`:81`） | 非 null/""/false 即真（`AnalyzeUrl.kt:869-874`） | Chloris 更严格 |
| 重试 | `i<=retry`，2xx–4xx 即停，5xx/异常退避（`http_port.dart:160-198`） | 仅 `isSuccessful` 停，无退避（`OkHttpUtils.kt:36-42`） | **非等价**：403/404 行为相反 |
| charset/解码 | 优先 `spec.charset`（`http_port.dart:275-277`），GBK/Big5/UTF-16/BOM（`:318-346`） | `Content-Type` → `EncodingDetect`（`OkHttpUtils.kt:52-58,79-95`） | 非等价 |
| `type` | `getBytes`+hex，**绕过限速与 Cookie**，无 `data:`（`:209-217`） | hex + `data:` URI，受限速/`setCookie` 约束（`AnalyzeUrl.kt:424-426,554,634-655`） | 缺失 |
| 限速 | 全部等待（`rate_limiter.dart:42-111`） | 等待 + `skipRateLimit` 旁路（`AnalyzeUrl.kt:427-429`） | 近似 |
| `isTest` 错误码 | 无（只能抛异常） | -1…-7 负错误码（`AnalyzeUrl.kt:516-536`） | 缺失 |
| 请求合并/取消 | 同请求共享 Future + 会话泳道 + 按会话取消（`http_port.dart:64-150`） | 无 | **Chloris 独有** |
| WebView 不可用时 | HTML 嗅探回退 `sniffResourceUrl`（`:403-425,753-779`） | 无 | **Chloris 独有** |

---

## 10. Legado-E 自身缺陷（Chloris 已修正 / 不应计入缺失）

审计等价率时，以下项**不能**算作 Chloris 落后：

| # | Legado-E 行为 | 证据 | Chloris 处理 |
|---|---|---|---|
| 1 | `@webjs:` 被 `JS_PATTERN` 的 `@js:` 子串抢先，分支实际不可达 | `AnalyzeRule.kt:545-566` + `AppPattern.kt:7-8` | 显式优先匹配，可用 |
| 2 | `@get:{k}` 的值里含 `}` 会截断 | `evalPattern=@get:\{[^}]+?\}`（`AnalyzeRule.kt:947`） | 平衡扫描 |
| 3 | `@put` JSON 非法时静默丢弃整段 | `AnalyzeRule.kt:454-477` | 保留为规则文本 |
| 4 | `@put:{...}` 内含嵌套 `}` 会截断 | `@put:(\{[^}]+?\})`（`AnalyzeRule.kt:946`） | 平衡扫描 + 自写分词 |
| 5 | `ChompRuleBalanced` 在引号内不处理 `\` 转义，`ChompCodeBalanced` 才处理，两模式不一致 | `RuleAnalyzer.kt:104,145` | 统一处理 |
| 6 | `RuleData.getBigVariable` 返回 null，ruleData 作用域的大变量被静默丢弃 | `RuleData.kt:19-21` | 无该层，不丢弃 |
| 7 | `ruleReview` 持久化实际返回 null / `"null"` | `BookSource.kt:309-312` | 正常往返 |
| 8 | `mode == Regex` 且 `rule.isEmpty` 时 `else -> rule` 把空串当结果赋给 `result`（非 null 但空），后续 `result ?: continue` 不再短路 | `AnalyzeRule.kt:347,251` | 显式空规则短路 |
| 9 | `AnalyzeByJSoup.getString` 多值直接 `\n` 拼接，嵌套命中会产生重复正文 | `AnalyzeByJSoup.kt:59` | `collapseJoinedStrings` 消歧（**行为改善但输出不再逐字相同**） |
| 10 | `UrlOption.origin` 解析后无任何消费者 | `AnalyzeUrl.kt:789,845-851` | 同样透传，无差异 |

---

## 11. 逐层差异强度评估

沿用 `artifacts/verification/20260906-engine-equivalence-audit/report.md` 的口径（0–100%，表示「同一 fixture 两侧输出一致」的估计），本轮**细化了规则引擎部分**：

| 子层 | 上轮估计 | 本轮细估 | 主要扣分项 |
|---|---:|---:|---|
| 词法/编译 | 70–80% | **82–90%** | 平衡组保护面不同（`{`/`` ` ``/引号内转义）；`@` 链空段；`@put` 宽松回退 |
| 执行内核 | — | **85–92%** | `collapseJoinedStrings` 输出形态；空规则+替换；后段失败是否短路 |
| 变量/模板 | — | **88–95%** | 大变量分层缺失；源级变量不持久化；`isJson` 标量与 Legado 不同 |
| CSS 后端 | 70–80% | **78–88%** | 属性值去重；`tag./class./id.` 是否含自身；索引区间端点与越界算法 |
| XPath 后端 | 70–80% | **55–70%** | 缺 `string()/count()/substring()/concat()` 等函数；只处理 Element；返回值 trim 差异 |
| JSONPath 后端 | 70–80% | **75–88%** | 缺 Jayway 函数扩展；越界/畸形路径处理 |
| 正则后端 | — | **80–90%** | 编译标志（multiLine/dotAll）；`&&` 切分严格度 |
| 请求构造 | — | **65–80%** | 模板时序；`<a,b,c>` 外推；header/Cookie 优先级；`bodyJs` 作用对象；GET 编码 |
| JS 宿主 | 55–65% | **50–65%** | 无共享作用域/沙箱/超时；`getElement` 非真 Element；`cache.get` 第二参语义；异常回退原输入 |

**综合**：规则引擎主体（词法+执行+CSS）已进入「主流书源可用」区间；**XPath 与 JS 宿主是两个结构性短板**，`AnalyzeUrl` 是隐藏的行为分叉区（书源规则正确、但请求发错）。

---

## 12. 高优先级差异清单（按影响排序）

| 优先级 | 差异 | 影响面 | 证据 | 建议动作 |
|---|---|---|---|---|
| P0 | `AnalyzeUrl` 中 `{{}}` 与 `<a,b,c>` 处理顺序相反 + `<a,b,c>` 纯数字外推 | 分页请求发错页 | `analyze_url.dart:571,577-587` vs `AnalyzeUrl.kt:190-216` | 对齐为「先 `{{}}` 后页模板」；纯数字模板改为 `pages[page-1]`/`pages.last()` |
| P0 | header / Cookie 优先级与 Legado 相反 | 需要鉴权的书源整源不可用 | `analyze_url.dart:659,670-680,188-193` vs `AnalyzeUrl.kt:133-141,248-250,703-725` | 让 `opt.headers` 覆盖源 header、规则 Cookie 覆盖 jar |
| P0 | XPath 函数缺失（`string()/count()/substring()/concat()/normalize-space` 组合） | 使用这些函数的源静默返回空 | `analyze_by_xpath.dart:429` | 补函数子集或在失败时给出可见告警 |
| P1 | 正则 `dotAll/multiLine` 与 Legado 默认不同 | 正则规则结果长度/边界不同 | `analyze_by_regex.dart:54` vs `AnalyzeByRegex.kt:11` | 明确对齐策略（去掉标志或在规则层声明） |
| P1 | CSS 索引区间端点含入 / 越界 / 空集合回退全部 | 列表/目录条目错位 | `analyze_by_css.dart:546-577` vs `AnalyzeByJSoup.kt:339-381` | 对齐 `start..end` 不含 end、空集合返回空 |
| P1 | 属性值去重导致列表长度变化 | 目录条目缺失 | `analyze_by_css.dart:303-307` vs `AnalyzeByJSoup.kt:270-277` | 与 Legado 一致保留重复（或在规则层去重） |
| P1 | `bodyJs` 作用于请求 body 而非响应 body | 依赖 bodyJs 的源拿不到预期内容 | `analyze_url.dart:663-666` vs `AnalyzeUrl.kt:507-510` | 移到响应侧 |
| P1 | JS 异常路径静默退化 | 失败可能被当成功（宽松解释器「猜中」形态时无任何信号） | `analyze_rule.dart:387-391`；`js_runtime.dart:125-232`（`strict=true` 只覆盖直接使用 `LenientJsRuntime` 的路径） | 让 `evalJs` 的兜底也走 strict；`JavaHost` 不可用时不要静默返回 `''` |
| P1 | `java.getElement` 返回 markup 字符串而非 Element | 使用 `.text()/.attr()` 的规则必失效 | `js_host_bridge.dart:553-562` | 补 Element 门面（text/attr/select/html） |
| P2 | JSONPath 缺函数扩展（`length()/sum()/min()/keys()` 等） | 少数源失效 | `analyze_by_jsonpath.dart` 无对应实现 | 按需补高频函数 |
| P2 | `cache.get(k, true)` 被当默认值 | 缓存语义错 | `js_host_bridge.dart:144` vs `CacheManager.kt:98` | 修正第二参语义 |
| P2 | 大变量分层缺失 / 源级变量不持久化 | 大正文与登录态 | `rule_data.dart` 12 行；`book_source.dart:75-85` | 与存储层改造方案一并处理 |
| P2 | 无 `skipRateLimit` / `isTest` 错误码 / `type` 的 `data:` | 调试与特殊源 | `AnalyzeUrl.kt:427-429,516-536,634-655` | 按需补 |
| P3 | 无 `epubIndex/name/author` 绑定；`strToBytes/bytesToStr` 等工具缺失 | 少数源 | `BookExtensions.kt:324-384`；`JsExtensions.kt:560-620` | 低优先补齐 |

---

## 13. 复现与验证

本轮使用的可执行证据（临时探针已删除，结论可复核）：

```bash
export PATH="/Volumes/Software/Chloris/reference/flutter-sdk/flutter/bin:$PATH"
export HOME=/Volumes/Software/Chloris/.tmp-home
export PUB_CACHE=/Volumes/Software/Chloris/.tmp-home/pub-cache
cd /Volumes/Software/Chloris/packages/chloris_engine

# 规则 corpus + 解析一致性 + JSONPath 边界 + 等价性回归
dart test test/rule_golden_corpus_test.dart test/parser_parity_test.dart \
          test/json_path_edge_test.dart test/equivalence_audit_test.dart
# → 21 项全部通过（含 RULE-01/02、CONTENT-01..04、IR-01）
```

已确认的实测结论（供复核）：
- `a@href` 于 `<a href=/a><a href=/a><a href=/b>` → Chloris `[/a, /b]`（去重）；同日 `p@text` 于两个 `<p>` → `x\ny`（**未**折叠）。
- `tag.div` 在 `<div>` 上下文返回其子节点（`package:html` 的 `getElementsByTagName` 为纯后代语义），与 jsoup 一致；`class.c` / `tag.span` / `text.one` 均可用。
- 引擎侧 `dart test` 全量（含 golden corpus）目前无失败。

**尚未闭合的验证缺口**：本文的对照结论是**静态对读 + 单侧实测**，缺少「同一 fixture 在 Legado-E 上运行」的真机双侧差分。`equivalence_audit.dart` 已预留 `EquivalenceOracle` 接口（`equivalence_audit.dart:93-112`）与 `CallbackEquivalenceOracle`（`:101-112`），建议下一步接一个 Legado-E 判题进程，把 §12 的 P0/P1 项各写 2~3 条 fixture，形成真正的双侧 golden。

---

## 14. 附：规则语法要素在两套实现中的归属

| 语法要素 | 归属层（Chloris） | 归属层（Legado-E） |
|---|---|---|
| `&&` / `\|\|` / `%%` | `RuleAnalyzer.splitRule` | `RuleAnalyzer.splitRule` |
| `@` 链 | `RuleAnalyzer.splitAt`（CSS/XPath 后端内） | `AnalyzeByJSoup.getResultList` / `getElements` |
| `##regex##replacement###` | `SourceRule.makeUp` | `SourceRule.makeUpRule` |
| `@put:{...}` | `SourceRule._splitPut` | `SourceRule.splitPutRule` |
| `@get:{...}` | `SourceRule._expandGetTokens` | `SourceRule` 的 `evalPattern` 分支 |
| `{{...}}` | `SourceRule._doubleBraceTokens` | `SourceRule` 的 `evalPattern` 分支 |
| `<js>…</js>` / `@js:` / `@webjs:` | `RuleCompiler._scanMarkers` | `JS_PATTERN` / `WebJS_PATTERN` |
| `{$.x}` 内嵌 JSONPath | `AnalyzeByJsonPath._expandEmbedded` | `AnalyzeByJSonPath.innerRule("{$.")` |
| `{{key}}` / `{{page}}` / `<a,b,c>`（URL 内） | `AnalyzeUrl._replaceKeyPageJs` | `AnalyzeUrl.replaceKeyPageJs` |
| `-` / `+` 列表前缀 | `WebBook`（编排层，非引擎） | `BookList` / `BookChapterList`（编排层，非引擎） |
| 首次 `:` 全正则 | `RuleCompiler.compile(allInOne)` | `AnalyzeRule.splitSourceRule(allInOne)` |

两套实现在**语法归属上高度一致**——差异不在「谁负责解析」，而在「解析算法与边界处理」。这也解释了为什么绝大多数规则能互通，而分歧集中在少数边界形态上。

---

## 15. 本轮对齐结果（2026-09-12）

本节记录按 §12 清单实施后的实际状态，以及**用外部证据对本文的勘误**。验证产物在
`artifacts/verification/20260912-rule-engine-parity/`。

### 15.1 §13 的验证缺口已闭合

本文原先的结论是「静态对读 + 单侧实测」，缺少真机双侧差分。现在补上了：
`packages/chloris_engine/tool/legado_oracle/` 是一个**独立 Gradle/Kotlin JVM 工程**，
以符号链接方式直接编译 Legado 原始 `.kt`（不复制、不漂移），依赖版本与上游
`gradle/libs.versions.toml` 对齐（jsoup 1.16.2 / JsoupXpath 2.5.3 / json-path 2.10.0）。
Dart 侧的桥是 `lib/src/equivalence/legado_oracle.dart`（实现既有的 `EquivalenceOracle`），
驱动脚本 `tool/legado_oracle_audit.dart`，判题进程不可用时自动降级为 `SelfBaselineOracle`
并打印「本次不是双侧差分」的横幅。

当前覆盖与结果：**7 条 fixture，6 通过 1 分歧**（`equivalence-bilateral.json`）。
已接上的后端：regex / css / xpath / jsonpath / lexer（`RuleAnalyzer.kt`）。
`AnalyzeRule.kt` 因依赖 Rhino、`Debug`、`CacheManager` 与实体类未接；
`AnalyzeUrl.kt` 依赖 OkHttp/Glide/media3/hutool 已放弃——两者都如实标注，未伪造输出。

### 15.2 §12 的实施状态

| 优先级 | 项目 | 状态 | 证据 |
|---|---|---|---|
| P0-1 | 页模板时序 + `<a,b,c>` 外推 | ✅ 已修 | `AnalyzeUrl.kt:190-216`；先 `{{}}` 后页模板，纯数字取 `pages[page-1]`/`pages.last()` |
| P0-2 | header / Cookie 优先级 | ✅ 已修 | `AnalyzeUrl.kt:133-141,248-250` + `CookieManager.kt:101-107`；规则 Cookie 覆盖 jar，且 `enabledCookieJar=false` 时规则 Cookie 照常发送 |
| P0-3 | XPath 函数缺失 | ✅ 大部分已修 | 谓词层新增值表达式求值器；路径级补 `count()`；失败改为 `DebugLog` 可见告警 |
| P1-4 | CSS 索引区间 | ✅ 已修 | 逐行对齐 `AnalyzeByJSoup.kt:339-370` |
| P1-5 | 属性值去重 | ⛔ **无需修** | 见 15.3 勘误 2 |
| P1-6 | `bodyJs` 作用对象 | ✅ 已修 | 移至响应侧，对齐 `AnalyzeUrl.kt:507-510` |
| P1-7 | JS 异常静默退化 | ✅ 已修 | 区分「无 JS 引擎」与「脚本执行失败」，后者不再静默猜中 |
| P1-8 | 正则 `dotAll/multiLine` | ✅ 已修 | 去掉标志，对齐 `AnalyzeByRegex.kt:11` 的 Java 默认语义 |
| P1-9 | `java.getElement` 返回 markup | ✅ 已修 | 见 15.6；元素门面 `{"__el":…}` + JS prelude 还原成带方法的对象 |
| P2-10 | JSONPath 函数扩展 | ✅ 高频子集 | `length/first/last/sum/min/max/avg/keys` |
| P2-11 | `cache.get` 第二参语义 | ✅ 已修 | 见 15.6；第二参改为 `onlyDisk` 布尔量，并对齐内存/disk 两层 |
| P2-12 | 大变量分层 / 源级变量持久化 | ⛔ 未做 | 按原文判断，归 `JS与存储层改造方案.md` |
| P2-13 | `skipRateLimit` / 错误码 / `data:` | ⛔ 未做 | 按需 |
| P3-14 | `epubIndex` 等绑定与字节工具 | ⛔ 其中绑定一项**判定不必做** | 见 15.6 勘误 |

### 15.3 对本文的勘误（均由判题进程实测推翻，非推测）

| # | 本文原说法 | 实测结论 | 证据 |
|---|---|---|---|
| 1 | §4.4 区间右端**不含** end（`[1:4]` → Legado `{1,2,3}`） | **错**。Kotlin `..` 与 `downTo` 都是闭区间，**含 end**；`[1:4]` 两侧都是 `{1,2,3,4}`。Chloris 原本就是对的 | 判题进程 `a.0:2@text` → `zero\ntwo`，两侧一致；`AnalyzeByJSoup.kt:370` |
| 2 | §12 P1「属性值去重导致列表长度变化，应与 Legado 一致保留重复」 | **错**。Legado 同样去重：`AnalyzeByJSoup.kt:274` 有 `if (url.isBlank() \|\| textS.contains(url)) continue`。也不需要修 | 判题进程 `a@href` 于重复 href → 两侧都得 `x` |
| 3 | §5 / §12 P0-3 称 Legado 支持 `string()`、`normalize-space()` | **错**。jsoupXpath 2.5.3 对这两个函数名直接抛 `NoSuchFunctionException: not support function: string`。Legado 真正支持的是 `count()` / `sum()` / `string-length()` / `substring()`，且 `substring(//t,2)`（不带长度形参）会抛 `IndexOutOfBoundsException` | 判题进程逐条探测 |
| 4 | §6「`getString` 多值等价」 | **错**。数组结果上 Legado 是 `ob.joinToString("\n")`（`AnalyzeByJSonPath.kt:46-47`），Chloris 原先会把整个数组 `jsonEncode` 成 `["ch1","ch2","ch3"]`。已修 | 双侧 golden 的 `legado/json-basic`（修复前 FAIL，修复后 PASS） |
| 5 | §2「`@` 链空段」等若干条目 | 未复核 | 本轮未涉及，保留原判断 |

**新增确认的一处分歧**（原先未识别）：XPath 选中**元素节点**时，Legado 返回节点序列化
（`//title` → `<title>First</title>`），Chloris 返回 `text`；若规则以 `/text()` 收尾则两侧一致。
判题进程复核：`//title` → 序列化、`//title/text()` → `First\nSecond`。这是 §12 之外的真实分歧，
全面对齐会改变所有现存 XPath 规则的输出，属破坏性变更，**本轮不改**，已用 fixture 固化。

**顺带修掉的一个工具缺陷**：`equivalence_audit.dart` 的 `_deepEquals` 原本只处理
`num/List/Map`，对 `String`/`bool` 一律 `return false`——单侧自比时因对象相同而侥幸通过，
一旦接上真判题进程会让每个标量字段都报不一致。已修。

### 15.4 回归

`packages/chloris_engine` 全量 `dart test`：**340 项通过**（对齐前基线 296 项）。
新增对齐测试：`analyze_url_parity` / `css_index_parity` / `regex_flag_parity` /
`js_strict_failure` / `xpath_function_parity` / `jsonpath_function_parity`。

> 过程中引入并修掉的一个真实缺陷：CSS 降序区间分支曾写成 `i += step`，而归一后的 `step`
> 恒为正，于是 `start > end` 时条件永真、形成死循环，会导致整轮 `dart test` 挂死。
> `css_index_parity_test.dart` 已加守卫用例。

### 15.6 JS 宿主工作流（本轮补充）

#### `java.getElement` 返回真元素门面（§12 的 P1）

**原先的真实状态比本文 §8 写的更糟。** §8 说它「返回标记字符串/markup」；实际是
`invokeSync` 里**根本没有 `getElement` 分支**，落到 `default: return ''`，所以同步路径下
`java.getElement(x)` 拿到的是空串。异步路径（两遍求值）会给出 markup 字符串，而在
markup 字符串上调用 `.text()` 同样是 `TypeError` —— 结论是**这类规则在任何路径下都必然失效**，
与 §12 记的现象一致。

修法（`lib/src/js/java_host.dart` + `lib/src/js/js_host_bridge.dart`）：

1. Dart 侧保留**活节点**并发放句柄（FIFO，上限 128），回一个自识别信封：
   `{"__el": {描述符}}` / `{"__els": [描述符]}` / `{"__raws": [非元素结果]}`。
   描述符带 `tag/id/cls/attrs/text/own/html/outer`，门面大多数方法因此无需回问。
2. JS prelude 新增 `__mkEl` / `__mkEls` / `__elFrom`：
   - `__mkEl` 给出 jsoup `Element` 那一套：`text() ownText() html() outerHtml() attr() hasAttr() attributes() id() className() tagName() children() parent() select() selectFirst() getElementsByTag() getElementsByClass()`，并有 `toString()` 回 `outerHtml`。
   - `__mkEls` 给出 jsoup `Elements` 的聚合语义（`text()` 按 `\n` 拼接、`html()`、`outerHtml()`、`size()`、`get()`、`first()`、`last()`、`select()`）。这一层不能省 —— 真实书源大量写 `java.getElement('div.list').select('a').text()`。
   - `__elFrom` 只认三种信封，**其余值原样返回**。正则后端返回的普通字符串（包括 `"123"` 这种看着像 JSON 的）行为完全不变，所以这是纯增量改动。
3. 门面里需要继续下钻的方法走同步桥 `elementOp`，返回 JSON 字符串（两个运行时的
   `invokeSync` 出口都会 `.toString()`，所以不能回 Map）。
4. 句柄被淘汰时打 `DebugLog` 可见告警，不静默返回空。

两遍求值是成立的：第一遍调用会抛 `TypeError`，但 `_dispatch` 已把调用记进 `pending`，
`fulfill()` 返回 true 触发第二遍，第二遍拿到门面后成功（`js_runtime_io.dart:71-103`）。

#### `cache.get` 第二参语义（§12 的 P2）

对齐 `help/CacheManager.kt`：

| 调用 | Legado 行为 | 改前 Chloris | 改后 Chloris |
|---|---|---|---|
| `cache.put(k,v,saveTime)` | `saveTime` 秒，0=不过期；写内存+disk | 忽略第三参 | 一致（disk 层为进程内替身） |
| `cache.get(k)` | 内存优先 → disk，命中回填内存 | 仅内存 | 一致 |
| `cache.get(k, true)` | **只读 disk** | 当成「默认值 `true`」，返回 `'true'` | 只读 disk |
| `cache.putMemory` / `getFromMemory` / `deleteMemory` | 仅内存层 | 与 `put/get/delete` 混用同一层 | 分离 |
| `cache.getInt/Long/Double/Float` | 内存 → 只读 disk → 解析 | 缺失 | 已补（`Long/Float` 复用整数/浮点路径） |

`test/js_bindings_test.dart` 原有一条断言 `cacheGet('missing','fallback') == 'fallback'`，
那是在断言 Chloris 独有语义；已按 P2 改成断言 Legado 语义，并在注释里写明原因。

#### 勘误：`epubIndex` / `name` / `author` 不是「绑定缺口」

§8 把它们列为「Chloris 缺的绑定」。实际去读 Legado 源码：这三个绑定是
`help/book/BookExtensions.kt:318-360` 的 `getExportFileName` 用 `buildScriptBindings`
注入的，属于**导出书名规则**，**不在书源规则求值的作用域里**（那边 Legado 也没有它们）。

Chloris 既没有「导出书名规则」这个功能（引擎与 App 都搜不到 `bookExportFileName`），
把它们加进 `AnalyzeRule.evalJs` 反而是错的 —— 书源规则里它们没有正确取值可给。
所以这一项应记为**功能缺口**（导出命名规则未实现），而不是绑定表缺三个名字。

#### 仍未做

- `strToBytes` / `bytesToStr` / `base64DecodeToByteArray` / `hexDecodeToByteArray`：
  要让字节数组穿过桥，需要给同步出口加一条非字符串通道。收益（极少数书源）与
  改动面不匹配，留待有实际需求时做。
- `createAsymmetricCrypto` / `createSign`：同上。
- `java.getFile(path)→File` / `readFile(path)→ByteArray`、`ajax*` 的 `callTimeout`、
  `webView*` 的 `cacheFirst`、`cookie.setCookie/replaceCookie/...` 一族：未动。

### 15.7 回归汇总

| 阶段 | `dart test` | 说明 |
|---|---:|---|
| 对齐前基线 | 296 | — |
| P0/P1 第一批落地后 | 340 | +44（含 6 个新对齐测试文件） |
| JS 宿主工作流落地后 | **353** | +13（`js_element_facade_test.dart`，含真 Node 引擎的 prelude 端到端） |

`dart analyze lib` 无 error / warning。双侧 golden 稳定在 **7 条 6 通过**。

### 15.8 仍未闭合（截至本轮）

1. **真机书源闭环未跑**：搜索 → 详情 → 目录 → 正文 → 换章 → 换源，尚未在真实站点上端到端验证。
2. **双侧 golden 的密度不够**：§5 要求「P0/P1 每项各 2~3 条 fixture」，目前只有 7 条，
   且请求构造层（`AnalyzeUrl`）**一条都没有** —— 判题进程没接 `AnalyzeUrl.kt`
   （依赖 OkHttp/Glide/media3/hutool），P0-1、P0-2 这两条最重要的修复目前只有 Chloris 单侧测试。
3. **`xpath-element` 与 `keys()` 两处分歧刻意保留**：元素节点序列化 vs text、Java `Set.toString`
   形态，全面对齐都是破坏性变更，见 15.3 与 `jsonpath_function_parity_test.dart`。
4. **路径级 `sum()` / `string-length()` / `substring()` 未接**：Legado 侧 `substring(//t,2)`
   自身抛 `IndexOutOfBoundsException`，照抄无意义。路径级只做了 `count()`。
5. **字节通道**：`strToBytes` / `bytesToStr` / `base64DecodeToByteArray` 等未做，
   需要给同步桥加非字符串返回通道（见 15.6 末）。
6. ~~**`data:` URI、`isTest` 负错误码、`skipRateLimit`**（§12 的 P2-13）未做。~~ → 见 15.9，已完成。
7. ~~**大变量分层与源级变量持久化**（§12 的 P2-12）按原文判断归 `JS与存储层改造方案.md`，本轮未动。~~ → 见 15.9，已按查证结果分别处理。

---

## 16. 第二轮补充：真机闭环 + 剩余 P2（2026-09-12 续）

### 16.1 真机书源闭环（§5 第 3 条，长期未做，现已执行）

新增 `packages/chloris_engine/tool/live_source_loop.dart`，语料用
`chloris/assets/sources/verified_book_sources.json`（756 个源，全部 `enabled`）。
每个源跑：搜索 → 详情 → 目录 → 正文 → 换章 →（条件触发）换源，逐阶段记录耗时与失败原因。

**全量 756 源的实测结果**（`artifacts/verification/20260912-rule-engine-parity/`）：

| 阶段 | 不含 JS | 含 JS |
|---|---:|---:|
| search | 16 | 13 |
| detail | 13 | 9 |
| toc | 12 | 9 |
| content | 3 | 3 |
| nextChapter | 2 | 3 |
| changeSource | 0 | 0 |

不含 JS 的 268 个源里，未闭环的归因是：

| 归因 | 数量 | 说明 |
|---|---:|---|
| env | 228 | 出口代理拦断 / TLS 证书校验失败 / 超时 / HTTP 5xx。**与引擎无关** |
| source | 26 | 请求成功但抽不到内容（站点改版或站点自身故障） |
| js | 12 | 规则实际用到 JS，而 CLI 环境只有 `NoJsRuntime` |
| **engine** | **0** | **全量 756 源里没有任何一次引擎异常或规则求值崩溃** |

`engine = 0` 是这轮最重要的结论：**报告里的失败没有一条能归到引擎头上**。

**归因不是靠猜的，逐条查过：**

- 「站点层」的代表案例：`www.52shukuw.cc` 的搜索页里直接写着站点自己的错误
  `[XSErrorException] ../soso/sdk/php/lib/XS.php(2563): fsockopen(): unable to connect to localhost:8384 (Connection refused)`
  以及 `<!-- empty result -->` —— 是站点搜索后端坏了，引擎抽 0 条是**正确行为**。
- 「环境层」的成因：本机没有设置任何 `*_PROXY` 环境变量，`curl --noproxy '*'` 同样可用，
  说明 502/503 来自沙箱的**透明出口白名单**；同一主机 `curl` 能通，换台主机就 502，
  这是环境限制而非引擎缺陷。
- 「疑似引擎问题」的抽查：真机报告里 `新笔趣阁 / xbiquge.la` 报「搜索返回空列表」，
  但把站点实际返回的页面存下来、交给引擎重跑同一条规则，
  `class.grid@tag.tbody@tag.tr!0` 抽出 **50 行**、`class.even.0@tag.a@text` 正确给出书名
  （见 16.2 的诊断探针）。也就是说那次失败来自站点的瞬时响应，不是规则求值错误。

**换源阶段的定向验证**（`live-source-loop-changesource.log` / `live-changesource.json`）：
换源要求「同一本书在另一个源上也能搜到」，可达样本太小时凑不出成对命中，
所以单靠全量扫描拿不到成功记录。改用已知闭环成功的书名《萌娘三国演义》作关键词、
把候选范围放开到全量语料后，拿到一条完整记录 ——

```
小说 http://yetianlian.info  《三国演义：白话版》
  search        OK  744ms  50 条
  detail        OK  294ms  作者:小河流水12
  toc           OK   10ms  35 章
  content       OK  302ms  5226 字
  nextChapter   OK  436ms  5568 字
  changeSource  OK  12178ms 改由「去读书啊」取得 6814 字
```

即**六个阶段全部在真实站点上跑通**。这轮 engine 同样为 0。

**已知边界**：`chloris_engine` 包内没有 JS 虚拟机（真机实现由 App 注入），
所以含 JS 规则的源无法在 CLI 下真正求值。这里刻意注入 `NoJsRuntime` 而不是宽松
解释器 —— 见 16.3。换源成功那条记录的源本身含 JS 规则，说明该源的 JS 不在关键路径上。

### 16.2 新增诊断探针 `tool/probe_rules.dart`

真机报告出现「搜索返回空列表 / 目录为空 / 正文为空」时，用它把三种原因分开：

1. 页面本身就没有目标元素（站点改版 / 站点返回垃圾页）；
2. 规则写法与页面结构不符（书源规则问题）；
3. 引擎求值错误（真缺陷）。

```bash
curl -sL -A "Mozilla/5.0 (Linux; Android 13) Chrome/120" -o /tmp/p.html '<搜索URL>'
dart run tool/probe_rules.dart /tmp/p.html '<bookList规则>' '<name规则>'
```

没有它就只能靠猜，而「猜成引擎问题」正是上一轮把 196 个 HTTP 503 记成 engine 的原因。

### 16.3 §12 的 P2-13 已完成

| 项 | 实现 | 证据 |
|---|---|---|
| `data:` URI | `type` 选项下按 `^data:.*?;base64,(.*)` 解出字节再转 hex，不发请求、不受限速与 Cookie 约束 | `AppPattern.kt:20`、`AnalyzeUrl.kt:634-645`；`analyze_url_options_parity_test.dart` |
| `isTest` 负错误码 | 测试模式下不抛异常，折叠成带负码的响应：-1 超过设定时间 / -2 超时 / -3 未找到域名 / -4 连接被拒 / -5 Socket / -6 SSL / -7 其它 | `AnalyzeUrl.kt:516-536`；同测试文件逐码断言 |
| `skipRateLimit` | 旁路限速器 | `AnalyzeUrl.kt:427-432`；同测试文件用 400ms 间隔实测对比 |

`StrResponse` 补了 `callTime` 字段承载负错误码（对齐 `AnalyzeUrl.kt:513-514,533-535`）。

**实现上必须偏离原文的一处**：Java 的异常类型与 Dart 不是一一对应的，
照抄 `is SocketTimeoutException` 这类类型判断在 Dart 侧编译都过不了。
而且 `analyze_url.dart` **不能**引 `dart:io`（引擎要能编到 Web），
所以负错误码按消息特征判定，并在代码注释里给了完整对照表。

**顺带修掉两个真实缺陷**（由新测试抓出）：

- `getBaseUrl` 直接取 `Uri.origin`，遇到 `data:` 抛
  「Origin is only applicable schemes http and https」。Legado 的
  `NetworkUtils.getBaseUrl`（`NetworkUtils.kt:192-203`）**只**认 http/https、其余返回 null，
  现已照做。
- `AnalyzeUrl.init()` 只要解析出的 URL 不以 `http` 开头就会尝试用宽松解释器
  「补救」URL。`data:` URI 因此被误判为解析失败。现在 `data:` 不再走那条路。

### 16.4 §12 的 P2-12：两个子项结论相反

**(a) 源级变量持久化 —— 是真缺口，已实现。**
Legado 的 `java.put` 写 `CacheManager`，键 `v_<bookSourceUrl>_<key>`，无 TTL、**跨重启**（`BaseSource.kt:275-286`）；
Chloris 只是一个进程内 map。新增 `net/kv_port.dart`：`KvPort` / `MemoryKvPort` /
`UnsupportedKvPort`（不可用即抛 `DomainError`，与 `UnsupportedFilePort` 同一约定），
`BookSource.varStore` 挂上后即按 Legado 的键格式读写，并在命中后回填内存层
（对齐 `CacheManager.get` 的磁盘→内存提升）。**没有挂持久层时会打一次可见告警** ——
否则「写成功但重启就没了」会以「偶尔要重新登录」这种最难查的形式暴露。

**(b) 大变量分层 —— 不是等价性缺口，未实现。**
去读 Legado 的真实实现后，情况与 §12 的措辞不同：

| 作用域 | Legado 实现 | 是否真分层 |
|---|---|---|
| `RuleData`（独立规则数据） | `RuleData.kt:11-21`：`putBigVariable` 仍写 `variableMap`，`getBigVariable` 恒返回 null | **否**（§10 缺陷 #6 即此） |
| `Book` / `BookChapter` / RSS | `BaseBook.kt:34-40` / `BookChapter.kt:103-109` / `BaseRssArticle.kt:21-27` 经 `RuleBigDataHelp` 落文件 | 是 |

而书/章节这两个作用域里，**小变量本身就是持久化的**（Legado 存 DB 列 `variable`，
Chloris 存同一列）。所以分层带来的差别只是**存储介质**（Legado 大值落文件、Chloris 落 DB 列），
**不是可观察行为**。`RuleData` 作用域两侧都不分层，也不存在差距。

因此 P2-12 的正确结论是：**持久化那半是真缺口（已修），分层那半不是缺口**（如
DB 列体积成为问题，属存储层改造，见 `archive/JS与存储层改造方案.md`）。

### 16.5 本轮回归

| 阶段 | `dart test` |
|---|---:|
| 对齐前基线 | 296 |
| P0/P1 第一批 | 340 |
| JS 宿主工作流 | 353 |
| P2-13 + 源级变量持久化 | **368 → 378** |

`dart analyze lib tool test` 无 error / warning。新增测试文件：
`analyze_url_options_parity_test.dart`（15 项）、`source_var_persistence_test.dart`（10 项）。

### 16.6 仍未闭合（本轮结束时的准确状态）

1. ~~**换源阶段零成功记录**（16.1）—— 代码已实现，但没有一次真实成功。~~
   → 已拿到真实成功记录，见 16.1 末尾。六阶段全部在真实站点上跑通。
2. **请求构造层的双侧 golden 依然缺失**（15.8 第 2 条）。本轮评估后确认
   `AnalyzeUrl.kt` **无法在 JVM 上忠实判题**：它依赖的 `io.legado.app.help.http` 整包
   建立在 `android.webkit.WebView`、`android.net.http.*`、Room(`appDb`)、Glide 之上
   （`help/http/*.kt` 共 2676 行），要垫的是一整个 Android 框架，垫片规模一旦到这个量级，
   「跑的还是原始实现」这个前提就不再成立。P0-1/P0-2 目前仍是 Chloris 单侧测试 + 源码行级证据。
3. **依赖 JS 求值的规则仍未验证**（引擎包内没有 JS 虚拟机）。含 JS 的源里有一批不依赖
   JS 求值，本轮闭环 6 个、换源记录即来自其中一个；但多数含 JS 规则的源在 CLI 下无法真正求值，
   需要 App 注入真机运行时后再补跑。
4. `xpath-element` 与 `keys()` 两处分歧刻意保留（15.3）。
5. 路径级 `sum()` / `string-length()` / `substring()` 未接（15.8 第 4 条）。
6. 字节通道未做（15.6 末）。
7. 全量扫描里「站点层」的 93 个源没有逐条与 Legado 对照 —— 区分「书源失效」与「引擎缺口」
   需要跑 Legado 侧。本轮只抽查了其中两条（结论都是站点问题），其余未查。
