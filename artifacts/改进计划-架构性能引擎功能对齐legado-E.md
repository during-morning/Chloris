# Chloris 改进计划：架构 · 性能 · 引擎 · 功能对齐 legado-E

> **2026-09-12 执行结果（第二轮，无人值守批次）**：阶段 0、1、2 的**全部可完成项已落地**，
> 阶段 3 完成两项（3.2 替换作用域、3.5+3.6 平台基线），其余按风险/依赖记录跳过。
> 引擎测试 **385 → 423 项全绿**；`flutter analyze` 254 → **251** issues、error 清零（修了 2 个坏测试）。
> 逐项结果见文末 **§7 执行台账**；改动前快照备份在 `.backup-20260912/`。

> 生成日期：2026-09-12。基于对 `packages/chloris_engine`（16,486 行）、`chloris/lib`（189 文件 / 44,904 行）的逐文件调研，以及 `reference/legado-E-main` 的功能面清点。
> 本计划与在办的《规则引擎算法与legado-E差异》衔接：那份计划管「规则等价性」，本计划管「除此之外的一切」。

---

## 一、功能 + 解析引擎对照表（vs legado-E）

### 1.1 功能对照

> 状态更新至 2026-09-12 第二批次（执行台账见 §7）。

图例：✅ 已可用 · 🟡 部分实现/有缺口 · ❌ 缺失 · ➖ 不计划做（平台不可能）

| 功能域 | 能力 | legado-E | Chloris | 缺口说明 |
| --- | --- | --- | --- | --- |
| 书架 | 分组/标签 | ✅ `BookGroup` | ✅ | **已补**（第三批）：分组定义+成员位掩码 KV 持久化，工具栏分组筛选+长按归属管理；DB `books.group` 位掩码列保留，待表结构迁移定稿后并入 |
| | 排序/置顶/批量管理 | ✅ | ✅ | 核实：排序菜单（最近更新/书名/作者/自定义）、置顶（长按菜单+持久化+置顶优先排序）、批量删除**均已存在** |
| | 刷新追更 | ✅ 手动触发 | 🟡 | 无定时调度（legado 自己也没有，非缺口） |
| 搜索 | 多源并发/停止/续搜 | ✅ | ✅ | host 级并发上限（2/host）；**早停已接入**（命中阈值收尾，续搜契约保住） |
| | 精确搜索/换源 | ✅ | ✅ | 换源保持全量扫描（不套用早停阈值） |
| | `checkKeyWord` 校验词 | ✅ `SearchRule.checkKeyWord` | ✅ | **已补**（第三批）：`BookSource.getCheckKeyword`（对齐 BookSource.kt:212-220 的 http/::/++/-- 排除规则）+ 调试页默认词消费 |
| 阅读 | 翻页：覆盖/滑动/滚动/无动画 | ✅ | ✅ | 菜单开合触发整章重排的 bug **已修**（缓存 key 剥离菜单态） |
| | 仿真翻页 | ✅ `SimulationPageDelegate` | ✅ | **已补**（第三批）：风格化卷页（可见区收缩+纸背渐变+软阴影，几何纯 Dart 可测，13 项不变式）；设置面板出现「仿真」项；物理逐像素卷曲为后续升级 |
| | 双页模式 | ➖（无） | ✅ | Chloris 独有 |
| | TTS 朗读/在线 TTS 源 | ✅ 前台 Service | ❌ | 实现仍缺；`POST_NOTIFICATIONS` 权限已声明 |
| | 漫画/音频/视频 | ✅ | ✅ | 媒体栈冗余见 §2-A2 |
| | 词典 `DictRule` | ✅ | ❌ | 低频 |
| | 段评 `ruleReview` | ✅ | ❌ | 低频，可不做 |
| 替换净化 | 作用域字段 | ✅ `scope/scopeTitle/scopeContent/excludeScope` | ✅ | 四字段模型/DB 均在位；**执行侧 `excludeScope` 已补齐**（对齐 legado LIKE 语义，12 项测试）；UI 编辑页未透出新字段 |
| 本地书 | TXT/EPUB/MOBI/PDF/UMD | ✅ | 🟡 | 复杂 KF8/PDF 布局在扩展 |
| | TXT 目录规则 `TxtTocRule` | ✅ | ✅ | **已补**（第三批）：规则评选对齐 legado 评分算法（正/误报比、>70 章提前收敛）、前言章节、`replacement` 标题净化 JS、tocUrl rule+replacement 往返；8 测试 |
| 书源 | 登录 `loginUrl/loginUi/loginCheckJs` | ✅ | 🟡 | 有登录入口，`loginUi` 自定义表单未对齐 |
| | `coverDecodeJs` 封面解密 | ✅ | ✅ | **更正**：核实 `_decodeCover`（web_book.dart:1400）已实现，原判断有误 |
| | `jsLib` 共享脚本作用域 | ✅ `SharedJsScope` | 🟡 | **声明型共享已落地**（`JsHostBridge.prependJsLib` 收口 + 8 测试，多源不串扰）；可变全局态跨 eval 持久化仍缺 |
| | `exploreScreen` 发现筛选 | ➖（legado 自身未消费） | ➖ | **更正**：全 legado 源码仅实体定义，无任何消费点，不构成缺口 |
| | `weight/respondTime` 智能排序 | ➖（legado 自身未消费） | 🟡 | **更正**：legado 的 `.weight` 无消费点；Chloris 按测速排序，字段已解析备未来使用 |
| | `eventListener/customButton` | ✅ | ❌ | 低频 |
| RSS | RSS2/Atom/JSON Feed | ✅ | ✅ | `sortUrl`、正文黑白名单未对齐 |
| 服务 | Web 服务/WebSocket | ✅ | ✅ 桌面端 | |
| | WebDAV/备份 | ✅ | ✅ | |
| 平台 | Android 权限/文件关联 | ✅ | ✅ | **已修**：release 此前零权限（联网不可用）；现补 INTERNET/POST_NOTIFICATIONS + .txt/.epub VIEW 过滤器 |
| | Android 后台下载/通知/TTS | ✅ 前台 Service | ❌ | 实现（前台 Service/WorkManager）仍缺 |
| | iOS 文档类型 | ✅ | ✅ | CFBundleDocumentTypes（txt/epub）+ 导入式打开；后台模式按规范未声明 |
| | Web 端数据库 | ➖（无 Web 端） | ✅ | **已修**：`driftDatabase()` 此前缺 `web` 参数（开库即崩），已接线 + wasm 资产落位；README「Web 闭环」声明需复查 |
| | 字体反爬 `queryTTF/replaceFont` | ✅ `QueryTTF.java` | ❌ | 有此类规则的源整源失败 |
| | 字体导入管理 | ✅ | ❌ | 仅内置四套 OFL 字体 |

