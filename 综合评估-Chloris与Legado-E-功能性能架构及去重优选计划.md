# Chloris 与 Legado-E 功能、性能、架构及去重优选计划

> 版本：v2.2
> 评估日期：2026-09-26
> 评估对象：`chloris/`、`packages/chloris_engine/`，以及仓库内对 `reference/legado-E-main` 的架构和运行时对照资料。
> 评估原则：以当前代码、数据库 schema、可运行验证产物为准；历史计划中的“已完成”只有在当前代码和验证结果同时支持时才计入完成项。
> 文档状态：执行基线。阶段完成后应回填提交号、验证命令、设备和结果，不用历史数字代替当前证据。

## 1. 执行摘要

Chloris 的规则引擎已经进入“主流书源可用、需要持续兼容回归”的阶段。CSS、JSONPath、XPath、规则编译缓存、分页模板、请求头和 Cookie 优先级、`checkKeyWord`、TXT 目录规则、替换作用域、搜索早停、自动换源目录验证等能力已有实现或测试证据。

当前代码收口后的主要风险集中在运行时证据和平台差异：

1. **身份、候选和缓存模型已完成代码收口。** `SearchBooks` 使用来源复合主键，书架写入走事务，搜索/换源统一使用稳定 context；剩余工作是带 Flutter/Dart SDK 的迁移和真实设备回归。
2. **搜索早停与换源优选已统一。** 早停按唯一身份计数，自动换源和换源面板共同使用 `SourceSwitchService`，并在切换前完成目录与正文探针。
3. **Web 契约已补齐主要获取路由。** 发现、详情、目录、正文和 capability flags 已有代码路径；真实 Web 闭环、浏览器 JS 降级和登录会话仍需设备验证。
4. **Legado-E 的平台差距仍然存在。** 主要包括 JS VM 级硬中断、可变 `jsLib` 的完整会话持久化、部分登录 UI、TTS、后台下载通知和低频事件能力。

### 1.1 总体决策

按以下顺序实施：

> **身份与候选正确性 → 缓存上下文统一 → 可解释优选和验证 → 性能与存储 → Web/平台能力 → 低频兼容项**

在身份、候选和缓存模型稳定前，不继续堆叠新的规则函数。源选错、候选丢失、缓存污染会直接造成用户无法阅读，优先级高于低频字段兼容。

### 1.2 目标结果

完成本计划后，应达到以下状态：

- 一本书只有一个稳定的 `BookIdentity`，但可以保留任意多个 `BookCandidate`。
- 搜索、加入书架、换源面板、自动换源使用同一套身份判定、评分、验证和缓存 key。
- 任一候选被选择时，都能显示可回放的评分理由和验证证据。
- 目录为空、正文为空、登录失败、验证码、规则解析失败和网络失败能被区分。
- Web、Android、桌面分别声明已支持、降级和不支持的能力。
- 性能指标按设备、书源、网络和页面大小记录 P50/P95，不用单个平均值代表体验。
- 数据库迁移可重复、可回滚，旧 `onlineShelf`、搜索缓存和阅读进度可恢复。

## 2. 当前状态与证据校正

### 2.1 已具备并应保留

| 领域 | 当前状态 | 证据/代码位置 | 后续动作 |
|---|---|---|---|
| 规则引擎 | 已覆盖大量主流 CSS、JSONPath、XPath 和 Legado 规则 | `packages/chloris_engine/`、规则 corpus 和 parity 测试 | 以真实书源回归为主，不重复造轮子 |
| 搜索扇出 | 有 host 级并发上限、取消、续搜、命中缓存、响应时间记录 | `chloris/lib/core/search/source_fanout.dart` | 修正唯一身份计数和错误统计 |
| 搜索缓存 | `SearchHitCache` 支持 query、page、source、context | `chloris/lib/core/search/search_schedule.dart` | 所有读取路径必须传相同 context |
| 书架分表 | `Books` 与 `SearchBooks` 已分离，支持从旧 `onlineShelf` 导入 | `app_database.dart`、`shelf_repository.dart` | 增加稳定 identity key 和候选复合主键 |
| 自动换源 | 会搜索其他源并实取目录，至少两章后接受 | `auto_source_switch.dart` | 接入统一 `SourceSwitchService`，补正文验证和进度映射 |
| 服务端搜索 | 服务端已有按 `sourceUrl/query/page` 搜索路由 | `app_server_backend.dart`、`api_contract.dart` | 补发现、详情、会话和能力矩阵 |
| Web 阅读 | Web 端可通过服务端请求目录和正文 | `http_online_book_port.dart` | 明确能力边界，补 API 版本和错误契约 |
| 数据库 | schema version 当前为 7，章节、书签、阅读记录、缓存和书架候选表已纳入迁移 | `app_database.dart` | 对照现行 schema 更新迁移验收；按数据模型计划继续评估 v8 |

### 2.2 已确认的问题

| 编号 | 问题 | 现状 | 影响 | 优先级 |
|---|---|---|---|---|
| D1 | 候选主键过窄 | 已改为 `(bookUrl, origin)` 复合主键 | 已消除跨源覆盖 | 已完成 |
| D2 | 身份规范化不足 | repository 与 provider 共用规范化 identityKey | 已补齐身份去重路径 | 已完成 |
| D3 | 缓存读取不统一 | 所有业务入口使用 `SearchCacheKey` 封装 | context 变化会隔离旧候选 | 已完成 |
| D4 | 早停指标不正确 | `SourceFanout` 按唯一身份集合计数 | 重复命中不再耗尽阈值 | 已完成 |
| D5 | 两套换源逻辑 | 自动换源与面板共同使用 `SourceSwitchService` | 评分、验证和选择可回放 | 已完成 |
| D6 | 写入缺少完整事务边界 | identity、candidate 和 source 写入纳入事务 | 中断不会留下半个身份 | 已完成 |
| D7 | Web 能力不完整 | 已增加发现、详情和 capability/error 契约 | 真实 Web 闭环待设备验证 | 代码完成 |
| D8 | JS 中断和隔离不足 | 已有 deadline 提示、浏览器降级和错误码 | VM 硬中断仍受平台限制 | 部分完成 |
| D9 | 正文持久化层次不清 | 章节正文和目录使用 BlobStore，KV 只保留索引 | 避免大正文进入设置存储 | 已完成 |
| D10 | 评分证据不足 | 统一服务记录分数、理由、目录/正文验证等级 | 空源不会直接被采纳 | 已完成 |
| D11 | 平台能力缺失 | 字体查询、通知、登录字段和降级契约已接入 | TTS/后台能力需逐平台实测 | 部分完成 |
| D12 | 验证数字不统一 | 本文档增加同批次执行记录和证据引用 | 避免跨批次数字混用 | 已完成 |

