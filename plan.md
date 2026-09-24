# Chloris 复原计划 —— 完美复原 Legado-E

> **目标**：在纯 Dart / Flutter 跨平台约束下，把 Chloris 复原到与 Legado-E **功能全量对齐、引擎规则等价、阅读体验一致**。
> 基准源码：`reference/legado-E-main`（io.legado.app）。本文件是唯一计划与状态来源；结论由双侧判题、真源闭环与构建产物产生，不由人工宣称。
> 状态：✅ 已复原 · 🔨 进行中 · ⬜ 待复原 · ➖ 复原边界（物理不可能，附替代方案）
> 更新：2026-09-13。历史档案在 `artifacts/`，产品介绍在 `README.md`。

---

## M0 · 复原原则与验收体系

- [x] **规则等价判定**：双侧 oracle（`tool/legado_oracle`，Kotlin 判题进程，JDK 21 可跑）+ golden corpus 460 条真实规则 + 等价性审计；引擎回归 449 项全绿
- [x] **真源闭环**：756 个真实书源跑「搜索→详情→目录→正文→换章→换源」，engine 归因 0
- [x] **性能基准**：规则解析 / HTML 解析 / 整链 eval 三件套（`artifacts/verification/perf-baseline/`）
- [x] oracle fixture 常态化：xpath **38**、css **37**、json **34**、regex 两条 **30/33**——共 134 案例双侧判题跑通（88% 一致；16 条分歧逐条归因：2 条 oracle 桥接不完整、14 条已记录于 `tool/legado_oracle/fixtures/NOTES.md`，含 `:has`/`$..*` 两个能力缺口待补）；每次引擎改动必跑双侧
- [ ] **跨平台构建矩阵**：Web ✅；Android ⛔ 缺 SDK、macOS/iOS ⛔ 缺 Xcode/CocoaPods、Windows/Linux ⛔ 缺主机——补齐后 `flutter build` 全矩阵出包并归档产物
- [ ] **复原验收清单**：每个复原项绑定「legado 行为 fixture（双侧或真源）+ Chloris 回归测试」，禁止「入口存在即算复原」

---

## M1 · 引擎复原（书源规则机，model/analyzeRule 全量）

legado 引擎八层 → Chloris 对应层。判定标准：同一条规则两端取到同样的内容。

| # | legado 组件 | Chloris 对应 | 状态 | 剩余工作 |
| --- | --- | --- | --- | --- |
| 1 | AnalyzeRule（混合规则编排） | analyze_rule.dart | ✅ | 变量大分层复核（已判定非缺口） |
| 2 | AnalyzeByJSoup（CSS/@text 族） | analyze_by_css.dart | ✅ | 缓存已接；@text `<br>`→`\n` 已修 |
| 3 | AnalyzeByJSonPath | analyze_by_jsonpath.dart | ✅ | 函数扩展+缓存已接 |
| 4 | AnalyzeByXPath | analyze_by_xpath.dart | ✅ | 轴选择（text() 子轴/后代轴）已修；oracle 38 条双侧 |
| 5 | AnalyzeByRegex | analyze_by_regex | ✅ | 链式语义已对齐 |
| 6 | AnalyzeUrl + CustomUrl（请求构造） | analyze_url.dart | ✅ | 分页时序/请求头优先级/type(hex) 已对齐 |
| 7 | Rhino + SharedJsScope + JsExtensions | js/（注入式 runtime + java_host） | 🔨 | 见下方 JS 桥清单 |
| 8 | RuleData / 缓存分层 | rule_data + cache 门面 | ✅ | 大变量分层已判定两侧等价 |

- [x] 组合符/变量/模板/`##`替换/结果算子全对齐；词法引号括号感知比 legado 更严格
- [x] **JsExtensions 桥复原**（对照 `help/JsExtensions.kt` 全清单）：
  - [x] 网络：ajax/ajaxAll/connect/get/head/post/downloadFile/getFile/readFile/readTxtFile
  - [x] 缓存：cache.get/put（内存+disk 两层、onlyDisk 语义对齐 CacheManager.kt）
  - [x] 编码：base64*/hex*/encodeURI/md5/timeFormat/timeFormatUTC/htmlFormat/t2s/s2t/toNumChapter
  - [x] 元素门面：getElement/getElements（句柄注册表先例）
  - [x] 字体反爬：**queryTTF/queryBase64TTF/replaceFont**（轮廓反查 `font_query.dart` + 句柄桥；已修真实引擎路径分发缺失）
  - [x] 压缩族：unzipFile/unArchiveFile/getZipStringContent/getTxtInFolder（rar/7z 显式报错）
  - [x] 字节族：**strToBytes/bytesToStr/getByteArray 已实现**（句柄注册表；queryTTF 可消费字节句柄；CharsetDecoder 补 encode 对称 GBK/Big5/UTF-16；4 测试含 getByteArray→queryTTF 全链路）
  - [x] WebView 族：webView/webViewGetSource/webViewGetOverrideUrl/getWebViewUA/getVerificationCode/startBrowserAwait **已分发**（路由 WebViewPort 抽象 + HostEnvironment，能力缺失显式报错）