### 1.2 解析引擎对照（估计值；第二轮已核实并补测试锁定）

| 子层 | 估计 | 核实结论（证据） |
| --- | ---: | --- |
| 变量与模板 | 88–95% | 与对齐文档一致 |
| 执行内核 | 85–92% | 与对齐文档一致 |
| 词法与编译 | 82–90% | 与对齐文档一致 |
| 正则 | 80–90% | 与对齐文档一致 |
| CSS | 78–88% | 语义不变；RegExp/谓词解析**已接 `RuleCompileCache`**（性能项） |
| JSONPath | 75–88% | 函数扩展已补高频子集；`=~` 正则已接缓存 |
| 请求构造 | 70–82% | 分页模板时序**已修**；**`type` 已核实为「二进制下载标记」（响应转 hex，`AnalyzeUrl.kt:424-426`），引擎实现与 legado 对齐并已锁定**（7 测试）；剩余：**webSocket 零支持**（legado 的 `type` 并不路由 WS，此项为独立能力） |
| XPath | 65–78% | **第二轮补齐 `contains/starts-with/ends-with/translate/not`**（`_evalFunction` 通用分支，参数经 `_evalValue` 递归求值，天然支持嵌套），11 测试；仍缺：轴选择只处理元素节点（`_asElement` L79）、复杂嵌套路径未穷举 |
| JS 宿主 | 55–70% | jsLib **声明型共享已收敛**（`JsHostBridge.prependJsLib`，8 测试）；仍缺：**超时保护**（需 VM 级 deadline）、**沙箱**、可变全局态跨 eval 持久化 |
| JS 桥 `java.*` | — | `java_host.dart` 1,691 行 vs legado `JsExtensions`：缺 `strToBytes/bytesToStr`（已判定缓做）、`queryTTF/queryBase64TTF/replaceFont`、`unzipFile/un7zFile/unrarFile` 系列、`getVerificationCode` |
| 测试基建 | — | golden corpus **5 → 460 条**（1,811 真实书源分层抽样，`tool/gen_corpus.dart` 可复现）；引擎基准 3 个建成（perf-baseline/2026-09-12）；oracle fixtures 5 个，xpath 侧未扩到 30 条（阶段 1 验收项未完成） |