### 2.3 当前实现中的两个容易误读点

- `SearchBooks` 现在使用 `(bookUrl, origin)` 复合主键；注释、迁移和 repository 已一致，验收仍应以数据库约束和并发写入测试为准。
- `searchCacheContext` 已覆盖搜索规则、请求头、Cookie 开关、JS 库和运行时变量；业务入口统一使用 `takeKey/putKey` 或 `takeForSource/putForSource`，不再回落到无 context 的兼容 key。

## 3. 目标领域模型

### 3.1 四类核心对象

```text
BookIdentity 1 ── N BookCandidate N ── 1 BookSource
     │                    │
     └── selectedCandidate └── VerificationEvidence / SourceHealth
                                   │
                            SelectionDecision
```

- `BookIdentity`：用户认知中的一本书，负责书架、阅读进度和展示名称。
- `BookCandidate`：某个书源返回的可抓取入口，保留原始字段和来源事实，不因优选失败删除。
- `SourceHealth`：书源在一段时间内的成功率、延迟、目录和正文探测结果，带衰减时间。
- `SelectionDecision`：本次选择的候选、分数、理由、验证结果和算法版本，可回放。

### 3.2 身份判定规则

身份判定分三层，禁止一步模糊合并：

1. **exact**：规范化书名 + 规范化作者完全一致；作者为空时不能把空作者当作强身份。
2. **probable**：书名高度相似，作者缺失或存在轻微差异，同时有 canonical URL、简介、字数、题材或章节标题等辅助证据。可以展示建议，但合并必须保留撤销信息。
3. **ambiguous**：同名异作者、同作者不同作品或证据冲突。不自动合并，允许用户选择。

规范化器至少处理：Unicode NFKC、大小写和全半角、连续空白、常见标点、站点前后缀、繁简策略和作者分隔符。规范化逻辑必须成为一个共享模块，搜索合并、书架写入、换源匹配和迁移都调用它。

建议输出：

```dart
IdentityResolution resolveIdentity(BookIdentityInput input);

// resolution: exact | probable | ambiguous | new
// identityKey: 稳定、可诊断、版本化的 key
// evidence: 命中的字段和相似度
```

规范化算法变更时递增 `identity_algorithm_version`，不要静默改变旧数据的含义。

### 3.3 候选唯一键

候选事实至少按以下字段区分：

```text
candidate_key = (identity_key, origin, book_url, source_context_hash)
```

如果确认同一书源同一 URL 的不同 context 不需要并存，可以把 context 放为可更新字段；在结论确定前，迁移阶段应保留 context，避免旧规则结果覆盖新规则结果。`book_url` 绝不能单独作为全局主键。

## 4. 目标数据模型和迁移

### 4.1 推荐表结构

保留兼容字段，但新增稳定身份、候选和选择数据：

```text
book_id / identity_key / identity_algorithm_version
 display_name / display_author / author_state / match_state
 selected_candidate_id / created_at / updated_at

book_candidates:
 id, identity_key, origin, book_url, canonical_url,
 name, author, toc_url, info_html, latest_title,
 source_context_hash, first_seen, last_seen,
 verify_state, verify_level, failure_code,
 respond_time, score_snapshot, raw_payload_ref

source_health:
 origin, success_rate, toc_success_rate, content_success_rate,
 latency_ema, freshness, consecutive_failures,
 last_success_at, last_failure_at, decay_at

selection_decisions:
 id, identity_key, candidate_id, score, algorithm_version,
 reasons_json, evidence_json, created_at
```

字段职责：

- 书架只保存身份、当前候选引用和阅读进度。
- 候选保存来源事实和最近验证结果，不因为排序变化丢失。
- `score_snapshot` 只表示某次评分结果，不能作为永久真相。
- 正文、图片、字体和大 HTML 存入 blob/file store；数据库保存引用、大小、校验和、过期时间。

### 4.2 迁移策略

当前 schema 为 v6，建议分两步：

**v7：兼容性迁移**

- 新增 `identity_key`、规范化版本和候选 context 字段。
- 新建候选唯一索引前，生成重复报告，不直接删除冲突数据。
- 从旧 `Books` 和 `SearchBooks` 双读，旧行保留 `legacy_id`。
- 从 `onlineShelf` 导入时记录 `migration_source`、失败原因和原始 JSON 引用。

**v8：约束迁移**

- 在离线迁移事务中重建候选表，将旧数据映射为复合键。
- 对完全重复的候选保留最新成功记录和历史审计记录。
- 对无法判定的 probable/ambiguous 数据进入待确认表，不强行归并。
- 完成校验后再启用唯一索引和外键约束。
- 保留导出和回滚脚本，迁移失败时恢复旧表和 KV。

迁移必须满足：可重复运行、可中途恢复、不会因单条脏数据中止全量迁移、执行前后书架阅读进度一致。

## 5. 搜索、去重、验证和优选流水线

### 5.1 流程

```text
SourceFanout
  ↓
原始候选落库（保留 source / raw / context）
  ↓
字段清理与 identityKey 计算
  ↓
IdentityResolver：exact / probable / ambiguous
  ↓
CandidateRepository 合并来源，不覆盖事实
  ↓
SourceRanker 计算可解释分数
  ↓
CandidateVerifier：目录 → 首章 → 连续性抽样
  ↓
SelectionDecision 记录选择原因
  ↓
书架选择或 SourceSwitchService 执行切换
```

UI 可以实时显示原始命中，但“加入书架”和“自动换源”只能使用已经完成身份判定的候选。任何候选被过滤时，保留过滤原因用于诊断。

### 5.2 搜索早停

`rawHits` 只用于诊断，不能控制早停。控制指标改为：

- `newIdentityHits`：本轮新增的 exact/probable 身份数量。
- `qualifiedCandidates`：达到名称、作者、可抓取性最低门槛的候选数量。
- `verifiedCandidates`：完成一级或二级验证的候选数量。

默认策略：首屏达到最低 `newIdentityHits` 后停止启动新源，但已在途请求继续完成；换源全量扫描关闭早停或使用 `verifiedCandidates` 目标。UI 必须明确显示“已提前返回，可继续搜索剩余书源”。

### 5.3 可解释评分

第一版使用规则评分，不引入黑盒模型：

```text
score =
  0.25 * titleMatch
+ 0.20 * authorMatch
+ 0.15 * tocCompleteness
+ 0.15 * contentProbeSuccess
+ 0.10 * sourceSuccessRate
+ 0.05 * freshness
+ 0.05 * latencyScore
+ 0.05 * configuredWeight
- penalties
```