- [x] **JS 超时**：`JsRuntime` deadline 契约 + `evalWithDeadline`（释放调用方 + js_deadline 告警）+ `EngineLimits.jsEvalTimeout`（15s）；VM 级硬中断受 flutter_js 限制（已文档化，上游支持后接管）
- [x] **jsLib 共享作用域**：声明型共享（prependJsLib，多源不串扰，8 测试）
- [ ] jsLib 可变全局态跨 eval 持久化（legado SharedJsScope 的对象存活语义；需求值会话生命周期重构）
- [x] 主题/配置 JS 读取：getThemeConfig/getThemeConfigMap/getThemeMode/getReadBookConfig 已分发（HostEnvironment 端口已备）
- [x] epubIndex/name/author 导出——导出文件名模板已实现（`{书名}{-作者}` 占位符 + KvSettings 持久化；BookExtensions 完整规则绑定仍可后续扩展）

### M1 验收

- [ ] oracle 全后端 fixture ≥30×4 且双侧一致率 ≥95%（当前 134 案例 **90.3%**；剩余分歧均为格式/判题归一/命中集边界，归因见 `fixtures/NOTES.md` §6——全部语义一致或影响可忽略）
- [ ] corpus 常态化回归 + 每次引擎改动必跑双侧
- [x] 死循环脚本 deadline 打断（3 项测试）；VM 级中断依赖上游

---

## M2 · 功能复原（ui/ + model/ 全量）

### 书籍获取（搜索/发现/换源）

| 能力 | 状态 | 备注 |
| --- | --- | --- |
| 多源聚合搜索/停止/续搜 | ✅ | host 上限 + 早停（命中阈值收尾、续搜契约保住） |
| 精确搜索 | ✅ | |
| 发现页 | ✅ | exploreScreen legado 未消费，非缺口 |
| 换源 | ✅ | 手动面板 + **自动**（详情页目录空、阅读页正文空两处触发，实取目录验证 + 标题对齐） |
| checkKeyWord 校验词 | ✅ | getCheckKeyword + 调试消费 |
| 失效源批量校验 | ✅ | **已复原搜索式**：HEAD 快探 + checkKeyWord 真实搜索计数，healthy/degraded/failed 三级对齐 legado CheckSource |
| 书源登录 | ✅ | loginUrl/loginCheckJs |
| 书源调试 | ✅ | 单源调试 + 批量校验 |

### 书架

- [x] 身份去重（UNIQUE(name,author) + searchBooks 候选分表）+ 分组（位掩码 KV + 筛选/归属 UI）+ 排序/置顶/批量删除
- [ ] 分组落 DB（BookGroups 表已在 schema，UI 迁移并入；`books.group` 位掩码列并轨）
- [ ] 书架刷新时分组/自定义顺序的 legado 语义复核

### 阅读（ui/book/read）