**结构性短板排序（按「让多少书源整源失败」计；2026-09-12 第二批后更新）**：
1. **字体反爬缺失** —— 有 `replaceFont` 规则的源正文是乱码（原第 3 位上调）。
2. **JS 超时/沙箱缺失** —— 死循环脚本挂死请求；带加密/反爬的源不可用。
3. **webSocket 未落地** —— 少数但整源失败（原 `type` 项已证实为实现正确，移除）。
4. ~~XPath 谓词函数缺失~~（已补齐）~~jsLib 声明缺失~~（已收敛）——**原第 1、2 位已解除**。

---

## 二、架构改进（带证据）

| # | 问题 | 证据 | 改法 |
| --- | --- | --- | --- |
| A1 | **9 个依赖写 `any`**，版本完全失控 | `chloris/pubspec.yaml`：`flutter_js、media_kit、media_kit_video、just_audio、audio_service、share_plus、flutter_local_notifications、mobile_scanner、app_links` | 全部锁到具体版本 |
| A2 | **媒体栈冗余**：`media_kit + just_audio + audio_service + video_player` 四套并存 | 同上 | 音频收敛到 just_audio、视频收敛到 media_kit，砍重复 |
| A3 | ~~**3 处绕过分层**~~ ✅ **已修**（2026-09-12 第二批：LoginCheckUseCase / shelfRepositoryProvider / EngineImageLoader，features 层直引 facade 归零） | 原：`features/sources/source_login_screen.dart:159` 等三处 | 已包 UseCase/Provider；lint 防回潮未加（待办） |
| A4 | ~~**Web 端 drift wasm 资产缺失**~~ ✅ **已修**（真因更深：`driftDatabase()` 缺 `web` 参数，Web 开库即崩） | 原：`chloris/web/` 无 wasm/worker | 已接线 + `sqlite3.wasm`(2.9.4)/`drift_worker.js`(2.31.0) 落位；Web 端运行时验证仍待做 |
| A5 | ~~**原生层空壳**~~ 🟡 **部分完成**（Android 权限+文件关联、iOS 文档类型已补；TTS/后台下载/通知实现仍缺） | 原：Manifest 零权限等 | 剩余见 §1.1 平台行 |
| A6 | 正文等大文本无长度控制地进 `CacheEntries(key,value TEXT)` KV 表 | `app_database.dart` L204–211 | 正文缓存迁独立表或设阈值落文件（对齐 legado 大值落文件的策略） |

---

## 三、速度优化方案（按收益排序）