扣分项包括：目录为空、正文为空、连续失败、超时、登录失败、验证码、章节标题重复率异常、章节顺序倒退和正文长度异常。每一项分数必须保留原始值和理由，例如：

```json
{
  "score": 0.86,
  "reasons": [
    "书名完全匹配",
    "作者匹配",
    "目录 312 章",
    "首章正文探测成功，长度 8421",
    "近 20 次目录成功率 95%",
    "平均响应 1.8 秒"
  ]
}
```

### 5.4 验证等级

- **L1 元数据与目录**：书名/作者可接受，目录非空且至少有两章。
- **L2 当前正文**：抽取首章或当前章，正文非空、长度合理、章节标题相似。
- **L3 连续性抽样**：连续抽取两至三章，检查章节序号、标题和正文连续性。

自动换源至少达到 L1 + L2；后台健康检查可抽样 L3。切换阅读进度时，使用旧章节标题、章节号窗口和相似度映射，不能直接把旧 index 当成新源 index。

## 6. 统一服务与接口契约

### 6.1 搜索域服务

建议新增或逐步抽取以下服务：

- `SearchOrchestrator`：接收查询、调度源、控制取消和早停。
- `SearchCache`：唯一封装 key、读写、失效和 context。
- `IdentityResolver`：规范化和身份判定。
- `CandidateRepository`：候选事实的事务读写。
- `SourceRanker`：计算分数和理由。
- `CandidateVerifier`：目录、正文和连续性验证。
- `SourceHealthRepository`：记录成功率、延迟和失败衰减。
- `SourceSwitchService`：换源面板和自动换源的唯一入口。

`SourceFanout` 只负责并发、host 限流、取消传播和结果投递，不负责业务去重、评分和书架写入。

### 6.2 缓存契约

禁止业务层直接拼接缓存 key，统一使用：

```dart
SearchCacheKey.from(
  source: source,
  query: query,
  page: page,
  context: SearchRequestContext.from(source, engineVersion),
);
```

context 至少包含：规则内容或版本哈希、搜索 URL、关键请求头哈希、Cookie/登录态版本、分页参数、JS 库版本、引擎版本和必要的 runtime variables。以下变化必须失效旧 context：规则、请求头、Cookie、登录态、分页策略、引擎语义版本。

改造清单：

- `SourceFanout` 的读写保持 context 对称。
- `auto_source_switch.dart` 的 `take` 必须传 context。
- `change_source_sheet.dart` 的 `take` 必须传 context。
- 其他搜索缓存调用通过 `rg "SearchHitCache.*take|SearchHitCache.*put"` 清零直调。
- context 变更测试必须覆盖规则、Cookie、JS 库和 runtime variable。

### 6.3 OnlineBookPort 与 Web

统一能力契约：

```text
search / explore / loadBookInfo / loadChapterList / loadContent
```

每个方法返回结构化 `DomainError`，至少包含 `code`、`stage`、`sourceId`、`bookId`、`retryable`、`recoverable` 和 `suggestedAction`。

Web 分两种目标，必须在产品文档中选定：

- **远程阅读器**：服务端负责搜索、发现、详情、目录、正文和会话；Web 只渲染和操作。
- **完整 Web 客户端**：补齐上述所有路由，复用同一套搜索、身份、候选和优选服务，不能另写一套 Web 逻辑。

服务端 API 建议增加：

```text
GET  /sources/capabilities
POST /search
POST /explore
POST /book/info
POST /book/catalog
POST /book/content
POST /source/verify
GET  /search/{requestId}/events
POST /search/{requestId}/cancel
```

API 返回 `capabilityVersion`、请求 correlation id、候选 context 和错误分类。暂不支持的能力必须返回 `capability_missing`，不能伪装成空结果。

## 7. 性能与存储优化

### 7.1 统一基线

每次基线必须记录：提交号、设备、系统、Flutter/Dart/引擎版本、网络类型、书源、查询、页面大小、缓存状态和命令。链路埋点包括：

- 搜索首个可用身份时间、全部结果时间、P50/P95。
- 目录首批章节时间、完整目录时间、目录缓存命中率。
- 正文请求、解析、首屏和排版 P50/P95。
- 规则编译和规则评估耗时。
- 取消后仍完成的请求数、host 槽位占用时间。
- 源级失败码、重试次数、超时比例。
- 数据库大小、blob 大小、启动时间和迁移时间。

### 7.2 初始预算

这些是第一版目标，不是当前实测结论：

| 指标 | 目标 |
|---|---:|
| 首个搜索身份 | P95 < 1.5 s（异常站点单独统计） |
| 网络正文首屏 | P95 < 2.5 s（站点响应超过 10 s 单独归类） |
| 离线正文首屏 | P95 < 500 ms |
| 阅读排版 | P95 < 100 ms/屏，菜单开合不触发整章重排 |
| 搜索 UI 更新 | 100–150 ms 合并一次 |
| 正文缓存命中率 | 稳定使用后 > 90% |
| 取消传播 | 取消后新请求不再占用 host 槽位 |

达到预算前，先解决影响正确性的重复请求、缓存误命中和错误重试；不要单纯通过提高并发换取首屏数字。

### 7.3 存储和排版

- 正文、图片、字体和大 HTML 使用独立 blob/file store，支持临时文件、原子替换、校验和、LRU 和后台清理。
- KV 只保存小型配置、索引和迁移标记。
- 章节和正文 key 至少包含 source、book identity、chapter、规则/会话 context，避免跨源正文混淆。
- 段落测量缓存 key 包含段落哈希、字体、字号、宽度、行距、语言和禁则版本。
- 首章采用增量排版，避免 preview 后再次全量排版同一章节。
- 以真实设备 timeline 确认启动瓶颈后，再调整数据库打开、媒体会话、日志持久化和统计初始化的并行关系。

## 8. 平台和 Legado-E 兼容路线

### P0：会让整条链路失败

- 原生 QuickJS deadline、interrupt handler、内存上限和会话隔离。
- Web 浏览器无法硬中断 JS 时的能力降级、超时和可见错误。
- 书源会话级 `jsLib` 持久化，同一书源会话内共享，跨源隔离。
- Web 搜索/发现/详情/会话契约，或明确远程阅读器边界。

### P1：影响大量书源或阅读体验

- `queryTTF`/`replaceFont` 的字节返回通道，使用真实字体反爬书源验证。
- `loginUi` 自定义表单、Cookie/token 生命周期、重新登录和退出清理。
- Android TTS、后台下载、通知和媒体会话。
- 正文、图片和字体的 blob 存储与清理。

### P2：低频和高级能力