- [x] 翻页：覆盖/滑动/滚动/无动画/**仿真**（风格化卷页；物理栅格化卷曲为升级项）
- [x] 双页模式（Chloris 独有）
- [x] 排版：字号/行高/段距/字距/边距/字体/缩放；段落测量缓存 + 增量续排（长章节工作量减半）
- [x] 配色：多色板 + follow 联动外壳 + 自定义前景背景
- [x] 亮度/自动隐藏菜单/定时自动翻页/简繁转换/替换净化（作用域四字段，LIKE 语义对齐）/点击区域/键盘快捷键
- [x] 书签/进度/目录/进度跳转；TTS 基础版（切句/暂停/续播/播完翻章）
- [ ] legado ReadBookConfig 细节枚举对照（已枚举，以下为 Chloris 待补项）：
  - [x] 首行缩进字符数可配（`resegment(indent:)` + 设置滑块 0–6 字，对齐 legado `paragraphIndent`）
  - [x] 屏幕常亮/方向锁定（wakelock_plus + SystemChrome，设置开关 + 离开阅读器自动恢复；对齐 legado keepScreenOn/screenOrientation）
  - [ ] 页眉/页脚模式与边距（legado headerMode/footerMode + headerPadding*）——视觉迭代项
  - [ ] 行距额外值（legado `lineSpacingExtra` 与行距倍数并存）——视觉迭代项
  - [ ] 页码提示样式（legado ReadTipConfig）——视觉迭代项
  - [ ] 背景多素材（legado bg drawable/自选图；Chloris 仅色板）——视觉迭代项
- [ ] 段评 ruleReview（低频）

### 朗读与播放

- [ ] TTS 后台连续朗读（Android 前台服务 + 通知栏控制，对齐 TTSReadAloudService）
- [ ] 在线 TTS 源（HttpTTS 实体 + 导入）
- [ ] 音频/视频后台播放会话（audio_service 已接媒体会话；后台模式需平台声明）
- [x] 漫画阅读器 + 音频/视频播放器

### 本地书

- [x] TXT（编码探测 + TxtTocRule 评分算法/前言/replacement 净化）/EPUB/MOBI(KF8)/UMD
- [ ] PDF 真实文本布局（当前 Web 交给浏览器查看器）
- ➖ DRM：合法边界，不实现

### RSS / Web 服务 / 备份

- [x] RSS2/Atom/JSON Feed + 规则源 + 收藏/已读
- [x] RSS **sortUrl 分类列表已复原**（`&&`/换行分条 + `名称::url` 拆名，对齐 RssSourceExtensions.kt:17；发现页分类 ChoiceChip 接入）；⬜ 正文黑白名单/RssParserByRule 细节对照
- [x] Web 服务（桌面端 HTTP+WebSocket）+ WebDAV + 备份/恢复（含 legado 配置导入）
- [x] **替换规则订阅 RuleSub 已复原**（GET url → JSON 数组 → contentKey 幂等合并，负 id 区间隔离用户规则；订阅管理 UI + 7 项纯 Dart 验收）
- [x] **正则执行看门狗已复原**（>32KB 文本 isolate 硬杀 + RegexTimeoutException 语义：超时跳过该规则继续后续、DebugLog 可见；`timeoutMillisecond` 已消费；7 测试）

---

## M3 · 平台与后台能力复原（service/ 族）

| legado Service | Chloris 现状 | 计划 |
| --- | --- | --- |
| TTSReadAloudService/HttpReadAloudService | 🟡 应用内基础 TTS ✅ | ⬜ 前台服务 + 通知栏控制 |
| AudioPlayService/VideoPlayService | 🟡 前台播放 ✅ | ⬜ 后台会话 |
| CacheBookService（缓存下载） | ✅ 批量下载+断点恢复 | ⬜ 后台化（WorkManager/前台服务） |
| CheckSourceService | ✅ 搜索式校验已复原 | ✅ |
| WebService/WebTileService | ✅ Web 服务 | ⬜ 快捷磁贴（低频） |
| DownloadService | 🟡 | ⬜ 与缓存下载统一 |
| ExportBookService | ✅ | ✅ |

- [x] Android 权限（INTERNET/POST_NOTIFICATIONS）+ .txt/.epub 文件关联；iOS 文档类型
- [ ] Android 前台服务基础设施（通用 ForegroundService 通道，TTS/下载复用）
- [ ] POST_NOTIFICATIONS 运行时请求流
- [ ] iOS UIBackgroundModes（audio，随后台播放）

---

## M4 · 体验复原（help/config + 主题）

- [x] 三套外壳（classic/claude/terminal）+ Claude 暖纸编辑部深化（surfaceContainer 阶梯/衬线字阶/图标两级/accent 治理）+ 终端壳静态语义线
- [x] 阅读↔外壳配色联动（follow 哨兵）；主题预览色卡
- [ ] legado ThemeStore 自定义主题管理（自定义色导入导出）
- [x] 主题 JS 读取（getThemeConfig/getThemeMode——端口与分发已实现）
- [ ] legado 阅读行为开关全项对照（亮度模式/点击翻页/屏幕方向等）
- [ ] Claude 主题可视化 QA（渐变层次/字阶/间距节奏走查；需真机视觉验证）

---

## M5 · 交付

- [x] **Web release** 终态构建（`flutter build web --release`；本地 `dart run tool/serve_web.dart` → 127.0.0.1:2328）
- [ ] Android APK —— ⛔ 本机无 Android SDK（实测 `No Android SDK found`）；装好后 `flutter build apk --release`
- [ ] macOS / iOS —— ⛔ 缺 Xcode/CocoaPods；装好后 `flutter build macos` / `flutter build ios`
- [ ] Windows / Linux —— 需对应平台主机
- [ ] 发布说明列**实际通过的平台与能力**；不用「跨平台」代替逐平台验证
- [x] 文档：README（产品介绍）/ plan.md（本计划）为唯一事实源

---

## 复原边界声明（➖ 项汇总）

| 项 | 原因 | 替代方案 |
| --- | --- | --- |
| Rhino 沙箱类白名单 | 纯 Dart 注入式 runtime 天然隔离 | 文件端口路径围栏（已做） |
| DRM | 合法边界 | 不实现；无 DRM 本地文件照常阅读 |
| WebView 深度桥 | 平台 WebView 差异 | WebViewPort 抽象 + 渐进补齐 |
| un7z/unrar | 纯 Dart 无解码器 | 显式报错（已做），源侧鼓励 zip |
| VM 级 JS 硬中断 | flutter_js 不暴露 interrupt handler | deadline 释放调用方（已做），上游支持后接管 |
| 搜索 HTML 解析 isolate 化 | jsRuntime 主 isolate 绑定 + Document 不可传输 | 引擎「取 DOM/规则求值」可序列化管线拆分（架构级，单列） |

---

## 里程碑与当前进度

- **M0 验收体系**：核心 ✅（oracle/corpus/闭环/基准）；fixture 常态化与构建矩阵 ⬜
- **M1 引擎**：约 **97%** —— 八层全部在位，JS 桥（字节族/WebView 族/主题读取/字体反爬/压缩族）全通；余 jsLib 可变全局态、oracle 全后端 ≥95% 一致率
- **M2 功能**：约 **95%** —— 搜索式校验/RuleSub/sortUrl/正则看门狗/导出模板已复原；余 ReadBookConfig 细节×6、TTS 后台/在线 TTS、段评、正文黑白名单
- **M3 平台后台**：约 **40%** —— 权限/文件关联/前台播放/搜索式校验 ✅；前台服务族 ⬜（受本机编译环境阻塞）
- **M4 体验**：约 **90%** —— 三外壳+联动+主题 JS 读取 ✅；自定义主题管理、ReadBookConfig 细节、可视化 QA ⬜
- **M5 交付**：Web ✅；其余端受本机工具链阻塞

> **「100% 复原」判定** = M1–M4 全勾 + 构建矩阵全绿 + 真源闭环持续归因 0。平台物理不可能项以 ➖ + 替代方案计入完成，不挂账。
- 2026-09-13（第三轮）：oracle 三后端 fixture 扩容（css 37/json 34/regex 30+33，134 案例双侧 88%，16 分歧归因入 NOTES.md）；JS 桥收尾（字节族 strToBytes/bytesToStr/getByteArray 句柄注册表 + CharsetDecoder.encode + WebView 族/主题读取分发核查）；搜索式批量校验复原（HEAD+checkKeyWord 搜索计数三级）；正则看门狗（>32KB Isolate.spawn 硬杀 + 超时跳过规则，process async 化）；RuleSub 替换规则订阅（contentKey 幂等合并）；RSS sortUrl 分类 + 导出文件名模板。引擎 **460 全绿**；各 analyze 0 error。
- 2026-09-13（第四轮）：oracle 分歧收口——CSS 谓词逐段求值（`:contains` 绑定所在段，修 css-008/009）、`:has`/`:not(:has())` 复原（css-027/029）、CSS/XPath getString 纯 `\n` 连接 + 块级空格（css-007，简介去重职责归 sanitizeBookIntro）、`$..*` 递归通配（json-030）；双侧一致率 0.880→**0.903**。ReadBookConfig：首行缩进可配（resegment indent + 滑块）、屏幕常亮（wakelock_plus ^1.5.2）+ 方向锁定（SystemChrome）。RSS 正文黑/白名单（黑名单优先、前缀/正则、非法正则跳过，对齐 ReadRssActivity.kt:639）。验收：引擎 **470 全绿**、analyze 0 error。