| # | 问题 | 证据 | 改法 | 预期收益 |
| --- | --- | --- | --- | --- |
| S1 | **菜单开合触发整章重排**：重排缓存 key 含 `_lastMenu` | `reader_layout.dart` L109 | 把菜单状态从排版缓存 key 中剥离 | 阅读中点开菜单不再卡顿（bug 级，最优先） |
| S2 | **长章节双重排**：首帧排 2800 字符 preview，postFrame 全量重排 | `reader_layout.dart` L123–141 | 首帧直接用增量结果；或 preview 阈值提到首屏两页 | 长章节打开耗时减半 |
| S3 | **分页测量全在主 isolate**：逐段 `TextPainter.layout + computeLineMetrics` | `measured_paginator.dart` L65–83 | TextPainter 进不了 isolate；改为**段落测量结果缓存**（段落哈希 → 行框），翻回页/重排命中缓存 | 长章节翻页 P95 显著下降 |
| S4 | **规则编译缓存只接了 1/4** | `rule_cache.dart` LRU 256，仅 `analyze_rule.dart` L482/502/535 三处调用；CSS/XPath/JSONPath 的内联 RegExp 未走缓存 | 把三个后端的 RegExp 构造统一走 `RuleCompileCache` | 搜索扇出 32 并发下 CPU 降载 |
| S5 | **HTML 解析同步阻塞** | `package:html` parse 在主 isolate | 大页面（>256KB）解析放 isolate（传字符串，回传 DOM 序列化结构需评估成本；保守方案：先只对搜索页做） | 搜索期间不掉帧 |
| S6 | **启动串行 await 链** | `main.dart` L71–156：hydratePrefs → 凭据迁移 → KvSettings → 主题 → EngineLimits → initMediaSession 全串行 | 无依赖项并行（`Future.wait`）；凭据迁移/日志持久化懒加载 | 冷启动首帧前移 |
| S7 | **离线首屏 30s 疑团** | 调研未找到「拉默认字体」代码（字体已打包进 pubspec，`app_theme.dart:687`）；真因疑似 `contentTimeoutSec=30` 首章兜底（`main.dart` L115–119） | 先复现定位：离线冷启动抓 timeline，确认是否首章请求兜底；若是，离线状态下直接跳过网络章节加载 | 离线首屏从 ~30s → <2s |
| S8 | `searchEarlyStop*` 已配置无消费点 | `EngineLimits` | 接入 SearchController：命中数达标即提前收尾 | 搜索体感提速 |
| S9 | `Books.lastReadTime/group` 无索引 | `app_database.dart` L38–40 | 书架量大前补索引（低优先） | |
| S10 | **无任何性能基准** | 引擎 test/ 内 grep Benchmark/Stopwatch 零命中 | 建 3 个基准：规则解析吞吐、HTML 解析、整章排版（见阶段 0） | 后续所有优化有度量 |

---

## 四、引擎补全方案

按「让多少书源整源可用」排序，每项**先写失败测试再改实现**（沿用对齐计划的执行原则）。

### E1. XPath 谓词函数补齐（P0）
- 补 `contains / starts-with / ends-with / translate / not`（`analyze_by_xpath.dart` 函数表 L652–702）。
- 重写 `_parseXPathFunctionCall`（L36）：支持嵌套表达式（如 `//a[contains(text(),'x')]` 已可用，但 `substring-after(contains(...))` 类嵌套当前降级为空）。
- 支持文本/属性节点轴（当前 L79 只取 Element）。
- 验收：`tool/legado_oracle` 的 `xpath.json` fixture 从 5 条扩到 ≥30 条，双侧一致率 ≥95%。

### E2. JS 宿主：超时 + 共享作用域（P0）
- **超时**：QuickJS 侧用 deadline 中断执行；浏览器 eval 无法安全中断，标注降级并打 `JsDegradation` 告警。目标：恶意/死循环脚本不再挂死请求。
- **共享作用域**：实现 `SharedJsScope` 对应物——同一书源内跨 eval 持久 `jsLib` 声明的全局态；替代当前「jsonEncode 重注入」与 `java.ajax` 的正则预取（`js_host_bridge.dart` L60–88）。
- 验收：构造一条带 `jsLib` 全局计数器的 fixture，跨三次 eval 状态可传递。

### E3. 请求构造收尾（P1）
- `type` option 透传到 HTTP 层（当前 `UrlOption` L20–91 仅解析）。
- `webSocket` 支持：走现有 `http_port.dart` 的双通道池模式新增 WS 通道。
- 验收：oracle 接不了 OkHttp 垫片（原判定），改用真源定向验证：从 756 源里筛出带 `type:`/WebSocket 的源各 ≥5 个跑通闭环。

### E4. `java.*` 桥分批补齐（P1→P2）
- 第一批（高频、纯字符串）：`base64Encode/Decode`、`hex*`、`encodeURI`、`timeFormat/timeFormatUTC`、`htmlFormat`、`t2s/s2t`（应用层已有简繁转换，下沉引擎）。
- 第二批：`coverDecodeJs` 支持、`loginUi` 自定义表单渲染、`checkKeyWord` 消费进批量校验。
- 第三批（大改动，单列）：`queryTTF/replaceFont` 字体反爬——需要非字符串返回通道（与已缓办的 `strToBytes` 同一基础设施，先建该通道再做）。
- 明确不做：`unzipFile/un7zFile/unrarFile` 文件压缩族（收益低）、Rhino 沙箱类白名单（平台不可能）。