- `DictRule`。
- 事件回调和 `customButton`。
- RSS `sortUrl`、正文黑白名单和边缘字段。
- Legado-E 未实际消费的 `weight`、`exploreScreen` 等字段只保留兼容，不实现无行为差异的假功能。

### 明确降级

DRM、平台专有 Rhino 白名单的完全复制、压缩格式全套桥接不纳入近期计划。必须提供结构化错误和用户可理解的替代动作。

## 9. 分阶段实施计划

### 阶段 0：基线和模型冻结（1 周）

**任务**

- 固定提交号，重新运行引擎测试、`flutter analyze`、Web 构建和可运行平台测试。
- 建立 50 组离线 fixture：同名异书、作者缺失、同 URL 多源、书名后缀、目录为空、正文为空、context 变化、取消/续搜和章节换源定位。
- 输出搜索、目录、正文、排版和迁移基线。
- 生成唯一的验证清单，删除报告中互相矛盾的历史测试数字。

**验收**

- 每组 fixture 有期望身份、候选数、选择结果和错误码。
- 所有空结果带错误分类。
- 报告包含提交号、设备、命令和失败分类。

### 阶段 1：去重和候选正确性（1–2 周）

**任务**

- 实现共享规范化器和 `identityKey`。
- 将 `SearchBooks` 迁移为候选复合键，至少支持 `(origin, bookUrl, source_context_hash)`。
- 实现身份、候选、选择写入事务。
- 将早停改为新增唯一身份数。
- 清理自动换源和换源面板的重复合并代码。
- 统一所有缓存读写 context。

**验收**

- 同一本书跨 10 个源只生成一个 exact identity，但保留 10 个候选。
- 同名不同作者不自动合并。
- 同 URL 不覆盖不同来源。
- 规则、Cookie、登录态或引擎版本变化后不命中旧候选。
- 32 路并发写入无重复、无 orphan、无半个身份。

### 阶段 2：可解释优选和换源闭环（1–2 周）

**任务**

- 建立源健康账本和衰减恢复。
- 实现评分、理由、L1/L2 验证和 `SelectionDecision`。
- 统一 `SourceSwitchService`，供面板和自动换源调用。
- 实现按标题相似度、章节号窗口和章节标题的阅读进度映射。
- 将前台快速返回和后台补搜分离。

**验收**

- 目录空源能切换到非空源。
- 正文空源能切换且保留阅读位置。
- 质量更高但响应稍慢的源不会被单一 latency 指标淘汰。
- 任一选择可以回放分数、理由、验证级别和失败候选。

### 阶段 3：性能、缓存和存储（2–3 周）

**任务**

- 落地正文 blob store 和清理策略。
- 加入段落测量缓存和首章增量排版。
- 优化启动依赖图、离线快速路径和搜索 UI 节流。
- 验证连接复用、host 限流、请求取消和缓存命中前后差异。

**验收**

- 搜索首结果、正文首屏、离线首屏和排版 P95 达到预算。
- 数据库大小和启动时间不随正文缓存线性膨胀。
- 所有优化均有前后基线和回滚开关。

### 阶段 4：Web 和平台能力（3–6 周）

**任务**

- 完成 QuickJS deadline/隔离。
- 完成字体字节通道和登录会话。
- 完成 Android TTS、后台下载和通知。
- 按选定目标补齐 Web 搜索、发现、详情、验证和会话路由。
- 为 DictRule、RSS、事件回调增加真实 fixture。

**验收**

- 每项能力有单元 fixture、至少一个真实书源闭环和失败可见性测试。
- Web、Android、桌面分别标注已支持、降级和不支持。
- API 版本、capability matrix 和错误码同步更新。

### 阶段 5：持续回归

- 每两周运行真实书源分层回归：搜索、目录、正文、字体、登录、换源和离线。
- 按失败原因归因：站点失效、网络出口、鉴权、JS、规则解析、数据模型或产品策略。
- 规则 corpus、源健康统计和优选 fixture 只增不减。
- 任何评分或规范化算法变化都保留版本和迁移说明。

## 10. 验证矩阵

| 类别 | 必测场景 | 通过条件 |
|---|---|---|
| 身份 | 同名异作者、作者缺失、后缀、全半角、繁简 | exact/probable/ambiguous 符合预期 |
| 候选 | 10 源同书、同 URL 多源、同源 context 变化 | 候选不覆盖，唯一键稳定 |
| 缓存 | 规则、Cookie、登录态、JS 库变化 | 旧 context 不命中 |
| 并发 | 32 路写入、取消、续搜、重复回调 | 无重复、无 orphan、无槽位泄漏 |
| 优选 | 空目录、空正文、慢优质源、验证码 | 选择可解释，失败可切换 |
| 阅读 | 换源后章节标题和进度映射 | 位置误差在约定窗口内 |
| Web | 搜索、发现、详情、目录、正文、错误 | 契约一致，能力缺失可见 |
| 平台 | JS 死循环、大脚本、字体、登录、TTS | 超时/降级/错误明确 |
| 性能 | 冷启动、热启动、离线、网络、1 MB HTML | P50/P95 达到预算或有归因 |
| 迁移 | v6→v7→v8、中断重跑、回滚 | 数据不丢，脚本幂等 |

## 11. 风险、回滚和决策门

### 11.1 主要风险

- 规范化过强造成同名异书合并：先以 ambiguous 保守处理，记录证据和撤销入口。
- 候选表迁移误删：先建立影子表和冲突报告，验证后再启用唯一约束。
- 新缓存 context 降低命中率：分阶段灰度，记录命中率和错误率，可通过 feature flag 回退。
- 评分偏向快源：保留质量门槛和探索槽位，禁止只按延迟排序。
- Web 和本地能力漂移：服务端和本地共用领域服务、错误码和 fixture。
- 大正文迁移期间磁盘占用增加：设置配额、校验和、LRU，迁移任务可暂停和恢复。

### 11.2 每阶段决策门

进入下一阶段必须同时满足：

1. 当前阶段验收项全部通过。
2. 失败项有归因和 owner，不以“偶发”关闭。
3. 有可回滚开关或数据库备份。
4. 新旧路径的关键指标至少有一轮对照。
5. 文档、API、capability matrix 和代码状态一致。

## 12. 最终验收清单

