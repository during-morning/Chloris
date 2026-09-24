# Chloris 核心引擎等价性审计

日期：2026-09-06  
基准：`reference/legado-E-main` 静态实现 + Chloris 固定 fixture

## 结论

Chloris 已形成 `Presentation -> UseCase -> OnlineBookPort -> WebBook/AnalyzeRule -> Adapter` 的可运行闭环。搜索、详情、目录、正文下载和提取共用同一规则执行器，错误按 `DomainErrorStage` 传递；本地 TXT/EPUB/MOBI/KF8/PDF 已由 `CanonicalDocument` 统一入口承载。

当前不能宣称 Legado-E 全功能 100% 等价。满足“公开书源规则、无 DRM、标准 HTML/PDF、网络响应相同”时，搜索扇出、目录提取、正文分页和本地导入的主路径达到理论语义等价；以下差异仍会破坏严格等价：

| 区域 | 当前估计 | Chloris 现状 | Legado-E 对照 | 影响 |
| --- | ---: | --- | --- | --- |
| 规则 lexer | 70%–80% | `RuleCompiler` 生成 `RuleProgram`，已 quote/bracket-aware | Android 版本是平衡组/上下文 lexer | Dart 侧组合符已覆盖，仍需跨宿主对照 |
| 替换 | 90%–95% | selector makeup 后保留 `##match##replace` | `SourceRule` 保留完整替换段 | 主路径已对齐 |
| JS | 55%–65% | Dart lenient runtime + Web `eval`/桥接 | Rhino/Android Java 宿主 | 扩展函数、异常和时序不同 |
| CSS/XPath/JSONPath | 70%–80% | 主流查询和组合符已覆盖 | Jsoup/JXDocument/JsonPath | 极端选择器/节点类型仍有差异 |
| 搜索 | 80%–90% | 全量源扇出，失败可见 | Kotlin coroutine flow + DAO | 缓存/排序持久化行为不同 |
| 目录/正文 | 75%–85% | fallback、净化、URL 身份和分页已统一 | `BookContent` 逐页直到结束 | 登录墙和站点私有脚本需逐源校验 |
| RSS/备份/WebDAV | 75%–85% | RSS、备份和 WebDAV 均由 UseCase 调度 Port/Adapter | Legado 对应仓储、同步和规则服务 | 页面已解耦；设置持久化与后台同步仍需扩展 |
| 本地 MOBI/KF8 | 55%–65% | PalmDOC/HUFF-CDIC、EXTH、pagebreak/headings | 完整 skeleton/fragment/resource reader | 复杂 KF8 版式和资源仍不完整 |
| PDF | 45%–55% | header、Info、页数、未压缩及 Flate 内容流文本；浏览器 iframe 渲染 | 原生 PDF/文本布局 | LZW/ASCII85/混合过滤器、ToUnicode、outline 目标和字体布局不同 |
| 下载/缓存 | 70%–80% | 并发、重试、host cap、blob 写入、任务元数据和重启读取 | 后台服务、可暂停恢复、数据库状态 | 自动恢复执行器和完整任务事件流仍需补齐 |

## 空章因果链

最常见的空章路径是：章节规则命中导航/广告 → 章节 URL 被错误保存 → 正文请求得到登录页/验证码 → selector 结果为空 → 旧实现用“短于 24 字即 fallback”覆盖合法短正文 → 空字符串写入 UI/缓存。还存在 URL 身份不一致（`bookUrl`、`tocUrl`、`chapter.url`）导致请求错页的情况。此前 `nextContentUrl` 续页失败会被吞掉并返回半章，本轮已改为向上抛出内容阶段 `DomainError`。

本轮已移除短正文阈值，续页默认上限提升为 32 并在链接结束或重复时停止；续页失败不再写入成功缓存；`ContentEmptyException` 保留正文阶段、章节和可恢复建议；搜索/目录错误不再伪装为空列表。固定复现见 `test/equivalence_audit_test.dart`。

## 可重复验证

- `dart test test/rule_golden_corpus_test.dart test/equivalence_audit_test.dart`：10 项通过。
- `dart test test/json_path_edge_test.dart`：3 项通过；`%%` 已对齐 Legado 的首列表长度语义。
- `flutter test test/persist/chapter_text_cache_test.dart test/local/local_book_test.dart`：7 项通过，包含 blob 重启读取回归。
- `flutter test` 全套：95 项通过（`--no-track-widget-creation --concurrency=1`）；本地格式/导出针对性套件 9 项通过；新增 RSS/备份/WebDAV/批量下载端口隔离以及取消后继续扫描只提交未尝试源的回归。
- `dart analyze lib test`：0 error，35 条既有 warning/info（分析器进程以非零码退出仅因为 lint/info）。
- `flutter analyze --no-pub`：0 error，237 条既有 lint/info/warning。
- `flutter build web --release --no-wasm-dry-run`：构建通过（本次构建约 62.5s）。
- 全引擎测试：141 项通过；新增双记录 KF8 直读 HTML flow、未压缩与 Flate 压缩 PDF 页面文本回归；`rate_limiter` 空规格时间阈值在并发负载下曾抖动，单测重跑通过。
- 架构静态检查：`chloris/lib/features` 页面不再直接引用 `EngineFacade`、`HttpSession`、`BackupService` 或 `WebDavClient`；RSS、源调试、批量下载、备份和 WebDAV 均通过 UseCase/Port provider 装配，原始输出见 `architecture-check.log`。
- Safari 最终回归：同源代理搜索 148/756、1498 命中；目录超时后重试恢复 2 章；下一章正文提取成功。新构建复测另一路结果加载 79 章并进入阅读器，页面可见；真实源仍可能返回合成 `data` 或混入导航，详见 `artifacts/verification/20260906-unattended-p1/safari-test.log`。

## 后续达到严格等价所需工作

1. 将 `RuleProgram` 扩展为完整平衡组 lexer，并为 Android Rhino 与 Dart/Web JS 建立同一 golden 输入输出集。
2. 引入真实 KF8 skeleton/fragment、字体、图片资源，以及 LZW/ASCII85/混合过滤器 PDF、ToUnicode、outline 目标和字体布局 fixture。
3. 为下载任务补齐自动恢复执行器和完整任务事件流（章节级 blob 重启读取已完成），并逐源校准短目录/导航污染规则。
4. 把剩余设置状态 provider 收敛到持久化端口，并继续校准 RSS、备份和 WebDAV 的后台同步行为。