### E5. 测试基建（贯穿）
- golden corpus `test/golden/legado_rule_corpus.json` **从 5 条扩到 ≥200 条**：从 `tool/` 的 756 个已验证书源按 ruleSearch/ruleToc/ruleContent 抽样自动抽取。
- 请求构造层差分（原判定工具不可得）降级方案：改用「真源定向闭环」替代双侧 oracle，纳入 `live_source_loop.dart` 常规回归。

---

## 五、可执行计划

原则：每项有**验收命令/标准**；同一失败三次不同假设仍败 → 记 blocked，不伪装完成。

### 阶段 0 · 基线固化（第 1 周，半天×5）

| 任务 | 产出 | 验收 |
| --- | --- | --- |
| 0.1 锁依赖 | `pubspec.yaml` 9 个 `any` → 具体版本 | `flutter analyze` 无新增告警；`flutter test` 全绿 |
| 0.2 修分层绕过 | §2-A3 三处包 UseCase | `grep -rn "engineFacadeProvider" chloris/lib/features/` 仅剩白名单 |
| 0.3 建 3 个基准 | `packages/chloris_engine/benchmark/`：规则解析、HTML 解析；`chloris/test/`：整章排版 | 输出基线数字，存 `artifacts/verification/perf-baseline/` |
| 0.4 复现 S7 离线首屏 | timeline 报告 | 确认真因（首章超时 vs 其它），写入本文档附录 |
| 0.5 corpus 扩容 | golden 5→200 条 | `dart test` 通过；每条规则标注来源书源 |

### 阶段 1 · 引擎 P0（第 2–3 周）

| 任务 | 对应 | 验收 |
| --- | --- | --- |
| 1.1 XPath 函数补齐 + 嵌套解析 | E1 | oracle xpath fixture ≥30 条、一致率 ≥95%；`dart test` 全绿 |
| 1.2 JS 超时保护 | E2 | 死循环脚本 fixture 在 3s 内被打断且报错可见 |
| 1.3 jsLib 共享作用域 | E2 | 共享状态 fixture 通过 |
| 1.4 `type` 透传 | E3 | 真源定向验证 ≥5 源闭环 |

### 阶段 2 · 性能（第 4 周）

| 任务 | 对应 | 验收 |
| --- | --- | --- |
| 2.1 修 `_lastMenu` 重排 bug | S1 | 基准：菜单开合 0 次重排（加回归测试） |
| 2.2 段落测量缓存 | S3 | 整章排版基准 P95 下降 ≥40% |
| 2.3 RuleCompileCache 接入 CSS/XPath/JSONPath | S4 | 规则解析基准吞吐提升可测 |
| 2.4 启动并行化 + 离线路径修复 | S6/S7 | 离线冷启动首屏 <2s |
| 2.5 `searchEarlyStop` 接入 | S8 | 搜索提前收尾生效 |

### 阶段 3 · 功能对齐（第 5–8 周）

| 任务 | 依赖 | 验收 |
| --- | --- | --- |
| 3.1 书架分组/排序/置顶 | **先决：解决「一书多条目」产品决策**（README 遗留，卡表结构迁移） | 分组 CRUD + 排序持久化 + 测试 |
| 3.2 替换规则作用域字段 | 无 | `scope/scopeTitle/scopeContent/excludeScope` 对齐 legado，双侧 fixture |
| 3.3 TXT 目录规则 | 无 | 3 本不同格式的真实 TXT 目录识别通过 |
| 3.4 TTS（先系统 TTS） | Android 权限 | 前台 Service 朗读、后台不中断 |
| 3.5 Android 原生基线 | 无 | Manifest 补 INTERNET/POST_NOTIFICATIONS；.txt/.epub 文件关联导入；后台下载通道（前台服务） |
| 3.6 Web 端 drift wasm 资产 | 无 | Web 端数据库读写验证脚本通过 |
| 3.7 `queryTTF/replaceFont`（若做） | 需先建非字符串返回通道 | 带字体反爬的真源正文不再乱码 |
| 3.8 媒体栈收敛 + 依赖体检 | 无 | 砍掉一套冗余媒体依赖 |