- [x] `SearchBooks` 不再以单独 `bookUrl` 覆盖跨源候选；schema v7 代码与事务测试覆盖候选写入。
- [x] 搜索、自动换源和换源面板复用身份/候选判定、评分与缓存上下文代码路径。
- [x] 搜索早停按唯一作品计数，在途请求仍归并；应用测试覆盖重复与唯一候选。
- [x] 正文和二进制走 BlobStore，KV 不再承担无上限正文存储。
- [ ] 身份合并与候选保留通过完整离线 fixture 矩阵（含繁简、同名异作者、缺作者和 URL 变化）。
- [ ] 在目标设备验证 schema v6→v7 升级、重复运行、中断恢复、回滚及旧书架/阅读进度恢复。
- [ ] 在真实源验证自动换源、L1/L2 证据、切换后进度映射和失败回退。
- [ ] Web 浏览器完成搜索、探索、详情、目录、正文与会话错误的端到端验收。
- [ ] JS、字体、登录、TTS、后台下载等能力完成 Android/macOS/Windows/Web 矩阵实测。
- [ ] 采集约定设备与网络下的搜索、目录、正文、排版及内存 P50/P95，并记录对照基线。
- [ ] 最终报告引用同一批次的完整测试、迁移、性能和设备结果。

## 13. 近期任务清单（按代码责任划分）

### P0-A：身份和候选

- 新增 `identity_normalizer.dart` 和 `identity_resolver.dart`。
- 为 `SearchBook` 增加候选 context 和 canonical URL 的持久化字段。
- 改造 `SearchBooks` 主键和迁移脚本，补复合索引。
- 将 `ShelfRepository` 的原始 `name + author` 关联改为 `identityKey`。

### P0-B：缓存和搜索调度

- 新增 `SearchCacheKey`/`SearchRequestContext`，禁止业务层拼 key。
- 修正自动换源和换源面板的 context 读取。
- 将 `SourceFanout` 的早停计数移到身份合并层。
- 为每个 row 输出 rawHits、newIdentityHits、qualifiedCandidates。

### P0-C：统一换源

- 抽取 `SourceSwitchService`、`SourceRanker`、`CandidateVerifier`。
- 自动换源和换源面板只保留 UI 或触发逻辑。
- 记录 `SelectionDecision` 和进度映射结果。

### P0-D：Web 和错误契约

- 固定远程阅读器或完整 Web 客户端目标。
- 补 capability matrix、API version、correlation id 和错误码。
- 对 `explore`、详情、登录和取消能力明确实现或降级。

### P1：性能和平台

- 正文 blob store、段落测量缓存、启动 timeline。
- QuickJS deadline/隔离、字体反爬、登录会话。
- Android TTS、后台下载和通知。

## 14. 架构优化补充方案

### 14.1 分层和依赖规则

继续保持 UI → Feature Controller/Riverpod Notifier → UseCase/Domain Service → Repository/Port → Engine/Database/Network/Platform Adapter 的单向依赖。

- Widget 不直接调用引擎、数据库、KV 或 HTTP。
- 搜索、换源、目录和正文共享领域服务，UI 只订阅状态和发出意图。
- 领域层不导入 Flutter，平台差异通过 capability port 注入。
- Repository 负责事务和数据映射，UseCase 负责业务编排，Adapter 负责协议转换。
- 跨页面操作携带 operationId/correlation id，页面销毁后取消订阅和请求。
- 同一业务状态只能有一个权威来源，不能同时由 provider、KV 和 widget 本地变量拼装。

建议把新增能力归入以下边界：core/domain（身份、候选、错误、评分、验证）；core/data（repository、迁移、缓存、blob）；core/runtime（并发、取消、deadline、观测）；features/search、shelf、source_switch、reader、settings；platform/android、web、desktop。

### 14.2 统一异步状态和资源生命周期

搜索、目录、正文、迁移和下载统一使用 idle、loading、partial、ready、degraded、failed、cancelled 状态。每个状态保存 operationId、阶段、开始时间、已完成数量、错误码、是否可重试和最后一次有效数据。旧请求返回时必须检查 operationId，禁止覆盖新查询或新书源状态。

每个操作拥有独立取消令牌；关键词变化、页面退出、书源切换和新章节打开时取消旧操作。连接、规则执行、目录分页和正文跳转分开计时。WebSocket、WebView、图片解码、文件句柄、isolate 和 TTS 会话必须在完成、失败和取消三条路径释放。

### 14.3 统一能力矩阵

启动时生成平台能力矩阵，至少覆盖 JS deadline、JS 隔离、WebView、字体字节、登录 UI、后台下载、通知、TTS、文件存储和全屏。能力状态使用 supported、degraded、unsupported，并给出原因和替代动作；界面不能让用户点击后才得到未分类异常。

## 15. 速度和加载优化补充

### 15.1 启动三段化

当前已有启动占位页，但 vault hydration、凭据迁移、KV 准备、主题恢复和引擎设置仍需要按依赖图整理：

1. 首帧关键路径：Flutter binding、最小主题、路由壳和上次页面状态。
2. 首屏关键路径：主题、语言、书架摘要、最近阅读和数据库打开。
3. 后台路径：媒体会话、完整书源同步、日志持久化、统计、缓存清理和源健康刷新。

离线时不得等待网络或超时任务才能显示书架。每个阶段记录耗时和失败原因。目标是冷启动有内容画面 P95 小于 1.5 秒，离线书架可用 P95 小于 2 秒。

### 15.2 网络、解析和内存

- 连接池按 host 复用，分别限制总并发、host 并发和下载并发。
- 搜索只取最低字段，详情、目录和正文延后加载。
- 首个高置信候选先返回，后台补搜剩余源。
- 规则编译按规则内容和引擎版本缓存，并隔离 CSS、XPath、JSONPath、正则命名空间。
- 重试采用指数退避和上限；验证码、登录失败和规则错误不自动重试。
- 图片采用尺寸感知缓存，列表封面不按原图解码。
- 正文缓存按章节使用 LRU，设置总大小、单文件大小和单书配额。
- 超大 HTML、脚本、图片和跳转超过上限时返回可见的资源超限错误。
- 阅读器只保留当前章、相邻章和必要的分页结果，章节切换后释放旧正文。

### 15.3 加载体验

搜索、详情、目录、正文和书架使用局部骨架与增量结果，不用整页转圈覆盖已有内容。搜索先显示已完成源；目录先显示首批章节；正文先显示缓存或骨架，网络返回后增量分页；书架先显示本地摘要，再后台刷新最新章节。

统一读取顺序为内存、数据库/blob、短期网络缓存、网络请求。过期内容允许先展示并后台刷新；错误缓存不能伪装成空内容。每个失败阶段提供重试、换源、查看错误详情和继续旧缓存四种动作。

## 16. 书籍和书源选优优化补充

### 16.1 搜索结果四层处理

先过滤空 URL、空书名、广告页、错误页和不完整响应；再计算 identityKey；然后按目录、正文、更新章节、简介、封面、字数和响应质量评价候选；最后按相关性、质量、稳定性、新鲜度、延迟和用户行为展示排序。

同一身份展示一个主结果和其他书源入口。结果卡片显示书名、作者、来源、最近章节、目录数量、验证状态和失败原因。重复候选保留事实和去重原因，不静默丢弃。

### 16.2 源探索、用户偏好和换源安全

源排序采用利用与探索：大部分请求给高置信高质量源，小部分留给新源、低样本源、近期恢复源和用户偏好源。健康评分按时间衰减，单次超时不能永久拉黑。

允许质量优先、速度优先、稳定优先三种策略；允许固定源、隐藏源、收藏源和手动反馈。固定源验证失败时提示用户，不静默替换。换源前保存旧章节标题、索引、URL 和阅读偏移，换源后按标题、章节号窗口和正文首句映射；置信度低时要求确认。

## 17. 主题系统优化补充

继续使用 AppTokens 和 AppStyleExtension，把页面背景、阅读背景、文本层级、错误/成功状态、页面宽度、阅读列宽、侧栏、控件高度、触摸目标、圆角、分割线、阴影和动画全部收敛为语义 token。页面禁止出现业务色值、随意圆角和随意固定字号。

经典、Absolutely、终端三套风格共享布局结构，只替换 token。每套主题覆盖浅色、深色、墨水屏、高对比度、大字体截图矩阵；检查对比度、链接、错误态、禁用态和焦点态。主题切换不得丢失阅读页状态、滚动位置、分页位置和弹层状态。UI 字体与阅读字体分离，字体、字号、宽度、行距或禁则版本变化时只失效相关分页缓存。

## 18. 交互优化补充

- 新关键词立即取消旧搜索，旧结果不得覆盖新结果。
- 搜索结果支持全部、按书源、已验证、可能重复筛选，继续搜索不重置滚动位置。
- 空结果区分没有命中、所有源失败、代理不可用和仍在搜索。
- 加入书架后立即显示身份；候选同步失败显示待同步、重试和错误详情。
- 删除书籍提供撤销，撤销期间不立即清理所有候选正文。
- 换源面板显示质量、速度、目录数、最近章节、验证状态和切换置信度。
- 中央点击、边缘点击、键盘、鼠标滚轮和触控板统一映射。
- 菜单显隐不触发正文重新测量，除非可用正文高度真的变化。
- 目录、设置、书签和换源弹层支持返回键、Esc、点击外部和手势关闭。
- 所有图标按钮有语义标签，触摸目标不小于 44×44 logical pixels。
- textScale 0.85–1.4、高对比度和窄屏下不遮挡主要按钮。

## 19. 占不满屏幕问题专项修复

### 19.1 问题分类

- 背景没有填满窗口：根节点或 Scaffold 只包住内容。
- 内容列过窄：可读性 maxWidth 影响了外层背景和交互区域。
- 系统栏占用空间：阅读器隐藏了应用菜单，却没有统一处理状态栏、导航栏和浏览器全屏。

### 19.2 布局原则

页面根节点负责填满可用约束并绘制背景，正文列单独使用 maxWidth。宽屏使用全宽背景、居中正文列和可选侧栏；窄屏使用全宽内容和安全区。内容最大宽度不能限制背景、工具栏、进度条和手势热区。MediaQuery padding、viewPadding、viewInsets 和键盘高度分开处理，旋转、分屏、窗口缩放、浏览器窄视口和字体放大后重新计算布局。

重点检查 HomeShell、Library、Search、Explore、BookDetail、Reader 和所有 bottom sheet 的 Expanded、ConstrainedBox、Center、SafeArea 组合，避免约束向上泄漏。背景、分割线、加载态和空态必须覆盖整个路由 viewport。

### 19.3 阅读器沉浸式全屏

进入阅读器时由 ReaderViewportController 集中管理系统栏、方向和常亮：优先使用 immersiveSticky；不支持时使用 edgeToEdge 并按安全区留白。离开阅读器、异常退出、旋转和路由替换时恢复全局 UI mode、方向和常亮状态。系统栏颜色和图标明暗与阅读背景同步。

Web 端检测 Fullscreen API 能力；浏览器拒绝时保留普通全宽布局并显示一次可关闭提示。不能把浏览器拒绝误报成阅读器失败。

验收覆盖刘海屏、手势导航、三键导航、平板横屏、桌面窗口、浏览器窄视口、键盘弹出、旋转和系统字体放大：背景没有未解释的空白带，正文和工具栏不被系统栏遮挡，退出后系统状态恢复。

## 20. 当前代码中应优先修复的潜在 Bug

| 严重度 | 现象 | 风险 | 修复方向 |
|---|---|---|---|
| P0 | OnlineShelfNotifier.add 只按 bookUrl 判断已存在 | 同一身份从其他书源加入时被忽略 | 改为 identity + candidate 判断，已有身份执行候选 upsert |
| P0 | ShelfRepository 候选写入和 Books 身份写入分开 | 中断后候选无身份或身份无候选 | 使用单事务 upsertIdentityAndCandidate |
| P0 | SearchBooks 仅以 bookUrl 为主键 | 同 URL 多源或不同 context 相互覆盖 | 迁移为复合唯一键并先输出冲突报告 |
| P0 | 书架和候选按原始 name/author 关联 | 规范化差异造成重复或错误合并 | 统一 IdentityResolver 和 identityKey |
| P0 | _toItem 用身份行 bookUrl 生成 SearchBook | 当前候选 URL 被替换，目录/正文可能请求错误入口 | 同时保存 identity URL 与 candidate URL |
| P0 | 自动换源和换源面板部分缓存读取不传 context | 规则或 Cookie 变更后命中旧候选 | 统一 SearchCacheKey，禁止无 context 直读 |
| P1 | SourceFanout 按原始 books 数量早停 | 重复命中耗尽阈值，漏掉高质量源 | 在身份合并层按新增 identity 计数 |
| P1 | 阅读器只恢复方向和常亮，没有集中恢复系统 UI mode | 状态栏/导航栏占空间或状态残留 | 引入 ReaderViewportController，覆盖退出和异常路径 |
| P1 | maxWidth 与全屏背景职责混合 | 内容看起来没有铺满窗口，交互热区变窄 | 根背景全宽，正文列单独限宽 |
| P1 | 数据库失败时回退 legacy blob | 数据库已有部分数据时可能显示旧快照 | 记录数据源版本，明确不可用时才回退并提示同步状态 |
| P1 | 异步搜索和持久队列可能被旧页面继续写入 | 旧结果覆盖新状态，切换后数据错位 | 使用 operationId、幂等 mutation key 和取消检查 |
| P1 | 候选和正文缓存 key 未统一身份/来源/context | 跨源正文混用或切换后显示旧内容 | key 加 identity、origin、candidate 和 context |
| P1 | TTS、自动翻页和章节切换并发 | 旧章节回调推进新章节或重复请求 | 每个阅读会话独立 token，切换前取消旧任务 |
| P2 | 大图片、字体和 HTML 失败时只显示空白 | 用户无法判断资源、网络还是规则问题 | 统一 DomainError 和可重试动作 |
| P2 | 大字体、高对比度和窄宽度下按钮/标题溢出 | 关键操作被遮挡 | 增加 golden/layout 矩阵和最小宽度布局 |
| P2 | 主题切换使整章重新排版 | 切换卡顿、页码跳变 | 分离 UI theme 和 reader layout key，保留位置映射 |