明确不做（本轮）：段评 `ruleReview`、词典 `DictRule`、`eventListener/customButton`、Rhino 沙箱、DRM、压缩文件族桥接。

### 阶段 4 · 持续机制

- 每两周跑一次 `live_source_loop.dart` 全量 756 源闭环，engine 归因保持为 0，回归即报警。
- oracle fixture 与 corpus 随引擎改动同步增长，只增不减。

---

## 六、风险登记

| 风险 | 缓解 |
| --- | --- |
| 「一书多条目」产品决策悬而不决，卡住 3.1 与表结构迁移 | 阶段 2 期间推动决策，不阻塞其它任务 |
| TextPainter 无法进 isolate，S3 缓存方案收益不确定 | 基准先行（0.3），若缓存命中低则退守 S1/S2 |
| 浏览器侧 JS 无法安全中断 | 明示降级 + 告警，不承诺 Web 端超时 |
| 请求构造层无双侧 oracle | 以真源定向闭环替代，降低判定强度 |
| 依赖锁定可能引出兼容性连锁 | 阶段 0 集中处理，一次锁定不动 |

---

## 七、执行台账（2026-09-12 无人值守批次）

### 已完成

| 项 | 结果 | 关键证据 |
| --- | --- | --- |
| 0.1 锁依赖 | ✅ 9 个 `any` 按 lock 版本改为 caret 约束 | `pub get` 成功、lock 无漂移 |
| 0.2 分层绕过 | ✅ 3 处全部收口（LoginCheckUseCase / shelfRepositoryProvider / EngineImageLoader） | `grep engineFacadeProvider lib/features/` = 0 |
| 0.3 基准 | ✅ 3 个基准建成并跑出基线 | 规则解析 186,886 ops/s；HTML 1MB 13 ops/s；整链 eval 194,811 ops/s（`artifacts/verification/perf-baseline/2026-09-12.md`） |
| 0.5 corpus | ✅ 5 → **460 条**（真实书源分层抽样，1,811 源） | `tool/gen_corpus.dart` 可复现；corpus 测试 ~4s |
| E1 XPath | ✅ 补齐 `contains/starts-with/ends-with/translate/not` + 嵌套参数递归求值 | **更正**：前三个原本有字面量快路径，真正缺的是动态实参与 ends-with/translate；新增 11 测试 |
| E3 type | ✅ 核实+锁定 | **更正**：legado 的 `type` 是二进制下载标记（响应转 hex，AnalyzeUrl.kt:424），引擎已正确实现；补 7 测试锁定语义 |
| E2-半 jsLib | ✅ 最小共享作用域核实+收敛 | **更正**：jsLib 前置注入已存在，本次收口为 `JsHostBridge.prependJsLib` 单一实现 + 8 测试（含多源不串扰）；可变全局态跨 eval 持久化不在范围 |
| S1 重排 bug | ✅ `_lastMenu` 移出排版缓存 key，菜单按浮层处理 | 回归测试断言：菜单开合 key 不变、字号变化 key 变 |
| S4 缓存接入 | ✅ RuleCompileCache 接入 CSS/JSONPath/XPath 三后端 | parity 测试全绿；key 强制 `<backend>:` 前缀防碰撞 |
| S6 启动 | ✅ 互不依赖的初始化并行化；媒体会话移至首帧后 | analyze 无新增问题 |
| S8 早停 | ✅ searchEarlyStopHits 接入：命中阈值停止发起新源、已发请求自然归并；换源保持全量扫描；续搜契约保住 | `SourceFanout.run → Future<bool>`；早停时 `remaining=universe-completed`；纯函数 + 集成测试 |
| 3.2 替换作用域 | ✅ 核实四字段模型/DB 均已在位，补齐执行侧 `excludeScope` 消费（对齐 legado LIKE 语义） | 12 项新测试全绿，含 legado 字段名 JSON round-trip |
| 3.5 平台基线 | ✅ Android main Manifest 补 INTERNET/POST_NOTIFICATIONS（release 此前零权限、联网直接不可用）+ .txt/.epub 文件关联；iOS 补 CFBundleDocumentTypes + LSSupportsOpeningDocumentsInPlace=false | 未加 UIBackgroundModes（防 App Store 打回） |
| 3.6 Web DB | ✅ 发现真 bug：`driftDatabase()` 缺 `web` 参数，Web 端开库即抛 ArgumentError——已接线 + 落资产（sqlite3.wasm 2.9.4 / drift_worker.js 2.31.0，版本对齐 lock） | **README「Web 闭环已跑通」与此矛盾，需要复查 Web 端真实状态** |
| 测试修复 | ✅ 修 2 个既有坏测试（file_port_io 条件导入歧义、web_api 条件导入 stub） | analyze error 清零 |