每个 Bug 必须有最小复现、根因层级、修复记录和回归场景，不能只用 UI 条件判断掩盖数据、事务或生命周期问题。

## 21. 扩展实施阶段

### 阶段 1A：架构和 Bug 止血（1 周）

修复书架单一 bookUrl 拦截、候选/身份事务、候选 URL 被替换、operationId 和阅读器系统 UI mode。先让书架、搜索和阅读器不再出现数据覆盖或状态残留。

### 阶段 1B：选优闭环（1–2 周）

接入 identityKey、候选复合键、SearchCacheKey、统一换源服务、源健康、评分、L1/L2 验证和理由展示；加入质量优先、速度优先、稳定优先策略和回切旧源。

### 阶段 2：加载和性能（2 周）

完成启动三段化、局部骨架、缓存优先、后台刷新、正文 blob、图片尺寸缓存、分页和排版拆分；建立启动、搜索、正文、排版和内存基线。

### 阶段 3：主题、布局和交互（1–2 周）

完成 semantic token 收敛、主题截图矩阵、全宽背景、沉浸式阅读器、大字体、高对比度、窄屏、分屏和宽屏布局；统一 loading、错误、撤销、继续搜索、换源和阅读手势。

### 阶段 4：平台能力和持续回归（3–6 周）

完成 QuickJS deadline、字体、登录、TTS、后台下载、Web Fullscreen；每两周运行真实书源和设备矩阵回归，持续维护潜在 Bug 台账、源健康和失败归因。

## 22. 扩展后的最终验收项

- [x] 书架身份与候选写入具备事务边界，候选 URL 不被身份 URL 覆盖。
- [x] 搜索、换源、目录、正文和书架都带 operationId、取消和错误分类。
- [ ] 启动首帧、首屏、离线书架和正文加载达到预算，并在目标设备复测。
- [ ] 主题 token 与浅/深/高对比、大字号和窄屏视觉矩阵完成自动化与人工验收。
- [ ] 阅读器系统栏、方向、常亮和 Web Fullscreen 在各平台完成进入/退出恢复验收。
- [x] 页面背景填满窗口；正文内容按可用区域布局，书库空态在宽屏下压缩留白并保持窄屏换行。
- [ ] 搜索、书架、换源、阅读器和下载的主要动作完成端到端撤销、重试和取消验收。
- [ ] P0/P1 潜在 Bug 台账逐项有最小复现、修复记录和回归结果。
- [ ] 性能、内存、缓存命中率和失败率有同设备前后对照，不只报告平均耗时。

## 23. 执行进度标记

> 标记规则：已完成表示代码路径已经修改并完成静态路径核对；运行时测试和真实设备验收仍按第 10 节矩阵执行。

- [x] **P0-缓存上下文统一（代码路径）**：新增 `SearchCacheKey`、`takeForSource`、`putForSource` 统一生成 context；`SourceFanout`、自动换源和换源面板均通过源级缓存 API 读写，已通过全仓 `rg` 核对业务调用点。
- [x] **P0-搜索早停去重（代码路径）**：`SourceFanout` 和 `SearchSession.hits` 按 `SearchMerge.identity` 统计唯一身份，同时保留 `rawHits` 诊断值。
- [x] **P0-书架身份与候选事务（代码完成）**：SearchBooks 已迁移为 `(bookUrl, origin)` 复合主键并升级 schema v7；repository 使用事务；provider 与 repository 使用同一规范化 identityKey；保留 identity URL 与 candidate URL，并按身份补充候选。运行时迁移和真实设备验证待执行。
- [x] **P0-换源评分统一（代码路径）**：自动换源和换源面板已改用 `SourceSwitchService`，统一评分、候选去重、目录/正文验证和选择记录。
- [x] **P0-统一换源服务**：`SourceSwitchService` 已抽取评分、候选去重、L1/L2 验证、选择理由和有界选择日志；自动换源与换源面板共用该服务。
- [x] **P0-Web 获取契约（代码完成）**：新增 `/exploreBooks`、`/getBookInfo`、服务端 backend、客户端调用和 capability flags；会话取消与真实 Web 闭环仍待验证。
- [x] **P1-全屏与满屏布局（代码完成）**：阅读器沉浸式系统栏、退出恢复、正文全宽背景/限宽列、Library/Search full-bleed 和大字体触摸目标已落地；真机/浏览器验收仍待执行。
- [x] **P1-启动/加载/主题/交互专项（代码完成）**：启动设置句柄并行、局部加载态、全宽正文、触摸目标、系统字号叠加、RSS/目录交互和阅读器章节防重入已落地；设备矩阵与性能基线仍待执行。

## 24. 执行记录（2026-09-25）

- [x] **统一换源领域服务**：新增 `chloris/lib/core/search/source_switch_service.dart`，统一候选接受条件、评分、按来源去重、验证顺序、L1 目录/L2 正文等级、失败原因和 `SelectionDecision`。
- [x] **自动换源接入**：详情页和阅读中空正文换源都调用同一服务；目录通过后继续探测首章正文，只有 L2 成功才自动采纳。
- [x] **换源面板接入**：候选列表使用同一评分和接受规则，用户点选前执行同一目录+正文验证，验证失败保留在面板而不切换空源。
- [x] **选择记录**：选择与失败候选写入有界 `sourceSelectionDecisionsV1` 日志，保存算法版本、来源、候选 URL、分数、理由、验证等级和失败码，可回放。
- [x] **缓存入口清零**：`SourceFanout` 使用捕获后的 `SearchCacheKey.takeKey/putKey`，自动换源和换源面板使用 `takeForSource/putForSource`，全仓不再存在 `SearchHitCache.instance.take/put` 直调。
- [x] **阅读器滚动灰屏**：滚动模式不再为永远为空的分页列表构造翻页数据，避免 `RangeError` 中断整页绘制；进度刷新限制在进度控件，新增长章节滚动回归测试。macOS universal AOT 已重新组装并更新发布包。
- [x] **阅读正文短段断行**：统一 LF、NEL、Unicode 行/段分隔符，合并被书源拆开的短文本段；回归测试覆盖截图中的句子并断言拼接处没有硬换行，重新构建 macOS universal 包。
- [x] **回归覆盖**：新增 `chloris/test/core/source_switch_service_test.dart`，覆盖同源候选去重、验证失败继续尝试、选择理由和决策记录。
- [x] **静态自查**：`git diff --check` 通过；计划文档中的未完成复选框已清零。
- [x] **二轮一致性复查**：修正文档顶部已过时的 D1–D7 风险描述；选择日志改为后台写入，不阻塞前台换源；补充缓存 key 捕获，防止 JS 运行时变量变更造成写入 key 漂移。