### 重要更正（对原计划判断的修正）

1. **「30s 字体超时」是过时描述**：全库无字体下载代码，README 已更正；真因首要嫌疑是首章 `contentTimeoutSec=30` 兜底，待运行时复现。
2. **`type` 与 jsLib 前置注入并非缺失**，第一轮静态调研判断有误——本轮以 legado 源码为基准核实并补测试锁定。
3. **Web 端数据库从未接线**，README 的「Web 端完整闭环」声明需要重新验证。

### 跳过（含原因）

| 项 | 原因 |
| --- | --- |
| E2-半 JS 超时保护 | 引擎不持有 VM（App 注入 QuickJS/eval），同步 eval 无法在引擎侧安全中断；需 VM 级 deadline（App 侧）或 isolate 化（平台插件不可跨 isolate），属跨界改造 |
| jsLib 可变全局态持久化 | 需重构求值会话生命周期（引擎不持有持久全局对象）；声明型共享已实现，可变态单列 |
| S2/S3 分页测量优化 | TextPainter 不可进 isolate；测量缓存收益未证实，基准已建，待基线对比后再动 |
| 0.4/S7 离线首屏复现 | 需真实运行 Web/离线环境复现 timeline，沙箱内 flutter_tester 无法启动，无法执行 |
| 3.1 书架分组/排序/置顶 | 卡「一书多条目」产品决策（README 遗留问题）+ 大型功能 |
| 3.3 TXT 目录规则 / 3.4 TTS / 3.7 queryTTF | 大型功能/原生能力/需非字符串通道，单列排期 |
| 3.8 媒体栈收敛 | 运行时行为无法在沙箱验证，不宜无人值守改动 |
| S9 Books 索引 | 需 bump schemaVersion + 迁移，收益低风险高，暂缓 |

### 环境限制（影响验收强度，不影响代码正确性）

- `flutter test` 在本沙箱全部失败于 **flutter_tester 启动阶段**（WebSocket 握手失败，加载期即中断，先于任何测试代码运行）——属环境拦截，非代码问题。新写的 app 侧测试（reader_layout_cache_test、search_early_stop_test 等）已入套件，在有可用环境的机器/CI 上跑一次即可。
- 引擎侧 `dart test` 可正常运行，**423 项全绿**；app 侧验收以 `flutter analyze`（254→251，error 清零）+ 纯 Dart 独立脚本实跑替代。

---

## 八、执行台账（第三批：五域功能补齐）

> 对应用户指令「书架、搜索、仿真翻页、本地书、书源全还原」= 按 legado-E 补齐五域缺口。
> 产品决策落定：书架**按身份去重**（DB schema 注释早已如此设计）。