当前工作环境已提供 Flutter/Dart SDK。本轮针对阅读正文短段处理与阅读页执行回归测试，并通过 macOS universal release 构建；全仓 `flutter analyze` 仍报告 331 条既有问题，其中工具脚本引用缺失的 `source_unify.dart` 等错误未纳入本轮阅读修复。受影响的正文处理和回归测试文件另做定向分析。

## 25. 执行记录（2026-09-26）

- [x] **书库空态压缩**：空态内容组上移、缩小图标和组间距；操作入口在宽屏横向排列，窄屏自动换行；布局回归测试覆盖 1636×781 视口与入口对齐。
- [x] **任意窗口尺寸空态布局**：紧凑空态始终受滚动视口约束，空间充足时居中显示，较矮时切换横向摘要；短窗口页头工具栏改为横向滚动，极短窗口整页可滚动。回归尺寸覆盖 1054×255、640×220、400×180、320×140、240×100、180×80，均无布局异常；最窄/最矮时验证可滚动至底部入口并在视口内显示。
- [x] **极宽书库布局**：搜索、筛选和书目从左侧页边距铺展至右侧；全宽页面的页头动作区扩展到最右侧，窄屏继续使用滚动与自适应。新增 3000×900 回归测试，断言内容宽度及右侧按钮位置。
- [x] **短 TXT 目录识别**：对行首重复章节标题补充可信度判断，避免短章节被“匹配距离过近”规则全部拒绝。
- [x] **HTML 跨段断句续接**：段落空行只有在前文已以句末标点结束时才保留；未完句即使跨多个 HTML 块或夹有单字碎片也会接回正文。新增截图对应的章节管线回归样本并通过 10 项测试。
- [x] **IO JS 空字符串**：处理 flutter_js 的 C 字符串边界，保留 `''`/`""` 的合法空结果；显式保留 `undefined` 的回退语义。
- [x] **搜索早停回归**：测试数据为每个来源提供唯一作品，验证按去重身份而不是原始重复命中触发阈值。
- [x] **Web 缺失能力错误**：探索和书籍详情响应形状不符合契约时返回 `capability_missing`，避免静默呈现空结果。
- [x] **换源页面回归**：测试提供候选书的有效目录缓存，覆盖点选候选并关闭面板的成功路径；明确空正文拒绝，正文探针异常但目录有效时保留 L1 可选级别。
- [x] **专项测试**：上述引擎、搜索、Web、换源及书库用例均通过。
- [x] **本轮本机验收**：Flutter 全量 331 项通过、引擎全量 480 项通过；受影响 Dart 文件定向分析无问题；macOS universal Release 构建、深度签名校验、双架构检查及发布 ZIP 完整性检查通过。发布包：`chloris/build/releases/chloris-macos-0.1.0+1.zip`，SHA-256：`25336918e66ddf75940ed866ea3d6656a7005045de7c0c6e4346e51d036bab74`。
- [x] **短窗口修复再验收**：Flutter 全量 331 项通过；3 个受影响 Dart 文件定向分析无问题；macOS universal Release 构建、深度签名及 ZIP 完整性通过。最新发布 ZIP SHA-256：`a0892d7512c103a518452b987843556ac9fa3d6fa8abeb9c4bb7db2635b5ac12`。
- [x] **超宽布局专项验收**：书库测试 5 项通过；Flutter 全量 332 项通过；3 个受影响 Dart 文件定向分析无问题；macOS universal Release 已按全宽左对齐版本重建，深度签名、双架构及 ZIP 完整性检查通过；发布 ZIP SHA-256：`9338cbda4ce43c69a3c9212f9ecf0792577e9e134a3f584cc4404d0a7fb04dd6`。
- [x] **其余主标签页全宽**：探索与我的页面改为全宽正文和页头，搜索与书库保持一致；探索超宽、书库回归共 6 项通过；受影响文件定向分析无 errors（含 5 条既有 info）；macOS universal Release 深度签名、双架构及 ZIP 完整性检查通过；最新发布 ZIP SHA-256：`817bc83e43f1d41715d4fcc3a2e05f5207fdaedeeec9e7872da839174acff750`。
- [x] **阅读器碎片换行修复**：归一化竖向控制字符与 Unicode 行分隔符；分页器依据实际行指标解析字体回退后的行边界，并禁止中文弯引号出现在行首。章节清洗/分页测试 19 项、Flutter 全量 336 项通过，定向分析无问题；macOS universal Release 深度签名、双架构及 ZIP 完整性检查通过，SHA-256：`f32d73bc2e0c235b5b6745e6063b1ea9b6b3667fa7003d9eea5fe460447e954a`。
- [ ] **跨平台和性能验收**：真实 Web 闭环、设备矩阵、迁移中断/回滚以及 P50/P95 尚未具备本轮证据，完成前不勾选总体验收。

此前“331 条既有问题”是 2026-09-25 的历史静态分析记录，不代表当前结果。2026-09-26 全仓静态分析为 0 errors、46 warnings、257 infos（303 条）；这些告警/提示仍需在后续任务中逐步收敛。

## 参考证据

- `README.md`
- `artifacts/改进计划-架构性能引擎功能对齐legado-E.md`
- `artifacts/archive/legado-E-架构分析.md`
- `artifacts/规则引擎算法与legado-E差异.md`
- `artifacts/verification/perf-baseline/2026-09-12.md`
- `chloris/lib/data/database/app_database.dart`
- `chloris/lib/data/database/shelf_repository.dart`
- `chloris/lib/core/search/source_fanout.dart`
- `chloris/lib/core/search/search_schedule.dart`
- `chloris/lib/features/book_detail/auto_source_switch.dart`
- `chloris/lib/features/book_detail/change_source_sheet.dart`
- `chloris/lib/application/online/http_online_book_port.dart`
- `chloris/lib/application/online/online_reading_use_cases.dart`
- `chloris/lib/services/web/app_server_backend.dart`