| 域 | 结果 | 说明 |
| --- | --- | --- |
| 书架·分组 | ✅ | 分组定义+成员位掩码 KV 持久化（`bookGroupsProvider`/`bookGroupMapProvider`，与置顶同模式，本地+在线书统一）；工具栏「分组」筛选（成员/未分组）、长按「归属分组/新建分组并加入」弹层（Consumer 实时刷新）；`books.group` DB 列保留待迁移定稿后并入 |
| 书架·排序/置顶 | ✅（核实已存在） | 排序菜单、置顶入口+置顶优先排序、批量删除均有，此前对照表判断有误 |
| 搜索·checkKeyWord | ✅ | 引擎 `BookSource.getCheckKeyword`（对齐 BookSource.kt:212-220）+ 调试页默认词消费；3 测试 |
| 阅读·仿真翻页 | ✅ | `ReadPagerStyle.simulation` + `page_curl_layout.dart` 纯 Dart 几何（curlForward/curlBackward），纸背渐变+折缝高光+软阴影层叠；`PageAnim.simulation` 不再折叠为覆盖、设置面板出现「仿真」；13 项几何不变式独立脚本验证 |
| 本地书·TxtTocRule | ✅ | `_pickRule` 对齐 legado 评分（间隔 >1000 字计正样本、<100 字计误报、csNum≥numE×3、>70 章提前收敛）；前言章节不再丢弃；`replacement` 标题净化 JS（result/index/prevTitle/prevLength 绑定，失败保留原标题）；tocUrl 保存 rule+joiner+replacement 往返；8 测试；旧测试「TXT splits by heading regex」按 legado 语义修正数据（短章节本应被否决） |
| 书源·coverDecodeJs | ✅（更正） | 核实 `_decodeCover` 已实现，对照表原判断有误 |
| 书源·weight/exploreScreen | ➖（更正） | legado 自身无消费点，不构成缺口；字段已解析备用 |

**重要更正（第三批）**：对照表中「书架排序/置顶缺失」「coverDecodeJs 缺失」「weight/exploreScreen 缺失」三项均为静态调研误判，已核实修正。

验收：引擎 `dart test` **423 → 431 项全绿**；`flutter analyze` error 0（253 issues，含预存 deprecated/interpolation infos）；卷页几何 13 项不变式独立脚本通过。

---

## 九、换行消失问题（用户复查反馈，2026-09-12 晚）

> 用户报「换行消失问题未解决」。根因不在排版层（段落间距此前已修），而在**内容提取层**。

**根因**：`@text` 提取走 package:html 的 `Element.text`——它只拼接文本节点，`<br>` 是元素节点会被**直接吞掉**。多数站点正文靠 `<br>` 分行，于是多行正文在引擎提取阶段就压成了一行，后面排版层无从恢复。`@ownText` 同理。

**修复**（`analyze_by_css.dart`）：
- `_text`：递归拼接文本节点时把 `<br>` 记为 `'\n'`；
- `ownText` 分支：直接子节点遍历中 `<br>` 同样记 `'\n'`。

覆盖面：显式 `@text` 规则、无后缀默认提取（`_single(...).map(_text)`）、引擎兜底规则组 `_ruleFallbackContent`（全部是 `@text` 形态）均自动受益；`@html` 路径与 `_fallbackContent` 原本就经 `htmlToPlain`/`htmlFormat` 转换，不受影响。

验收：新增回归测试「@text preserves <br> as newline」；引擎全量 **432 项全绿**；`dart analyze` error/warning 0；Web release 已重建（修复需重建后才在 Web 端生效——上一轮「未解决」的体感很可能来自只改了源码、未重建部署）。

---

## 十、自动换源（2026-09-12 晚）

> 用户需求：「点开发现源空自动换源」——点开书发现当前源是空的（目录为空）时，自动换到有内容的源。

- **无头换源** `lib/features/book_detail/auto_source_switch.dart`：复用换源面板的同款打分（`searchMatchScore`/精确阈值 300/800）与来源（seed 的 origin 记录、`SearchHitCache`、`SourceFanout` 全源搜索）；对打分 top-5 候选**逐个实取目录验证（≥2 章）才采纳**——搜索命中只代表搜到了同名书，不代表源还活着，而这正是触发自动换源的原因。
- **触发与切换**：详情页目录加载完成且为空 → 触发一次（每实例一次，防循环）；切换复用 `_applySourceSwitch`（失效缓存、更新书架条目、刷新详情），全程 SnackBar 提示「正在寻找其它源… / 已自动换源 → X / 没有找到可用的其它源」。
- 验收：`flutter analyze` 0 error；新文件 0 issue；Web release 已重建。
- 后续（未做）：阅读中正文为空的自动换源——需要跨源保留阅读进度（章节标题对齐），改动面大，单列。
