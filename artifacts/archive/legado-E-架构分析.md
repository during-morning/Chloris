# Legado-E 架构分析报告

> 分析对象：`/Volumes/Software/Chloris/reference/legado-E-main`（只读，未改动任何文件）
> 目标：为 Flutter 移植项目 **Chloris** 提供 Legado-E 的结构、分层与核心运行时的完整参照
> 行号均对应当前工作区快照；统计口径含空行与注释

---

## 0. 先决更正：任务书中的若干前提有误

在开始之前必须先纠正 7 处会导致移植方向错误的假设：

| # | 任务书假设 | 实际情况 | 证据 |
|---|---|---|---|
| 1 | UI 是 "Compose screens" | **零 Compose**。全仓 `@Composable` 命中数 = 0；`app/build.gradle` 的 `buildFeatures` 只有 `buildConfig`/`viewBinding`，无 `compose = true`；`res/layout/` 下 216 个 XML 布局；119 个文件使用 ViewBinding。`libs.versions.toml:84/158` 的 `activity-compose`、`glide-compose` 是未被引用的遗留声明 | `grep -rl "@Composable" app/src` = 0 |
| 2 | 存在 `modules/web` 模块 | 该目录**只有 3 个 README.md**，没有 `build.gradle`，未在 `settings.gradle` 中 include。`settings.gradle` 只 include `:app`、`:modules:book`、`:modules:rhino`。Web 前端源码在 `app/src/main/assets/web/`（Vue 打包产物 + help 文档） | `settings.gradle` 末尾；`find modules/web` |
| 3 | `ui/bookSource/` 包 | 实际路径是 `ui/book/source/`（`edit/`、`debug/`、`manage/`） | `ui/book/source/edit/BookSourceEditActivity.kt` |
| 4 | `lib/` 下有 tts/aes/pdf/zip/rhino/glide 等子包 | `lib/` 实际只有 9 个子包：`aliyun`、`cronet`、`dialogs`、`icu4j`、`mobi`、`permission`、`prefs`、`theme`、`webdav`。TTS 在 `help/TTS.kt`+`service/`；rhino 在 `modules/rhino`；glide 在 `help/glide`；zip 在 `modules/book/util/zip`；PDF 用系统 `PdfRenderer` | `ls app/src/main/java/io/legado/app/lib/` |
| 5 | `io.legado.READ_WRITE` 保护 ContentProvider | Manifest 中**未声明该权限**，`ReaderProvider` 无 `android:permission` 且 `exported="true"`。该权限只出现在 `api.md:189` 的文档里 | `AndroidManifest.xml:526-531` |
| 6 | 备份整包 AES 加密、远程书用 `webdav://` | ZIP 是**普通 zip**（`ZipUtils.zipFiles`），AES 只加密 `servers.json` 与 `webDavPassword` 两个字段；远程书标识是 `origin = "webDav::<url>,{json}"` 而非 scheme | `help/storage/Backup.kt:151-158`、`model/remote/RemoteBookWebDav.kt:79-81` |
| 7 | 存在 App Widget、`webPortEnabled`/`webSocketPort` 配置 | **无任何 AppWidgetProvider**（全仓 0 命中）。只有 `WebTileService`（QS 磁贴）与 Launcher 图标切换。端口配置只有 `PreferKey.webPort`（默认 1122），WebSocket 端口硬编码 `port + 1` | `service/WebService.kt:158/185-191` |

此外两处实体字段比上游 legado 更"瘦"，移植时不能照抄上游：`DictRule` 只有 `urlRule`+`showRule`（无 replacement 字段）；`HttpTTS` 无 method/headers/body/charset 列，这些藏在 `url` 的 `,{...}` JSON 尾缀里。

---

## 1. 模块与包结构

### 1.1 Gradle 模块与构建

- `settings.gradle`：`rootProject.name = 'legado'`，include `:app`、`:modules:book`、`:modules:rhino`。仓库与镜像仓库在 `pluginManagement`/`dependencyResolutionManagement` 中成对配置（注释掉阿里/华为/Google 镜像，需手动启用）。
- 根 `build.gradle`：仅声明插件别名（`libs.plugins.*`）与 `compile_sdk_version = 36`。
- `gradle/libs.versions.toml`：Kotlin **2.3.10**、AGP **8.13.2**、KSP 2.3.4、Room **2.7.1**、OkHttp **5.3.2**、coroutines 1.10.2、jsoup **1.16.2（锁定，禁止升级）**、Rhino **1.8.1（锁定）**、commons-text 1.13.1（锁定）、json-path 2.10.0、JsoupXpath 2.5.3、NanoHTTPD 2.3.1、Glide 5.0.5、Media3 1.8.0、sora-editor 0.24.4、LiveEventBus 1.8.14、hutool-crypto 5.8.22（锁定）、libarchive 1.1.6、quick-chinese-transfer 0.2.17。
- `app/build.gradle`：`namespace io.legado.app`，`minSdk 21 / targetSdk 36`，Java 17 + `coreLibraryDesugaring`，KSP 驱动 Room（`room.generateKotlin=false`，schema 目录 `app/schemas`）。版本号 `3.yy.MMddHH`，`versionCode = 10000 + git commit count`。release 开 minify+shrinkResources。
- `app/schemas/io.legado.app.data.AppDatabase/` 下 **89 个 schema JSON**（1.json … 89.json），是数据库演进史的完整记录，对 Flutter 侧（如 drift/isar）复刻 schema 极有价值。

### 1.2 `app/src/main/java/io/legado/app/` 包全景（859 文件 / 140,707 行）

| 包 | 文件 | LOC | 职责 | 代表类 |
|---|---|---|---|---|
| `ui` | 378 | 71,996 | 全部界面（Activity/Fragment/View/Adapter/Dialog） | `ReadBookActivity`、`ReadView`、`TextChapterLayout`、`MainActivity` |
| `help` | 102 | 17,461 | 横切基础设施：配置、缓存、HTTP、替换、备份、源工具 | `AppConfig`、`ReadBookConfig`、`CacheManager`、`BookHelp`、`HttpHelper`、`AppWebDav`、`Backup`、`ContentProcessor` |
| `model` | 44 | 13,754 | 领域运行时（无 UI、无 Room 定义） | `WebBook`、`ReadBook`、`CacheBook`、`Download`、`ReadManga`、`AudioPlay`、`ReadAloud`、`VideoPlay` |
| `utils` | 102 | 11,466 | 通用工具与 Kotlin 扩展 | `NetworkUtils`、`GsonExtensions`、`HtmlFormatter`、`EncodingDetect`、`FlowExtensions`、`FileUtils`、`ACache` |
| `lib` | 102 | 11,446 | vendored/复制进来的第三方库 | `icu4j`、`mobi`、`cronet`、`webdav`、`theme`、`permission`、`dialogs`、`prefs` |
| `data` | 62 | 5,336 | Room 数据库、实体、DAO | `AppDatabase`、`BookSource`、`Book`、`BookChapter` |
| `service` | 11 | 4,940 | 前台服务 | `BaseService`、`BaseReadAloudService`、`CacheBookService`、`ExportBookService` |
| `base` | 19 | 1,675 | UI 基类与通用 Adapter | `BaseActivity`、`VMBaseActivity`、`BaseViewModel`、`RecyclerAdapter` |
| `api` | 7 | 833 | 对外 API（ContentProvider + 4 个 Controller） | `ReaderProvider`、`BookController`、`BookSourceController` |
| `constant` | 13 | 688 | 常量与模式 | `AppConst`、`PreferKey`、`AppPattern`、`BookType`、`EventBus`、`NotificationId` |
| `web` | 6 | 517 | 内置 HTTP/WebSocket 服务 | `HttpServer`、`WebSocketServer`、`AssetsWeb`、3 个 socket handler |
| `receiver` | 4 | 286 | 广播/媒体键接收 | `MediaButtonReceiver`、`TimeBatteryReceiver` |
| `exception` | 8 | 48 | 自定义异常 | `TocEmptyException`、`ContentEmptyException`、`ConcurrentException`、`RegexTimeoutException` |

### 1.3 分层与数据流

```
┌─ UI 层 ──────────────────────────────────────────────────────────────┐
│ Activity/Fragment + ViewBinding（216 XML）  ui/**                     │
│ 自绘阅读视图 ReadView/PageView/ContentTextView                        │
│ ViewModel（base/BaseViewModel: AndroidViewModel + execute/executeLazy）│
└──────────────┬──────────────────────────────────────────────────────┘
               │  三种通信方式（无 Flow 单向数据流）
               │  ① LiveEventBus 字符串事件（constant/EventBus.kt ~40 个 key）
               │  ② 回调接口（ReadBook.CallBack 14 个方法 / ReadView.CallBack 11 个）
               │  ③ LiveData（57 个文件，主要用于表单/导入结果）
┌──────────────▼──────────────────────────────────────────────────────┐
│ 领域运行时层  model/**（全部是 Kotlin object 单例）                    │
│ WebBook（抓取） ReadBook（阅读会话） CacheBook（下载） ReadAloud（朗读）│
│ Rss/RssParserByRule  LocalBook/{TextFile,EpubFile,MobiFile,UmdFile}   │
└──────────────┬──────────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────────┐
│ 规则引擎（model/analyzeRule，4407 行）                                │
│ AnalyzeUrl → 构造请求/UrlOption/cookie/限流                           │
│ AnalyzeRule → 规则切分(SourceRule) + 4 种解析后端                      │
│   AnalyzeByJSoup / AnalyzeByXPath / AnalyzeByJSonPath / AnalyzeByRegex│
│ RuleAnalyzer → 平衡组扫描器（&&/||/%%/{{}}/@get/@put/##）             │
│ RhinoScriptEngine（modules/rhino）→ JS 沙箱                           │
└──────────────┬──────────────────────────────────────────────────────┘
               │
┌──────────────▼──────────────────────────────────────────────────────┐
│ 支撑层                                                                │
│ Room（data/**，21 实体 + 1 视图，89 版本）                             │
│ 文件系统（externalFilesDir/book_cache/**、filesDir/*.json）             │
│ 网络（help/http：全局 OkHttp 5 单例 + Cronet 可插拔）                   │
│ 缓存（help/CacheManager：LruCache 50MB + Room caches + ACache）        │
└──────────────────────────────────────────────────────────────────────┘
```

关键特征：**没有 Repository 层、没有 DI 框架（无 Hilt/Koin）**。单例 `object` 直接 `appDb.xxxDao` / `CacheManager` 全局取用；`App.kt` 手工初始化（含 Rhino WrapFactory 注册、通知渠道创建）。

---

## 2. 数据模型（Room）

### 2.1 数据库定义

`data/AppDatabase.kt:60-67`：

```kotlin
val appDb by lazy {
    Room.databaseBuilder(appCtx, AppDatabase::class.java, "legado.db")
        .fallbackToDestructiveMigrationFrom(false, 1, 2, 3, 4, 5, 6, 7, 8, 9)
        .addMigrations(*DatabaseMigrations.migrations)
        .allowMainThreadQueries()      // ← 允许主线程查询
        .addCallback(AppDatabase.dbCallback)
        .build()
}
```

`@Database(version = 89, exportSchema = true, entities = [...21 个...], views = [BookSourcePart::class], autoMigrations = [AutoMigration(43→44) … AutoMigration(88→89)])`。43 之前的手写迁移在 `DatabaseMigrations.migrations`（含 `Migration_54_55`、`_64_65`、`_80_81`、`_83_84`、`_84_85` 的 spec）。

`dbCallback.onOpen`（`:177-260`）承担**幂等的启动期修补**，这是移植时要复刻的隐藏逻辑：
- 用 `insert ... select ... where not exists` 补齐 8 个内置分组（`BookGroup.IdAll=-1/IdLocal=-2/IdAudio=-3/IdNetNone=-4/IdLocalNone=-5/IdVideo=-6/IdError=-11`）；
- 清洗历史脏数据：`loginUi='null'` → NULL（book_sources/rssSources/httpTTS）；
- `keyboardAssists` 表为空时从 `DefaultData` 播种 32 条辅助键盘条目；
- 建库时 `db.setLocale(Locale.CHINESE)`（API ≥ M）。

### 2.2 21 张实体表 + 1 个视图

| 表名 | 实体 | 主键 / 索引 | 说明 |
|---|---|---|---|
| `books` | `Book`(480行) | PK `bookUrl`；UNIQUE(`name`,`author`) | 书架书籍，含阅读进度、自定义信息 |
| `book_groups` | `BookGroup` | PK `groupId` | 分组；负数 id 为内置分组；`enableRefresh`/`show`/`bookSort`/`onlyUpdateRead` |
| `book_sources` | `BookSource`(314行) | PK `bookSourceUrl` | 书源，5 个规则字段用 TypeConverter 序列化为 JSON 文本 |
| `book_sources_part` | `BookSourcePart`（**@DatabaseView**） | — | 书源列表投影，避免列表页加载全部规则文本 |
| `chapters` | `BookChapter`(204行) | PK(`url`,`bookUrl`)；UNIQUE(`bookUrl`,`index`)；FK→books CASCADE | 目录 |
| `replace_rules` | `ReplaceRule`(120行) | PK `id` 自增 | 净化规则，`sortOrder` 列存 `order` |
| `searchBooks` | `SearchBook`(138行) | PK `bookUrl`；UNIQUE(`bookUrl`)；FK origin→book_sources CASCADE | 搜索结果缓存（临时） |
| `search_keywords` | `SearchKeyword` | PK `word` | 搜索历史 + 使用次数 |
| `cookies` | `Cookie` | PK `url` UNIQUE | 以二级域名为键 |
| `rssSources` | `RssSource`(214行) | PK `sourceUrl` | 订阅源（规则字段**全部内联**，无独立 RssRule 类） |
| `bookmarks` | `Bookmark` | PK `time`；IDX(`bookName`,`bookAuthor`) | 书签 |
| `rssArticles` | `RssArticle` | PK(`origin`,`link`,`sort`) | 订阅文章 |
| `rssReadRecords` | `RssReadRecord` | PK `record`(=link) | 已读记录，列表查询用 LEFT JOIN 标已读 |
| `rssStars` | `RssStar` | PK(`origin`,`link`)+starTime | 收藏 |
| `txtTocRules` | `TxtTocRule` | PK `id` | TXT 目录规则（id<0 为内置默认） |
| `readRecord` | `ReadRecord` | PK(`deviceId`,`bookName`) | 阅读时长统计（跨设备合并） |
| `httpTTS` | `HttpTTS`(97行) | PK `id` | 在线朗读引擎 |
| `caches` | `Cache` | PK `key` UNIQUE | KV 缓存的持久层（`value`+`deadline`） |
| `ruleSubs` | `RuleSub`(37行) | PK `id` 自增 | 规则订阅（type: 0书源/1订阅源/3替换规则） |
| `dictRules` | `DictRule`(56行) | PK `name` | 词典规则 |
| `keyboardAssists` | `KeyboardAssist` | PK(`type`,`key`) | 规则编辑辅助键盘 |
| `servers` | `Server`(56行) | PK `id` | WebDAV 服务器（`type=WEBDAV`，`config` 为 JSON） |

### 2.3 实体关系

```
BookSource ──origin(bookSourceUrl)──► SearchBook        [FK CASCADE]
Book       ◄──FK bookUrl CASCADE─── BookChapter         [1:N]
BookSource ──origin(bookSourceUrl)──► Book（逻辑外键，无 FK 约束）
BookGroup  ──group(位掩码 &)─────────► Book             [多对多，位运算]
RssSource  ──origin(sourceUrl)──────► RssArticle ──► RssStar / RssReadRecord
Server     ──config(serverID)───────► Book.origin = "webDav::<url>,{serverID}"
```

`Book.type` 与 `Book.group` 都是**位标志**（`constant/BookType.kt`：video=4、text=8、updateError=16、audio=32、image=64、webFile=128、local=256、archive=512、notShelf=1024；`group` 为 2^n）。书架列表查询完全基于位运算，例如 `BookDao.flowRoot()`：

```sql
select * from books where type & 8 > 0 and type & 256 = 0
and ((SELECT sum(groupId) FROM book_groups where groupId > 0) & `group`) = 0 ...
```
`BookDao.flowByGroup(groupId)` 用 `when(groupId)` 把负数组映射到 8 个专用流，并按 `isNotShelf` 过滤临时书。这是 Flutter 侧最容易写错的部分。

### 2.4 存储组织

```
内部存储
└─ filesDir/
   ├─ readConfig.json / shareReadConfig.json   ← ReadBookConfig（排版样式，可 zip 导出）
   ├─ themeConfig.json                         ← ThemeConfig
   ├─ coverRule.json                           ← BookCover 自定义规则
   └─ backup/                                  ← 本地备份 zip 落点
└─ shared_prefs/
   ├─ <pkg>_preferences.xml   ← defaultSharedPreferences（AppConfig 全部设置）
   ├─ local.xml               ← LocalConfig（密码、版本位、lastBackup）
   └─ SourceConfig.xml        ← SourceConfig（书源评分账本）
└─ (getExternalFilesDir)/
   ├─ book_cache/<folderName>/
   │  ├─ 00012-a1b2c3d4e5f6a7b8.nb    ← 章节正文，格式 "%05d-%s.nb" % (index, md5_16(title))
   │  ├─ 00012-a1b2c3d4e5f6a7b8.nr    ← 存在 = 关闭"去除重复标题"
   │  └─ images/<md5_16(src)>.<suffix> ← 正文图片
   ├─ epub/<originName>                ← 仅 getEpubFile 旧路径使用（现已废弃）
   ├─ covers/<md5_16(bookUrl)>.jpg     ← 仅本地书封面
   └─ tmp_backup.zip
└─ cacheDir/
   ├─ ACache/          ← ACache 磁盘 KV（默认 50MB，含 shareJs 子目录）
   ├─ httpTTS/         ← 朗读音频 LRU 128MB
   └─ ArchiveTemp/     ← 压缩包解压临时目录（启动时清理）
```

`folderName` 规则：`Book.getFolderNameNoCache()`（`help/book/BookExtensions.kt:293-297`）= 书名去 `[\\/:*?"<>|.]` 后取前 9 字 + `md5Encode16(bookUrl)`；`Book.getFolderName()` 把结果缓存在 `folderName` 字段（`Book.kt:350-357`）；换源/改名时 `BookHelp.updateCacheFolder(old,new)` 搬迁目录（`:76-91`）。

**关键：不存在 `index.json`、不存在 `cover.jpg`**（任务书假设有误）。章节清单完全来自 Room，封面走 Glide 磁盘缓存。

---

## 3. 阅读 / 抓取运行时（端到端）

这是整个 App 的核心，也是 Flutter 移植的最大工作量所在。下面按"搜索 → 详情 → 目录 → 正文 → 缓存 → 渲染"完整追踪。

### 3.1 搜索

**入口**：`ui/book/search/SearchActivity` + `SearchViewModel` → `model/webBook/SearchModel(scope, callBack)`。

```
SearchModel.search(searchId, key)                     SearchModel.kt:52-74
 ├─ searchId 变化 → close() 旧任务、清空 searchBooks、
 │   从 callBack.getSearchScope().getBookSourceParts() 取启用源
 ├─ initSearchPool(): Executors.newFixedThreadPool(min(threadCount, AppConst.MAX_THREAD))
 │                    .asCoroutineDispatcher()          SearchModel.kt:46-50
 └─ startSearch()                                        SearchModel.kt:76-114
      flow { for (bs in bookSourceParts) emit(bs.getBookSource()) }
        .onStart { callBack.onSearchStart() }
        .mapParallelSafe(threadCount) {                  ← flatMapMerge(n)+buffer(0)
            withTimeout(30_000L) { WebBook.searchBookAwait(it, searchKey, searchPage, filter) }
        }
        .onEach { appDb.searchBookDao.insert(*it); mergeItems(it, precision); callBack.onSearchSuccess() }
        .onCompletion { callBack.onSearchFinish(...) }
        .catch { AppLog.put("书源搜索出错...") }
```

`mergeItems`（`:116-197`）是**同名书合并算法**：按 `name==key || author==key` > `kind 含 key` > `name/author 含 key` > 其他 分四档，同档内 `(name,author)` 相同则 `addOrigin(origin)` 合并书源，各档按 `origins.size` 降序排列。`pause()/resume()` 通过 `workingState: MutableStateFlow<Boolean>` + `first{it}` 实现背压暂停。

**单源搜索** `WebBook.searchBookAwait`（`WebBook.kt:49-107`）：

```
1. 构造 AnalyzeUrl(mUrl=source.searchUrl, key, page, baseUrl=source.bookSourceUrl,
                  source, ruleData=RuleData, coroutineContext)     WebBook.kt:61-69
2. analyzeUrl.getStrResponseAwait()                                WebBook.kt:72
3. 若 bookSource.loginCheckJs 非空 → analyzeUrl.evalJS(checkJs, response) as StrResponse
   失败时构造 errResponse（HTTP 500）再跑一次 checkJs，仍失败才抛错         WebBook.kt:79-94
4. checkRedirect()  仅记录重定向日志                                 WebBook.kt:504-512
5. BookList.analyzeBookList(source, ruleData, analyzeUrl, baseUrl=res.url,
                            body=res.body, isSearch=true,
                            isRedirect=res.raw.priorResponse?.isRedirect==true, ...)
```

**列表解析** `BookList.analyzeBookList`（`BookList.kt:35-151`）：
1. `AnalyzeRule(ruleData, bookSource).setContent(body).setBaseUrl(baseUrl).setRedirectUrl(baseUrl)`；
2. 搜索分支：若 `bookSource.bookUrlPattern` 匹配 `baseUrl` → 说明搜索 URL 直接落到详情页 → `getInfoItem()` 走 `BookInfo.analyzeBookInfo` 并把 `infoHtml` 塞回 `SearchBook`（`BookList.kt:62-81`）；
3. `bookList` 规则字符串前缀 `-` = 结果倒序，前缀 `+` = 去空白（`:89-96`）；
4. `analyzeRule.getElements(ruleList)` 拿到条目集合；
5. 集合为空且无 `bookUrlPattern` → 也按详情页解析（`:100-108`）；
6. 否则逐条 `getSearchItem()`：`splitSourceRule` 预切 8 个子规则以减少重复解析，然后 `analyzeRule.setContent(item)` 后依次取 name/author/kind/wordCount/lastChapter/intro/coverUrl/bookUrl，每步都有独立 `try/catch` + `Debug.log`（`:119-141`）；`bookUrl == baseUrl` 时把 `body` 存入 `infoHtml` 复用；
7. `LinkedHashSet` 去重（依赖 `SearchBook.equals` = bookUrl 相同）+ 可选 reverse。

`BookHelp.formatBookName/formatBookAuthor` 做书名作者清洗（去"作者："等前后缀、去空白）。

### 3.2 加入书架与详情

搜索结果 `SearchBook.toBook()` 生成 `Book` → 书架 `bookDao.insert`（`Book.save()` 内部做 `has()? update : insert`）。

**详情** `WebBook.getBookInfoAwait`（`WebBook.kt:192-252`）：
- 优先复用 `book.infoHtml`（从搜索列表带过来的 HTML，避免二次请求）；
- 否则 `AnalyzeUrl(mUrl=book.bookUrl, baseUrl=source.bookSourceUrl, ruleData=book)` → `getStrResponseAwait()` → `BookInfo.analyzeBookInfo`。

`BookInfo.analyzeBookInfo`（`BookInfo.kt:48-176`）按 `BookInfoRule` 字段顺序解析：`init`（先执行一次元素级初始化并**替换 content**）→ name → author → kind（`getStringList` join）→ wordCount（`wordCountFormat`）→ lastChapter → intro（`<usehtml>/<md>/<useweb>` 前缀直通，否则 `HtmlFormatter.format`）→ coverUrl（`NetworkUtils.getAbsoluteURL(redirectUrl, …)`）→ 分支：`book.isWebFile ? downloadUrls : tocUrl`。
- `canReName` 语义：`mCanReName = canReName && !infoRule.canReName.isNullOrBlank()`，只有允许时才覆盖已有书名作者。
- `tocUrl == baseUrl` 时把 `body` 存入 `book.tocHtml`（详情页即目录页的站点省一次请求）。

### 3.3 目录

`WebBook.getChapterListAwait`（`WebBook.kt:284-351`）：

```
runCatching {
  if (runPerJs) runPreUpdateJs(source, book, isFromBookInfo)     ← 执行 ruleToc.preUpdateJs
  if (book.bookUrl == book.tocUrl && book.tocHtml 非空)
      BookChapterList.analyzeChapterList(..., body = book.tocHtml)
  else
      AnalyzeUrl(mUrl = book.tocUrl, baseUrl = book.bookUrl, ruleData = book)
        .getStrResponseAwait()  (+ loginCheckJs 双向校验)
      BookChapterList.analyzeChapterList(baseUrl=book.tocUrl, redirectUrl=res.url, body=res.body)
}.onFailure { currentCoroutineContext().ensureActive() }
```

`BookChapterList.analyzeChapterList`（`BookChapterList.kt:36-182`）是**目录分页 + 后处理**的中枢：

1. `chapterList` 规则前缀 `-` 反转、`+` 去空白（`:54-60`）；
2. 首屏解析 `analyzeChapterList(...)`（private 重载，`:184-303`）返回 `Pair<章节列表, nextTocUrl 列表>`；
3. **三种翻页策略**（`:68-120`）：
   - `nextTocUrl` 为空 → 结束；
   - 只有 1 个 → `while` 串行跟进（`nextUrlList` 防环），**并发受限**（注释明写"控制并发访问"）；
   - 多个 → `flow{...}.mapAsync(AppConfig.threadCount)` 并发抓取（`mapAsync` 保序）；
4. 空列表抛 `TocEmptyException`；
5. 去重 `LinkedHashSet`，按 `book.getReverseToc()` 决定是否 reverse（`:124-133`）；
6. `list.forEachIndexed { index, c -> c.index = index }`；
7. `tocRule.formatJs` 逐章执行 Rhino 脚本格式化标题，绑定 `gInt/index/chapter/title`（`:139-157`）；
8. 用 `ContentProcessor.get(book).getTitleReplaceRules()` 计算 `durChapterTitle`/`latestChapterTitle`；
9. 更新 `book.totalChapterNum/lastCheckCount/latestChapterTime/lastCheckTime`；
10. `upChapterInfo(list, book)`（`:305-325`）——当 `AppConfig.tocCountWords` 开启时，按 `"${index}_${title}"` 从旧表中回填 `wordCount/variable/imgUrl`（避免刷新目录丢字数）。

private 重载里逐条构造 `BookChapter(bookUrl, baseUrl=redirectUrl)`：
- `isVolume` 规则为真 → `isVolume=true`，`tag=info`（info 来自 updateTime 规则）；
- 否则按 `AppPattern.wordCountRegex` 从 info 中抽"字数"，剩余进 `tag`；
- `url` 为空：卷章用 `title+index` 占位，普通章用 `baseUrl` 占位；
- `isVip`/`isPay` 用 `isTrue()` 判定；
- 标题非空才入列。

### 3.4 正文

`WebBook.getContentAwait`（`WebBook.kt:379-455`）：

```
contentRule = source.getContentRule()
if (contentRule.content 为空) return bookChapter.url          ← 音/视频源：正文即链接
if (chapter.isVolume && chapter.url.startsWith(chapter.title)) return chapter.tag ?: ""
if (chapter.url == book.bookUrl && book.tocHtml 非空)
    BookContent.analyzeContent(..., body = book.tocHtml)
else
    AnalyzeUrl(mUrl = chapter.getAbsoluteURL(), baseUrl = book.tocUrl,
               ruleData = book, chapter = chapter)
      .getStrResponseAwait(jsStr = contentRule.webJs, sourceRegex = contentRule.sourceRegex)
    (+ loginCheckJs 双向校验)
    BookContent.analyzeContent(baseUrl=chapter.getAbsoluteURL(), redirectUrl=res.url, body=res.body)
```

`BookContent.analyzeContent`（`BookContent.kt:38-211`）：

1. 计算 `mNextChapterUrl`（未传入则查 DAO：`index+1`，越界回落到 `index 0`）；
2. 首屏 `analyzeContent(...)` private 重载取正文 + `nextContentUrl`；
3. `nextContentUrl` **单值** → `while` 串行翻页，遇 `mNextChapterUrl` 相同则 `break`（防止把下一章当成本章续页）；`nextUrlList` 防环；
4. `nextContentUrl` **多值** → `mapAsync(AppConfig.threadCount)` 并发取，结果按序 `contentList.add`；
5. `subContent`（副文规则）：`book.isOnLineTxt` 直接追加；否则若以 `http` 开头则再发一次请求；音频书 → `chapter.putLyric()`，视频书 → `chapter.putDanmaku()`；
6. `contentList.joinToString("\n")` 后应用 `contentRule.replaceRegex`（全书替换，逐行 trim；在线 TXT 再加全角缩进）；
7. `contentRule.title` 规则可在正文里反查标题，并用 `AppPattern.imgRegex` 从标题尾部抽出 `imgUrl`（段评图标）→ `chapter.title = title; chapter.titleMD5 = null; chapter.update()`；
8. 非卷章且内容空白 → 抛 `ContentEmptyException`；
9. `needSave` 时 `BookHelp.saveContent(source, book, chapter, contentStr)`。

private 重载（`:214-264`）的正文规格化顺序（移植时必须逐字对齐）：
```
content = analyzeRule.getString(contentRule.content, unescape = false)
if (!book.isAudio && !book.isVideo) {
    if (AppConfig.adaptSpecialStyle)  提取 <usehtml>...</usehtml> 为占位符 {usehtml_N}
    content = HtmlFormatter.formatKeepImg(content, redirectUrl)
    if (content 含 '&') content = StringEscapeUtils.unescapeHtml4(content)
    还原 usehtml 占位符
}
if (getNextPageUrl) nextUrlList = analyzeRule.getStringList(contentRule.nextContentUrl, isUrl = true)
```

### 3.5 缓存与阅读会话

**写路径**：`BookHelp.saveContent` → `saveText` → 写入 `book_cache/<folder>/<00012-md5.nb>` → `postEvent(EventBus.SAVE_CONTENT, (book, chapter))`。图片由 `BookHelp.saveImages` 在需要时按需下载（`flowImages(...).onEachParallel(threadCount)`，URL→`ConcurrentHashMap<String, Mutex>` 同图去重，`BitmapFactory` 校验宽高、坏图删除）。

**读路径**（`model/ReadBook.kt`，1064 行）：`ReadBook` 是 `object ReadBook : CoroutineScope by MainScope()`，持有 `book/curTextChapter/prevTextChapter/nextTextChapter/bookSource/callBack`。

```
ReadBook.loadContent(index, upContent, resetPageOffset, success)     ReadBook.kt:568-596
 └─ Coroutine.async {
      chapter = appDb.bookChapterDao.getChapter(bookUrl, index) ?: return
      if (addLoading(index)) {                        ← @Synchronized + loadingChapters 去重
          BookHelp.getContent(book, chapter)          ← 命中磁盘缓存
            ?.let { contentLoadFinish(book, chapter, it, ...) }
            ?: download(downloadScope, chapter, resetPageOffset)     ← 未命中
      }
    }
```

- 预取策略：`loadContent(resetPageOffset)`（无 index 重载，`:534-543`）同时加载 `dur-1 / dur / dur+1` 三章；
- `preDownload()`（`:938-967`）在翻页后（`curPageChanged` 调用）用 `AppConfig.preDownloadNum`（默认 2）向后预下载 `dur+2..min(dur+num, chapterSize)`、向前 `dur-2 downTo dur-min(5,num)`，并发受 `preDownloadSemaphore = Semaphore(2)` 限制，失败 3 次以上跳过；
- 下载经 `CacheBook.getOrCreate(bookSource, book).download(scope, chapter, semaphore)`（`CacheBook.kt:406-441`）；
- 内容就绪后 `contentLoadFinish`（`:692-783`）：
  `ContentProcessor.getContent(...)`（净化）→ `ChapterProvider.getTextChapterAsync(...)`（异步排版，返回 `TextChapter`）→ 按 `offset = chapter.index - durChapterIndex` 落到 `cur/prev/nextTextChapter` → 遍历 `textChapter.layoutChannel` 回调 `callBack.upContent(offset, resetPageOffset)` / `onLayoutPageCompleted(pageIndex, page)`；每个 index 一个 `Coroutine` 存于 `chapterLoadingJobs: ConcurrentHashMap<Int, Coroutine<*>>`，翻页时 `clearExpiredChapterLoadingJob()` 取消 ±1 之外的排版任务；
- 进度保存 `saveRead()`（`:908-933`）走 `globalExecutor`，同时 `SourceCallBack.callBackBook(SAVE_READ, ...)` 触发书源回调；
- 目录续更 `upToc()`（`:870-894`）：当 `chapterSize - durChapterIndex - 1 < 3` 且距 `lastCheckTime` 超 10 分钟时重新拉目录，新增章节则 `bookDao.replace(old,new)` + `BookHelp.updateCacheFolder` + `bookChapterDao.delByBook` + 重插。

### 3.6 批量下载（离线缓存）

`model/CacheBook.kt`（460 行）：`object CacheBook` 持有 `cacheBookMap: ConcurrentHashMap<String, CacheBookModel>`。

- `startProcessJob(context)`（`:127-154`）：`mutex.withLock` + `flow` 轮询所有 `CacheBookModel`，`onEachParallel(AppConfig.threadCount)` 并发下载；`workingState: MutableStateFlow<Boolean>` 支持暂停；
- `CacheBookModel` 状态机（`:193-458`）：`waitDownloadSet` / `onDownloadSet` 两个 `LinkedHashSet`，跳过 `isVolume`、跳过已有图片内容（改为只下图片）、失败 `delay(1000)` 后重入且**最多 3 次**（`ConcurrentException` 不计入失败数）；
- 进度经 `EventBus.UP_DOWNLOAD`（单本）与 `UP_DOWNLOAD_STATE`（全局）广播，`downloadSummary` = `"正在下载:N|等待中:N|失败:N|成功:N"`；
- 承载服务 `service/CacheBookService`：线程池 `min(AppConfig.threadCount, AppConst.MAX_THREAD=9)`，下载完成即 `stopSelf()`，不驻留后台。

`model/Download.kt` 只有 18 行，是转交 `DownloadService`（系统 `DownloadManager`）的薄封装。

### 3.7 规则引擎内部（§3 的"发动机"）

**`AnalyzeUrl`（978 行）** 负责把规则 URL 变成 HTTP 请求：

1. `initUrl()`（`:149-157`）：`analyzeJs()` → `replaceKeyPageJs()` → `analyzeUrl()`；
2. `analyzeJs()`（`:162-185`）：先用 `AppPattern.JS_PATTERN`（`<js>...</js>|@js:...`）逐段求值，`@result` 占位符接续上一步结果；
3. `replaceKeyPageJs()`（`:190-217`）：`RuleAnalyzer.innerRule("{{","}}")` 替换所有内嵌 JS；再把 `<a,b,c>` 形式的 page 模板按 `page` 取第 n 项或末项（`:206-216`）；
4. `analyzeUrl()`（`:222-286`）：`paramPattern = \s*,\s*(?=\{)` 把 URL 与 `,{...}` 选项分离；`NetworkUtils.getAbsoluteURL(baseUrl, urlNoOption)` 补全；选项反序列化为 `UrlOption`（字段见 `:780-957`：method/charset/headers/body/origin/retry/type/webView/webJs/dnsIp/js/bodyJs/serverID/webViewDelayTime），先试 `GSONStrict` 再退回 `GSON` 并告警"链接参数 JSON 格式不规范"；GET 走 `analyzeQuery`、POST 走 `analyzeFields`，`encodeParams`（`:302-350`）逐键值判断是否已编码（`NetworkUtils.encodedForm`）再用 `URLEncoder` 或 `EncoderUtils.escape`；
5. `getStrResponseAwait(jsStr, sourceRegex, useWebView, isTest, skipRateLimit)`（`:417-433`）：`type != null` 直接返回 hex（音频/视频源）；否则 `concurrentRateLimiter.withLimit { executeStrRequest(...) }`；
6. `executeStrRequest`（`:435-537`）：`setCookie()` → 三条分支：
   - `useWebView`（URL 选项 `webView:true`）→ POST 先用 OkHttp 拿 `res`，再把 `res.body` 交给 `BackstageWebView`（隐藏 WebView）；GET 直接 `BackstageWebView`；
   - 普通 POST（form / json / 显式 Content-Type）与 GET/HEAD；
   - XML 内容类型但 body 不以 `<?xml` 开头时补声明；`bodyJs` 存在则对 body 二次 JS 处理；
   `isTest=true` 时把异常转成错误码（-1 超时 / -2 SocketTimeout / -3 UnknownHost / -4 Connect / -5 Socket / -6 SSL / -7 其他）写入 `StrResponse.callTime`。

**`AnalyzeRule`（973 行）** 是规则求值核心：

- `splitSourceRule(ruleStr, allInOne)`（`:531-574`）：先按 `JS_PATTERN` 切出 `Mode.Js` 片段，再按 `WebJS_PATTERN`（`@webjs:...`）切出 `Mode.WebJs`，剩余段落按 `Mode.Default`；首字符 `:` 表示整串按正则（`Mode.Regex`）；
- 内部类 `SourceRule`（`:585-785`）：构造时按前缀判定模式（`@CSS:`→Default、`@@`→Default 且去前缀、`@XPath:`→XPath、`@Json:`→Json、`$.`/`$[`→Json、`/`→XPath、`isJSON`→Json），然后：
  - `splitPutRule()` 抽出 `@put:{...}`（`:454-477`，先严格 JSON 后宽松 JSON，宽松时告警）；
  - `evalPattern = @get:\{[^}]+?\}|\{\{[\w\W]*?\}\}`（`:947`）拆出 `@get:`（从变量池取）与 `{{js}}`（`isRule()` 判定是规则还是 JS）；
  - `splitRegex()` 拆出 `$1..$99` 分组引用；
  - `makeUpRule(result)`（`:714-773`）用分组引用/JS 结果/@get 值回填规则字符串，再按 `##` 切成 `rule / replaceRegex / replacement / replaceFirst`（4 段即 `##match##replace###` 的"取第一个匹配"语义）；
- `getString / getStringList / getElement / getElements` 四个求值入口，分派到：
  - `Mode.Js` → `evalJS(rule, result)`
  - `Mode.WebJs` → `getWebJsResult(rule, result)`（强制后台线程，`BackstageWebView` + 10s 超时，`cacheFirst = true`）
  - `Mode.Json` → `AnalyzeByJSonPath`
  - `Mode.XPath` → `AnalyzeByXPath`
  - `Mode.Default` → `AnalyzeByJSoup`
  - `Mode.Regex` → `AnalyzeByRegex`
- 缓存：`stringRuleCache`（规则串→SourceRule 列表）、`regexCache`（`getOrPutLimit(regex, 16)`）、`scriptCache`（编译后的 Rhino 脚本，`getOrPutLimit(jsStr, 16)`）；
- 变量池 `put/get`（`:794-823`）优先级：`chapter > book > ruleData > source`；特例 `bookName`/`title` 直通；
- `evalJS`（`:828-859`）构造 bindings：`java`(=AnalyzeRule 自身)、`cookie`、`cache`、`source`、`book`、`result`、`baseUrl`、`chapter`、`title`、`src`、`nextChapterUrl`、`rssArticle`、`fromBookInfo`；作用域优先取 `source.getShareScope(coroutineContext)`（jsLib 共享作用域），否则新建，并在调用 >16 次后把 `prototype` 存入 `WeakReference` 做复用；
- `reGetBook()` / `refreshTocUrl()`（`:904-943`）：**只能在 `preUpdateJs` 中调用**，内部 `runBlocking(coroutineContext) { withTimeout(1800000) { ... } }`。

**`RuleAnalyzer`（378 行）** 是"不用正则、只在序列上标记首尾、最后才切片"的手写切分器，专门解决规则中含 `&&`/`||`/`%%`/`@`/`{`/`}` 的冲突：
- `splitRule("&&","||","%%")` 用 `tailrec` + `consumeToAny` + `findToAny('[','(')` 跳过选择器/筛选器内部的分隔符；`elementsType` 记录实际命中的分隔符（决定 `results` 是取首命中还是 zip 交错）；
- `chompCodeBalanced('{','}')`（代码平衡：处理 `[...]` 嵌套、单双引号、`\` 转义）与 `chompRuleBalanced`（规则平衡：引号内不转义），由构造函数 `code: Boolean` 选择；
- `innerRule("{{","}}") { ... }` 用于 `AnalyzeUrl` 的内嵌 JS 替换，`innerRule("{$.")` 用于 JSONPath 嵌套规则。

**四种解析后端**：
- `AnalyzeByJSoup`（524 行）：支持 `&& / || / %%` 组合、`SourceRule.elementsRule` 空则取 `element.data()`；末级规则 `@text`/`@textNodes`/`@ownText`/`@html`（先删 script/style）/`@all` 或任意属性名（`@href`、`@src`…）；`ElementsSingle` 支持 `tag.div.-1:10:2` 旧式索引与 `tag.div[-1, 3:-2:-10, 2]` 新式区间（负数、反向 `[-1:0]`、`!` 排除）；
- `AnalyzeByXPath`（155 行）：用 JsoupXpath 的 `JXDocument`；对以 `</td>`/`</tr>`/`</tbody>` 结尾的片段自动包 `<tr>`/`<table>` 修复；同样支持 `&& / || / %%`；
- `AnalyzeByJSonPath`（172 行）：`RuleAnalyzer(rule, code=true)` 解决 JSONPath 自身的 `&&`/`||` 与规则冲突；`innerRule("{$.")` 支持 `{$.rule}` 嵌套；
- `AnalyzeByRegex`（59 行）：`&&` 分隔多级正则，逐级用 `Pattern.find()` 拼接结果，末级返回 `group(0..groupCount)` 列表；
- `QueryTTF.java`（1055 行）：字体字形（glyf）解析，配合 `java.queryTTF` / `java.replaceFont` 破解"字体混淆"反爬（原理：用错误字体的 glyf 数据在正确字体中反查 unicode）。

---

## 4. 本地书籍格式

分发逻辑在 `model/localBook/LocalBook.kt`（528 行）+ `help/book/BookExtensions.kt:47-75` 的 `isLocalTxt/isEpub/isUmd/isPdf/isMobi` 后缀判定（`.mobi/.azw3/.azw` 归 mobi），未命中回落 `TextFile`。抽象接口 `BaseLocalBookParse`（`BaseLocalBookParse.kt:9-21`）只有 `upBookInfo / getChapterList / getContent / getImage` 四个方法，各格式以 `companion object` 实现。

| 格式 | 实现 | 依赖 | 目录来源 | 正文形态 |
|---|---|---|---|---|
| TXT | `TextFile.kt`（623 行） | 无（手写） | `TxtTocRule` 正则 + 用户交互 | **纯文本**（非 HTML） |
| EPUB | `EpubFile.kt`（480 行） | `modules/book` 的 `me.ag2s.epublib` fork | NCX/nav `tocReferences`，空则 `spine` | HTML（Jsoup 清洗） |
| MOBI/AZW3 | `MobiFile.kt`（318 行） | `lib/mobi`（自研纯 Kotlin，34 文件） | INDX/TAGX（KF6）或 NCX+FDST/SKEL/FRAG（KF8） | HTML |
| UMD | `UmdFile.kt`（122 行） | `modules/book` 的 `me.ag2s.umdlib` | `chapters.titles` index 序列 | 纯文本；**不支持图片** |
| PDF | `PdfFile.kt`（229 行） | 系统 `android.graphics.pdf.PdfRenderer` | 每 10 页一章，标题 `分段_i` | 伪 HTML（每页若干 `<img src="N">`） |

### 4.1 TXT 的关键算法

- **编码探测**：读首块 512,000 字节 → `EncodingDetect.getEncode(bytes)`（`lib/icu4j` 的 `CharsetDetector`）→ 写回 `book.charset`。
- **目录规则自动选择** `getTocRule(content)`（`:497`）：遍历 `txtTocRuleDao.enabled`（`assets/defaultData/txtTocRule.json` 内置 26 条），逐条 `Pattern.MULTILINE` 匹配后统计命中数 `csNum` 与"间隔<100 字"的误判数 `numE`，要求 `csNum >= numE*3 && csNum > maxNum + 2`，`maxNum > 70` 提前 break。胜出规则 + replacement JS **编码进 `book.tocUrl`**，分隔符为魔数字符串 `spaceChars = "🫅🈳🏻"`。
- **分章** `analyze(rr)`（`:159`）：按 512KB 块流式扫描（`Utf8BomUtils.hasBom` 跳过 BOM），记录字节偏移 `start/end`；块首残余 → "前言"章；上一章残余 → 追加到上一章 `end`；两匹配间为空 → 上一章标 `isVolume=true`。`replacement` 走 Rhino（绑定 `result/book/index/prevTitle/prevLength/lastVolumeTitle` 与 `java`（提供 `putVolume(title)`）），**JS 返回空串即丢弃该匹配**。超长章（`maxLengthWithToc = 102400` 字节，受 `Book.getSplitLongChapter()` 控制）递归拆分，子章标题 `"$lastTitle(n)"`。
- **无规则**（`:394`）：按 `maxLengthWithNoToc = 10KB` 切块并回退到 `0x0a` 换行处，标题 `第{blockPos}章({chapterPos})`。
- **正文** `getContent`（`:118`）：8MB 滑动窗口（`txtBufferSize`），跨窗口边界时重新 open + skip；`replace(padRegex, "　　")`；**TXT 正文不进缓存**（`BookHelp.hasContent` 对本地 TXT 恒为 true）。

### 4.2 EPUB 的关键点

- 读取走 `BookHelp.getBookPFD(book)` → `AndroidZipFile(pfd, originName)` → `EpubReader().readEpubLazy(zipFile, "utf-8")`，**不再拷贝到 `epub/` 目录**（`BookHelp.getEpubFile` 已废弃）。持有 `ParcelFileDescriptor` 防 GC。
- `AndroidZipFile` 是 fork 的核心改造：把原版 `RandomAccessFile` 换成 `ParcelFileDescriptor`，用 `me.ag2s.base.PfdHelper`（`android.system.Os.lseek/read/fstat`）实现 `read/seek/length`。这是 `modules/book` 必须是 android-library 的唯一技术原因。
- 目录：`tocReferences` 递归（有子节点则父章 `isVolume`），串联 `startFragmentId`/`endFragmentId`，并 `putVariable("nextUrl", ...)`。
- 正文：靠 fragmentId 在**同一 xhtml 内**截取（`getBody` 先 `Jsoup.parse` 修复不规范 XHTML，再用 `getElementById(id).outerHtml().substringBefore("\n")` 求截断点再重新 parse）；清理 `title`、`[style*=display:none]`、重复 `img[src=cover.jpeg]`、`<image xlink:href>`→`<img src>`、相对 src 绝对化；`Book.rubyTag`/`hTag` 位标志控制是否拆 ruby / 删 h1-h6。

### 4.3 导入与压缩包

- `LocalBook.importFile(uri)`（`:241`）：`FileDoc.fromUri` 取 size/lastModified，size==0 抛 `EmptyFileException`；**已存在同 bookUrl 即"重导入=更新"**（`deleteBook(book,false)` + `latestChapterTime=0` + `bookChapterDao.delByBook`）；新建 `Book(type = BookType.text or BookType.local)`。
- 书名作者 `analyzeNameAuthor`（`:347`）：优先执行用户脚本 `AppConfig.bookImportFileName`（Rhino 注入 `src`，末尾拼 `JSON.stringify({author,name})` 回读），失败退回 4 条正则。
- `importArchiveFile`（`:284`）：`ArchiveUtils.deCompress` + `AppPattern.bookFileRegex`（`.*\.(txt|epub|umd|pdf|mobi|azw3|azw)`），成功后 `origin = "loc_book::<包名>"` 并 `addType(BookType.archive)`。
- `saveBookFile`（`:433`）强依赖 `AppConfig.defaultBookTreeUri`，缺失抛 `NoBooksDirException`（`exception/NoBooksDirException.kt:6`）；权限失败抛 `SecurityException`。`InvalidBooksDirException` 只在 `ui/association/FileAssociationActivity.kt:158/168/182` 抛出、`:201` 捕获后重开目录选择器。
- 压缩包解压走 `me.zhanghai.android.libarchive`（`utils/compress/LibArchiveUtils.kt`），临时目录 `externalCache/ArchiveTemp`，启动时由 `BookHelp.clearInvalidCache()` 清理。

---

## 5. 平台 / 系统集成

### 5.1 AndroidManifest 要点

`app/src/main/AndroidManifest.xml`：

- **权限**（5-23）：INTERNET、WAKE_LOCK、ACCESS_NETWORK_STATE、FOREGROUND_SERVICE(+MEDIA_PLAYBACK/DATA_SYNC)、POST_NOTIFICATIONS、REQUEST_IGNORE_BATTERY_OPTIMIZATIONS、MANAGE_EXTERNAL_STORAGE、REQUEST_INSTALL_PACKAGES、SYSTEM_ALERT_WINDOW（仅视频悬浮窗）、READ/WRITE_EXTERNAL_STORAGE。
- **53 个 Activity**，全部独立注册（多 Activity 架构）：
  - `WelcomeActivity` 为 LAUNCHER；`Launcher1`–`Launcher7` 全部 `enabled="false"`，由 `help/LauncherIconHelp.kt:22-64` 用 `setComponentEnabledSetting` 动态启停实现换图标；
  - `MainActivity`/`ReadBookActivity` 均 `singleTask`；
  - `ReadBookActivity`/`ReadMangaActivity` 注册三星 S Pen 遥控 `com.samsung.android.support.REMOTE_ACTION` + `@xml/spen_remote_actions`（翻页映射 PAGE_DOWN/PAGE_UP，`:142-163`）；
  - `SharedReceiverActivity`：PROCESS_TEXT + SEND `text/plain`（划词/分享导入，`:341-360`）；
  - `OnLineImportActivity`：`legado://` + `yuedu://` BROWSABLE（`:362-376`），格式 `legado://import/{path}?src={url}`；
  - `FileAssociationActivity`：mimeType 与 `pathAdvancedPattern` **双保险**覆盖 txt/json/epub/pdf/mobi/azw/azw3/zip/rar/7z（`:388-476`）。
- **9 个 Service**（`:478-516`）：CheckSource/CacheBook/ExportBook/Web/WebTile/Download 为 `foregroundServiceType="dataSync"`；TTSReadAloud/HttpReadAloud/AudioPlay/VideoPlay 为 `mediaPlayback`。`WebTileService` 另带 `BIND_QUICK_SETTINGS_TILE` + `QS_TILE` intent-filter。
- **Receiver**：仅 `MediaButtonReceiver`（`MEDIA_BUTTON`）。
- **Provider**：`ReaderProvider`（`${applicationId}.readerProvider`，`exported="true"`，**无权限保护**）+ `FileProvider`。
- **`<queries>`**：VIEW、`TTS_SERVICE`、PROCESS_TEXT。

### 5.2 服务层

`base/BaseService.kt` 继承 `LifecycleService`：`onStartCommand` 首次进入即 `startForegroundNotification()`（`:46-55`）；`onTimeout`/`onTaskRemoved` 一律 `stopSelf()`；`onCreate` 申请通知权限 + 忽略电池优化。通知渠道在 `AppConst.kt:19-21`（`channel_download`/`channel_read_aloud`/`channel_web`），由 `App.kt:178-220` 创建，全部 IMPORTANCE_DEFAULT、无声振动、锁屏可见。`NotificationId.kt`：ReadAloud=101、AudioPlay=102、CacheBook=103、ExportBookService=104、Web=105、Download=106、CheckSource=107、VideoPlay=108。

| Service | 职责 | 关键实现 |
|---|---|---|
| `CacheBookService` | 批量离线缓存 | 线程池 `min(threadCount, 9)`；1 秒轮询刷新通知；下载完 `stopSelf()` 不驻留 |
| `DownloadService` | 单文件下载 | 走系统 `DownloadManager`（VISIBILITY_HIDDEN）+ 自绘进度通知分组；`ACTION_DOWNLOAD_COMPLETE` + 1 秒 `queryState()` 轮询 |
| `CheckSourceService` | 书源校验 | `onEachParallel(threadCount)` + `withTimeout(CheckSource.timeout)`；失败按"校验超时/js失效/网站失效/域名失效/搜索失效/发现失效"打组；`onDestroy` 发 `CHECK_SOURCE_DONE`。**注意其通知误用 `channelIdReadAloud` 渠道**（`:66`） |
| `ExportBookService` | 导出 TXT/EPUB | `waitExportBooks` linkedMap 串行队列；EPUB 走 `me.ag2s.epublib` 的 `EpubWriter`；可选 `AppWebDav.exportWebDav` 上传 |
| `WebService` | 内置 HTTP/WS 服务 | 见 §5.4 |
| `AudioPlayService` | 有声书播放 | ExoPlayer + `MediaSessionCompat("readAloud")`，`MediaStyle` 通知；静态 `isRun/pause` 供 MediaButton 查询 |
| `VideoPlayService` | 视频播放 | ExoPlayer/GSYVideoPlayer + 悬浮窗（`SYSTEM_ALERT_WINDOW`） |
| `BaseReadAloudService` | 朗读基类 | 见 §5.3 |
| `TTSReadAloudService` | 系统 TTS | `android.speech.tts.TextToSpeech` |
| `HttpReadAloudService` | 在线 TTS | ExoPlayer + `SimpleCache` LRU 128MB |

### 5.3 朗读子系统

- **引擎选择**（`model/ReadAloud.kt:24-39`）：读 `ReadBook.book.getTtsEngine() ?: AppConfig.ttsEngine`；为空 → `TTSReadAloudService`；为纯数字 → 按 id 查 `httpTTS` 表，命中 → `HttpReadAloudService`；否则系统 TTS。`ReadAloud` 全部控制方法都是 `startForegroundServiceCompat(Intent(context, aloudClass)) + IntentAction`（play/pause/resume/prevParagraph/nextParagraph/setTimer/upTtsSpeechRate），`play` 额外带 `pageIndex`/`startPos`。
- **断句粒度是"段落"而非"句子"**：`BaseReadAloudService.newReadAloud()`（`:232-275`）取 `ReadBook.curTextChapter`（必须 `isCompleted`），
  `contentList = getNeedReadAloud(0, readAloudByPage, 0).split("\n").filter { it.isNotEmpty() }`，
  `nowSpeak` 为段索引、`readAloudNumber`/`paragraphStartPos` 为章内字符偏移；`AppPattern.notReadAloudRegex`（`^(\\s|\\p{C}|\\p{P}|\\p{Z}|\\p{S})+$`）过滤纯标点/空白段。
- **状态机**：`isRun/pause/timeMinute` 为静态；状态常量在 `constant/Status.kt`（STOP=0/PLAY=1/PAUSE=3），经 `postEvent(EventBus.ALOUD_STATE, ...)` 广播；`EventBus.TTS_PROGRESS` 上报字符位置。
- **音频焦点与媒体会话**：`MediaHelp.buildAudioFocusRequestCompat`（USAGE_MEDIA/CONTENT_TYPE_MUSIC）；请求失败即 `pauseReadAloud(false)`；`MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or FLAG_HANDLES_TRANSPORT_CONTROLS`，回调含 onPlay/onPause/onSkipToNext/onSkipToPrevious/onStop、自定义 `addTimer` 动作与 `onMediaButtonEvent`；通知为 `MediaStyle` + 5 个按钮（上一章/播放暂停/下一章/停止/定时）。
- **翻页联动**：`nextP()/prevP()` 跨页时直接调 `ReadBook.moveToNextPage()/moveToPrevPage()`；UI 侧 `ReadBookActivity` 监听 `ALOUD_STATE`（暂停/停止时清除页内高亮 span）与 `TTS_PROGRESS`（更新 `durChapterPos` 并高亮当前段），实现"朗读自动滚动 + 高亮"。
- **耳机键**：`receiver/MediaButtonReceiver.kt` 处理 PREVIOUS/NEXT 依据 `AppConfig.mediaButtonPerNext` 决定翻章还是前后段，其余键切换播放；`help/MediaHelp.playSilentSound()` 播放静音音频以"欺骗系统下放媒体键"。
- **HTTP TTS**：`HttpReadAloudService` 逐段 `AnalyzeUrl(httpTts.url, speakText=..., speakSpeed=..., source=httpTts)`；校验响应 `Content-Type`；连续 5 次错误自动暂停；音频缓存于 `cacheDir/httpTTS/{章节标题MD5}_{(url|speed|文本)MD5}.mp3`（`:421-424`）；失败或无文本写 `R.raw.silent_sound` 占位；`AppConfig.streamReadAloudAudio` 切换流式播放。

### 5.4 内置 Web 服务（远程改书源 / 远程控制）

- `WebService`（`:147-183`）：`getPort()` 读 `PreferKey.webPort`（默认 **1122**，越界回落），启动 `HttpServer(port)` 与 `WebSocketServer(port + 1)`，WS 超时 30 秒；可选 `PARTIAL_WAKE_LOCK` + `WIFI_MODE_FULL_HIGH_PERF`；`NetworkChangedListener` 回调重建 IP 列表并 `postEvent(EventBus.WEB_SERVICE, hostAddress)`；通知点击复制地址、带"取消"按钮。
- `web/HttpServer.kt`（152 行）：`class HttpServer(port: Int) : NanoHTTPD(port)`。**每个请求先 `WebService.serve()` 唤起服务**（`:26`），然后：
  - OPTIONS → CORS 预检（`Access-Control-Allow-Methods: POST`、回显 origin）；
  - **16 个 POST 路由**（`:54-70`）：`/saveBookSource(s)`、`/deleteBookSources`、`/saveBook`、`/deleteBook`、`/saveBookProgress`、`/addLocalBook`、`/saveReadConfig`、`/saveRssSource(s)`、`/deleteRssSources`、`/saveReplaceRule`、`/deleteReplaceRule`、`/testReplaceRule`；
  - **13 个 GET 路由**（`:77-91`）：`/getBookSource(s)`、`/getBookshelf`、`/getChapterList`、`/refreshToc`、`/getBookContent`、`/cover`、`/image`、`/getReadConfig`、`/getRssSource(s)`、`/getReplaceRules`；
  - 未命中 → `AssetsWeb("web")` 提供 `app/src/main/assets/web/` 静态资源（URI 以 `/` 结尾自动补 `index.html`）；
  - 列表长度 > 3000 时用 `okio.Pipe` + `Coroutine.async` **流式输出 JSON**；`ReturnData.data is Bitmap` 时输出 PNG（`/cover`、`/image` 用）。
- `web/utils/AssetsWeb.kt`：`assetManager.open("web" + path)` + 按扩展名给 MIME（html/htm/js/css/ico/jpg，其余默认 `text/html`）。
- `web/WebSocketServer.kt`（24 行，NanoWSD）只路由 3 个端点：`/bookSourceDebug`、`/rssSourceDebug`、`/searchBook`。
- `web/socket/BookSourceDebugWebSocket.kt` 实现 `Debug.Callback`：30 秒 ping 保活；收到 `{tag, key}` JSON 后 `Debug.callback = this; Debug.startDebug(this, source, key)`；`printLog(state, msg)` 把调试日志逐条推给浏览器（state ∈ {10,20,30,40} 的原始 HTML 不下发），state == -1/1000 时结束调试并关闭。
- 静态前端：`assets/web/`（Vue 打包的 `index.html`/`assets/js/dist.js`、`vue/index.html`、`uploadBook/index.html`、`help/` 离线帮助文档）。
- UI 入口：`ui/main/my/MyFragment.kt:98-137`（显示地址、启停）、`ui/config/OtherConfigFragment.kt:188-190`（开关后重启服务）。

### 5.5 Content Provider API

`api/ReaderProvider.kt`（163 行）：authority `${applicationId}.readerProvider`，18 条 URI（`:30-51`）。`insert` 只读 `ContentValues("json")` 并 `runBlocking` 调 Controller；`query` 从 `url`/`index`/`path` 参数构造 map，返回 `MatrixCursor(arrayOf("result"))` 单行，内容是 `Gson().toJson(ReturnData)`（`SimpleCursor`，`:155-163`）；`delete` 只支持 `bookSources/delete`/`rssSources/delete`，**且 rss 分支错误地调用了 `BookSourceController.deleteSources`**（`:68`）；`onCreate()` 的副作用是构建动态快捷方式 `ShortCuts.buildShortCuts()`。

`api/controller/` 四个 Controller 同时服务 HTTP 与 Provider，返回统一 `api/ReturnData.kt`（`isSuccess`/`errorMsg`/`data`）。

### 5.6 WebDAV / 备份 / 恢复

- `help/AppWebDav.kt` 单例，默认服务器 `https://dav.jianguoyun.com/dav/`（坚果云），根目录 = `web_dav_url` + `AppConfig.webDavDir`（默认 `"legado"`），下设 `bookProgress/`、`books/`、`background/`。
- 传输层 `lib/webdav/WebDav.kt` 是**手写 OkHttp**（PROPFIND Depth 0/1、MKCOL、PUT、DELETE、Basic Auth），`callTimeout(0)` 永不超时。
- **备份**：`help/storage/Backup.kt`（315 行）导出 **23 个文件**：14 张表的 JSON（bookshelf/bookmark/bookGroup/bookSource/rssSources/rssStar/replaceRule/readRecord/searchHistory/sourceSub/txtTocRule/httpTTS/keyboardAssists/dictRule）+ `servers.json` + `readConfig.json`/`shareReadConfig.json`/`themeConfig.json`/`coverRule.json` + `config.xml`/`videoConfig.xml`，用 `ZipUtils.zipFiles` 打**普通 ZIP**。AES（`help/storage/BackupAES.kt`，8 行）只加密 `servers.json` 与 prefs 里的 `webDavPassword`，密钥 = `MD5(LocalConfig.password)` 前 16 字节（即 AES/ECB/PKCS5 + Base64，**无 IV/盐**；未设密码时密钥退化为常量 `d41d8cd98f00b204`，仅为混淆）。文件名 `backup_yyyy-MM-dd[-设备名].zip`，`onlyLatestBackup` 时本地固定 `backup.zip`，但**远端始终用带日期名**（两端可能不同名）。
- **恢复**：`Restore.kt`（330 行），`servers.json`/`webDavPassword` 用"能解密就解密，否则当明文"的容错写法；无版本协商，仅当 `bookSource.json` 非数组时回退 `ImportOldData.importOldSource`（迁 2.x 数据，含 `@Header:{}`/`{{}}` 旧语法改写）；书籍按 `bookUrl` 存在则 update 否则 insert，其余表 `OnConflictStrategy.REPLACE`，`readRecord` 按 `(deviceId, bookName)` 主键做跨设备合并。
- **进度同步**：本地 `durChapterIndex/durChapterPos/durChapterTime/syncTime`；上传 `AppWebDav.uploadBookProgress`；启动时 `downloadAllBookProgress`，冲突规则是**"读得更远者胜"**（`ReadBook.kt:265-282`）；`autoCheckNewBackup` 默认 true，`MainActivity` 检测到更新备份会提示恢复。
- **远程书**：`model/remote/RemoteBook.kt` / `RemoteBookManager`（抽象 list/get/download/upload/delete）/ `RemoteBookWebDav.kt`；标识 `Book.origin = "webDav::<url>,{serverID}"`，`BookType.webDavTag = "webDav::"`；本地文件缺失时 `LocalBook.getBookInputStream` 会尝试 `downloadRemoteBook` 重新拉取。

### 5.7 其他集成

- **无 AppWidget**。小组件式集成只有：`service/WebTileService`（QS 磁贴，`onStartListening` 同步 `WebService.isRun`，API 34+ 用一个透明 Dialog 规避前台服务启动限制）、`help/LauncherIconHelp`（切换 Launcher1-7 + WelcomeActivity）。
- `receiver/TimeBatteryReceiver.kt`：`ACTION_TIME_TICK`/`ACTION_BATTERY_CHANGED` → `EventBus.TIME_CHANGED`/`BATTERY_CHANGED`，由 `ReadBookActivity` 动态注册，驱动阅读页眉的时间/电量。
- `receiver/NetworkChangedListener.kt`：API 24+ 用 `registerDefaultNetworkCallback`，否则回退 `CONNECTIVITY_ACTION`。
- `receiver/SharedReceiverActivity.kt`：文本分享/划词后正则抽 http 链接，有链接进 `MainActivity` 否则进 `SearchActivity`。
- `api/ShortCuts.kt`：3 个动态快捷方式 —— "上次阅读"（两级 intent）、"朗读"（`SharedReceiverActivity` + `action=readAloud`）、"书架"。
- **通信统一用 LiveEventBus**（`utils/EventBusExtensions.kt:13-25` 的 `postEvent/observeEvent/observeEventSticky`），无 EventBus/LocalBroadcast。唯一的动态 `BroadcastReceiver` 是朗读服务里监听 `ACTION_AUDIO_BECOMING_NOISY` 自动暂停。

---

## 6. 扩展点与约定

### 6.1 书源 JSON Schema（`data/entities/BookSource.kt`）

顶层字段（41 个，按 `BookSource.kt:32-103`）：

```
bookSourceUrl (PK)      bookSourceName          bookSourceGroup
bookSourceType (0文本/1音频/2图片/3文件/4视频)   bookUrlPattern
customOrder   enabled   enabledExplore          jsLib
enabledCookieJar        concurrentRate          header
loginUrl      loginUi   loginCheckJs            coverDecodeJs
bookSourceComment       variableComment
lastUpdateTime          respondTime             weight
exploreUrl    exploreScreen
ruleExplore   ruleSearch  ruleBookInfo  ruleToc  ruleContent  ruleReview
eventListener           customButton
```

5 个规则对象（各自有 `JsonDeserializer` 支持"对象或 JSON 字符串"两种写法，见各 `companion object`），通过 `BookSource.Converters` 的 `@TypeConverter` 以 JSON 文本存库：

| 规则 | 字段 |
|---|---|
| `SearchRule` | `checkKeyWord` + 继承 `BookListRule`：`bookList name author intro kind lastChapter updateTime bookUrl coverUrl wordCount` |
| `ExploreRule` | 同上但**无** `checkKeyWord`；另有 `exploreScreen`（在 BookSource 上）描述筛选项 |
| `BookInfoRule` | `init name author intro kind lastChapter updateTime coverUrl tocUrl wordCount canReName downloadUrls` |
| `TocRule` | `preUpdateJs chapterList chapterName chapterUrl formatJs isVolume isVip isPay updateTime nextTocUrl` |
| `ContentRule` | `content subContent title nextContentUrl webJs sourceRegex replaceRegex imageStyle imageDecode payAction callBackJs` |
| `ReviewRule` | `reviewUrl avatarRule contentRule postTimeRule reviewQuoteUrl voteUpUrl voteDownUrl postReviewUrl postQuoteUrl deleteUrl`（**Converters 中被硬编码为 `null`/"null"**，即当前版本不持久化） |

**导入/导出与版本化**：
- 无 `version`/`schemaVersion` 字段；**兼容策略是"字段级容错"**：`fromJsonObject` 用 `Result` 包装、`getSearchRule()` 等在字段为 null 时惰性创建空对象（`BookSource.kt:121-154`）、`equal()` 用 `a == b || (a.isNullOrEmpty() && b.isNullOrEmpty())` 做空等价比较（用于判断是否需要更新，`:264`）。
- 更新判据：`RuleSub`（订阅）比对 `lastUpdateTime`；`SourceHelp.insertBookSource` 处理插入与分组保留。
- `help/Model/RuleUpdate.kt`：规则订阅（type 0书源/1订阅源/2替换规则，`RuleSub.type` 注释写 3 但代码用 2）拉取远端 JSON 数组，`silentUpdate` 决定静默写入还是缓存到 `cacheBookSourceMap` 等三个 `ConcurrentHashMap` 等待用户确认；`#requestWithoutUA` 后缀可禁用 UA。
- `BookSource.addErrorComment(e)` / `removeErrorComment()` 把校验失败信息写成 `// Error: ...` 前缀塞进 `bookSourceComment`；`getInvalidGroupNames()` 识别 `失效`/`校验超时` 分组。
- 18+ 源通过 `SourceHelp.is18Plus()` 打标（`assets/18PlusList.txt`）。

### 6.2 规则语法（`assets/web/help/md/ruleHelp.md` + `AppPattern.kt`）

- **模式标记**：`@@`（默认，可省略）、`@XPath:`（或直接以 `//` 开头）、`@Json:`（或以 `$.`/`$[` 开头）、`:regex`（只能用于书籍列表与目录列表）、`@CSS:`、`@webjs:`（5 字符以上）。
- **组合符**：`&&`（与/并集）、`||`（或/取首个非空）、`%%`（zip 交错）——由 `RuleAnalyzer.splitRule` 在跳过选择器/筛选器后切分。
- **替换**：`规则##正则##替换` 或 `规则##正则##替换###`（第 4 段 = 只取第一个匹配，`AnalyzeRule.replaceRegex` `:482-506`）。
- **变量**：`@put:{"key":"规则"}` 存变量、`@get:{key}` 取变量、`{{js}}` 内联 JS、`$1..$99` 分组引用。
- **内嵌**：`{{...}}` 内若无规则标志则当 JS 执行；`{$.rule}` 用于 JSONPath 嵌套。
- **jsLib**：直接填 JS 片段，或填 `{"name":"url"}` 映射（自动下载复用）；作用域由 `model/SharedJsScope.kt` 缓存（键 `MD5(jsLib)`，值 `WeakReference<Scriptable>`，`LruCache(16)`，磁盘缓存 `ACache("shareJs")`），求值后 `scope.preventExtensions()` 强制显式 `var`。
- **登录 UI / 登录 URL**：`loginUi` 是 `RowUi` 数组（type: text/password/button/toggle/select，支持 `action`/`viewName`/`chars`/`default`/`style`）；`loginUrl` 以 `@js:`/`<js>` 开头时被 `BaseSource.getLoginJs()` 剥离后执行，必须实现 `login` 函数；登录信息 AES 加密存 `CacheManager`（`userInfo_<key>`，密钥取自 `androidId`）。
- **发现 URL**：JSON 数组（新）或 `名称::url` 行（旧），`ExploreKind` + `InfoMap`（`source.putInfoMap` 值可读写并 `save()`）。
- **URL 选项**（`,{...}`）：`method charset headers body origin retry type webView webJs dnsIp js bodyJs serverID webViewDelayTime`（`AnalyzeUrl.UrlOption`，`:780-957`）。
- **事件回调**（`model/SourceCallBack.kt`）：13 个可消费事件（clickBookName/longClickAuthor/clickCustomButton/clickShareBook/clickClearCache/clickCopyBookUrl/clickCopyTocUrl/clickCopyPlayUrl/clickBookLabel 及其长按变体）+ 7 个不可消费事件（addBookShelf/delBookShelf/saveRead/startRead/endRead/startShelfRefresh/endShelfRefresh），JS 返回 `true` 消费事件。

### 6.3 JS 扩展 API 面（`help/JsExtensions.kt` 1199 行 + `help/JsEncodeUtils.kt` 517 行）

**全局变量**（`AnalyzeRule.evalJS` / `AnalyzeUrl.evalJS` / `BaseSource.evalJS` 注入）：

| 变量 | 含义 |
|---|---|
| `java` | 当前对象（`JsExtensions` 实现类） |
| `source` | `BaseSource`（书源/订阅源/HttpTTS） |
| `book` / `chapter` / `rssArticle` | 对应实体 |
| `cookie` | `CookieStore` |
| `cache` | `CacheManager`（含 `WebCacheManager` 给 WebView） |
| `baseUrl` / `result` / `src` / `title` / `nextChapterUrl` / `fromBookInfo` | 上下文 |
| `page` / `key` / `speakText` / `speakSpeed` / `infoMap` | URL 规则专用 |

**`java`（JsExtensions）主面**：`ajax(url[,callTimeout])`、`ajaxAll(urls[,skipRateLimit])`、`ajaxTestAll(urls,timeout)`、`connect(url[,header,timeout])`、`webView(html,url,js[,cacheFirst])`、`webViewGetSource(...)`、`webViewGetOverrideUrl(...)`、`get/head/post`（Jsoup 重定向拦截）、`importScript`、`cacheFile`、`getCookie`、`downloadFile`、`readTxtFile`、`deleteFile`、`unzipFile/un7zFile/unrarFile/unArchiveFile`、`getTxtInFolder`、`getZipStringContent/getRarStringContent/get7zStringContent`、`queryTTF/replaceFont`（字体反爬）、`base64Encode/Decode`、`hexEncode/Decode`、`md5Encode/md5Encode16`、`createSymmetricCrypto/createAsymmetricCrypto/createSign`、`digestHex/digestBase64Str/HMacHex/HMacBase64`、`t2s/s2t`、`htmlFormat`、`timeFormat/timeFormatUTC`、`encodeURI`、`toNumChapter`、`toURL`、`randomUUID`、`androidId`、`getWebViewUA`、`toast/longToast/log/logType`、`openUrl(url[,mimeType])`、`openVideoPlayer`、`startBrowser/startBrowserAwait`、`getVerificationCode`、`getReadBookConfig(返回 JSON)`、`getThemeMode/getThemeConfig`、`strToBytes/bytesToStr`。
文件读写**只能操作 App 缓存目录内相对路径**，`getFile()` 用 `canonicalPath` 做前缀校验，越界抛 `SecurityException("非法路径")`。

**`source`（BaseSource）**：`getKey/getTag`、`putVariable/getVariable`、`put(key,value)/get(key)`、`getLoginHeader/getLoginHeaderMap/putLoginHeader/removeLoginHeader`、`getLoginInfo/getLoginInfoMap/putLoginInfo/removeLoginInfo`、`login()`、`getHeaderMap(hasLoginHeader)`、`refreshExplore()`、`refreshJSLib()`、`putConcurrent(value)`、`evalJS`。变量持久化到 `CacheManager`（`v_<key>_<name>`、`sourceVariable_<key>`）。

**`book`/`chapter`**：属性直读（`book.name/author/kind/coverUrl/intro/type/group/durChapterIndex/...`）+ `putVariable/getVariable`；`chapter.putLyric/putImgUrl/update`。

**`cookie`**：`getCookie/getKey/setCookie/replaceCookie/removeCookie/setWebCookie`。
**`cache`**：`put/get/delete`（Room+内存）、`putFile/getFile`（ACache）、`putMemory/getFromMemory/deleteMemory`。

**沙箱**（`modules/rhino`）：`RhinoClassShutter` 前缀黑名单（`java.io.File*`、`java.lang.Class/ClassLoader/Runtime/ProcessBuilder`、`java.nio.file`、`java.lang.reflect/invoke`、`sun.*`、`dalvik.system`、`org.mozilla`、`com.script`、`android.app.ActivityThread`、`android.os.Process`、`android.system`、`androidx.room`、`okio.*`、`io.legado.app.data.dao` 等），由 `ClassNameMatcher`（排序数组 + `LruCache(64)` + 二分）加速；`System` 类被 `ProtectedNativeJavaClass` 包装并隐藏 `load/loadLibrary/exit`；`ReadOnlyJavaObject` 隐藏所有 `setXxx`。`App.kt:225-233` 注册 WrapFactory：BookSource/RssSource/HttpTTS → `NativeBaseSource.factory`（安全门面），ExploreRule/SearchRule/BookInfoRule/ContentRule/BookChapter/ReadConfig → 只读对象。
**超时机制不是指令预算**：`instructionObserverThreshold = 10000` 触发 `RhinoContext.ensureActive()` → 抛 `RhinoInterruptError`（继承 `Error`，为的是穿出脚本里的 `catch(Throwable)`）→ `doTopCall` 还原为真正的 `CancellationException`，即**协作式协程取消**。另有 `checkRecursive()`：`recursiveCount >= 10` 抛 `RhinoRecursionError`（防 JS 回调借道递归执行脚本）；`doTopCall` 先校验 `allowScriptRun`。

### 6.4 订阅（RSS）规则格式

**没有独立的 `RssRule` 类**，规则字段全部内联在 `RssSource`（`data/entities/RssSource.kt:15-116`）：`sourceUrl(PK) sourceName sourceIcon sourceGroup enabled jsLib enabledCookieJar concurrentRate header loginUrl loginUi loginCheckJs coverDecodeJs sortUrl singleUrl articleStyle ruleArticles ruleNextPage ruleTitle rulePubDate ruleDescription ruleImage ruleLink ruleContent contentWhitelist contentBlacklist shouldOverrideUrlLoading style enableJs loadWithBaseUrl injectJs preloadJs startHtml startStyle startJs showWebLog type(0网页/1图片/2视频) preload cacheFirst searchUrl`。

抓取链：`model/rss/Rss.getArticlesAwait`（`Rss.kt:35-81`）→ `AnalyzeUrl(sortUrl, page, key, baseUrl=sourceUrl, source, ruleData=RuleData)` → `loginCheckJs` 双向校验 → `RssParserByRule.parseXML`（`RssParserByRule.kt`）。
- `ruleArticles` 为空 → 降级 `RssParserDefault`（`XmlPullParser` 解 RSS2.0：`item/title/link/media:thumbnail/enclosure/description/content:encoded/pubDate`，正则抽首图）；
- `ruleArticles` 前缀 `-` = 倒序；
- `ruleNextPage == "PAGE"` 时 `nextUrl = sortUrl` 借 `page` 参数翻页，否则 `getString` + `getAbsoluteURL`；
- 标题空白即丢弃；`ruleDescription` 为空则置 null 并标记"将解析内容页"。
- 分类列表 `help/source/RssSourceExtensions.sortUrls()`：`&&`/换行分条、`名称::url` 拆名，支持 `<js>`，结果缓存 `ACache("rssSortUrl")`。

**"阅读全文"实现**：仅由 `ruleContent` 非空触发（`ui/rss/read/ReadRssViewModel.kt`）——`description` 非空直接渲染；否则 `ruleContent` 非空走 `Rss.getContent`（`AnalyzeUrl(link, baseUrl=origin, ruleData=rssArticle)` + `AnalyzeRule.setContent(body).setBaseUrl(...)` + `getString(ruleContent)`），**取回的正文被写回 `rssArticle.description` 并入库**（`RssArticle.content` 字段在 App 内无写入点）；`ruleContent` 为空则交给内置 WebView 打开原页。RSS 朗读读的是 WebView 的 `outerHTML` → `Jsoup.textArray` → TTS，与 `content` 字段无关。

**持久化与去重**：`RssArticle` 主键 `(origin, link, sort)`；分页加载用"递减 `order` + `insert(REPLACE)` + `clearOld`"，"加载更多"用首末条查重后 `append(IGNORE)`；已读标记来自 `flowByOriginSort` 的 `LEFT JOIN rssReadRecords ON t1.link = t2.record`。

### 6.5 字典规则 / 辅助键盘 / HTTP TTS 的规则形态

- **`DictRule`**：表 `dictRules`，字段只有 `name(PK) / urlRule / showRule / enabled / sortNumber`。查询时 `AnalyzeUrl(urlRule, key=word).getStrResponseAwait().body`，再 `AnalyzeRule.getString(showRule, mContent = body)`——因此 `showRule` 内可用全部规则语法（含 `##正则##替换`），**没有独立的替换字段**。`buttonClick(name, click)` 走 `evalJS` 支持结果里的按钮。使用点：阅读页选中文字 → `TextActionMenu` → `DictDialog`（按启用规则多 Tab，`<md>` 开头用 Markwon 渲染，否则 HTML + GlideImageGetter）。
- **`KeyboardAssist`**：`type/key/value/serialNo`（PK `(type,key)`），内置 32 条（`assets/defaultData/keyboardAssists.json`），在 `KeyboardToolPop` 中以网格插入编辑框，用于给出 `@css:`/`<js>`/`{{}}`/`##`/`&&`/`%%`/`||`/`useWebView` 等片段。
- **`HttpTTS`**：字段 `id name url contentType concurrentRate loginUrl loginUi header jsLib enabledCookieJar loginCheckJs lastUpdateTime`。请求细节（method/headers/body/charset/retry）写在 `url` 的 `,{...}` 尾缀里。内置 3 条（`assets/defaultData/httpTTS.json`：百度、阿里云语音（HmacSHA1 签名 + loginUi + loginCheckJs）、Next 引擎），JS 里 `speakText`/`speakSpeed` 可用。

---

## 7. 工程细节

### 7.1 线程与协程

- **自研链式协程 `help/coroutine/Coroutine.kt`** 是主要抽象：`Coroutine.async(scope = DEFAULT(MainScope), context = Dispatchers.IO, start, executeContext = Dispatchers.Main, semaphore, block)`——**默认"IO 执行 + Main 回调"**，与裸 `viewModelScope.launch` 的语义差异是移植时最容易踩的坑。提供 `onStart/onSuccess/onError/onErrorReturn/onFinally/onCancel/timeout`；`executeInternal` 统一做 `semaphore.acquire()/release()` 与 `ensureActive()` 插桩；`onCancel` 用 `ActivelyCancelException` 区分"主动取消"与"父作用域取消"；`onFinally` 在取消时不执行。`CompositeCoroutine` 是 `Coroutine<*>` 的 `HashSet` 容器（`clear()` 全取消）。
- **并行算子集中在 `utils/FlowExtensions.kt`**：`onEachParallel / onEachParallelSafe / mapParallel / mapParallelSafe`（基于 `flatMapMerge(n) + buffer(0)`）与 `mapAsync / mapAsyncIndexed`（`Semaphore(n) + channelFlow` 发 `async` 后**按序 await**，用于目录/正文多页保序）。`utils/MapExtensions.getOrPutLimit(key, maxSize, default)` 是"只缓存前 N 个"的懒加载辅助。
- **线程池**：搜索/校验/下载用 `Executors.newFixedThreadPool(min(AppConfig.threadCount, AppConst.MAX_THREAD))` 或 `.asCoroutineDispatcher()`；`AppConfig.threadCount` 默认 **32**，`AppConst.MAX_THREAD = 9`；另有 `help/ExecutorService.kt` 与 `help/globalExecutor`（进度保存、阅读时长统计等 fire-and-forget 任务）。
- **调度上下文裁剪**：`AnalyzeRule.setCoroutineContext(context)` 做 `context.minusKey(ContinuationInterceptor)`，刻意去掉拦截器（否则 Rhino 内的 `ensureActive()` 会失效）；`runScriptWithContext` 同样注入去掉拦截器的上下文。
- **主线程保护**：`isMainThread` 断言散布在 `webView`/`refreshExplore`/`refreshJSLib`/`getWebJsResult` 等处，主线程调用直接 `error(...)`。

### 7.2 缓存策略（三层 + 一套文件树）

| 层 | 载体 | 上限/位置 | 用途 |
|---|---|---|---|
| 内存 | `LruCache<String, Any>`（`CacheManager.kt:17`） | 50MB（`sizeOf` 用 `String.memorySize()`） | 变量、cookie、登录头、`webview_result` 等 |
| 内存（专用） | `queryTTFMap = LruCache(4)` | 4 | 字体子集 |
| 持久（结构化） | Room `caches` 表 | `key/value/deadline` | 与内存同 API，`saveTime=0` 表示永不过期 |
| 持久（文件） | `ACache`（`utils/ACache.kt`） | 默认 50MB，`cacheDir/ACache`（含 `shareJs` 子目录） | 大文本/字节、`explore` 分类缓存、`rssSortUrl` |
| 书籍正文 | **裸文件树**（与上面完全解耦） | `externalFilesDir/book_cache/<folder>/` | `.nb` 正文 / `.nr` 标记 / `images/` |
| 朗读音频 | ExoPlayer `SimpleCache` | LRU 128MB，`cacheDir/httpTTS/` | 逐段音频 |

`deadline` 语义：`saveTime == 0` → 永不过期；`get` 判定 `deadline == 0L || deadline > now`；`get(key, onlyDisk = true)` 绕过内存。`delete` 三处齐删（内存/DB/ACache）。`WebCacheManager`（`CacheManager.kt:158-196`）用 `@JavascriptInterface` 把同一套 API 暴露给后台 WebView。`CacheManager.clearSourceVariables()` 按 `v_ / userInfo_ / loginHeader_ / sourceVariable_` 四个前缀批量清理。

命名空间实况：`v_<sourceKey>_<key>`、`userInfo_<key>`、`loginHeader_<key>`、`sourceVariable_<key>`、`<domain>_cookie` / `_session_cookie` / `_cookieJar`、`infoMap_<sourceUrl>`、`md5_16(url)`（下载文件）。

### 7.3 网络栈

- **全局唯一 `okHttpClient`**（`help/http/HttpHelper.kt:51-127`）：超时 connect/write 15s、read/call 60s；`SSLHelper.unsafeSSLSocketFactory` + `unsafeHostnameVerifier`（**不校验证书**）；应用拦截器注入 UA（值为 `"null"` 时**删除** UA）与 `Keep-Alive/Connection/Cache-Control:no-cache`；网络拦截器按自定义头 `CookieJar` 决定是否走 cookie 存取；自定义 DNS（`AppConfig.customHosts` + `hostMap/addressCache`）；`AppConfig.isCronet` 时挂 `CronetInterceptor`；最后挂 `DecompressInterceptor`（未显式给 `Accept-Encoding` 且无 `Range` 时透明解 gzip/deflate，并剥掉 `Content-Encoding`/`Content-Length`）。
- `getProxyClient(proxy)` 按 `http|socks4|socks5://host:port[@user@pass]` 缓存代理客户端。
- `OkHttpUtils.kt`：`newCallResponse/newCallResponseBody/newCallStrResponse`、`Call.await()`（`suspendCancellableCoroutine` + `invokeOnCancellation { cancel() }`）、`ResponseBody.text(encode)`（去 UTF-8 BOM → HTTP charset → `EncodingDetect.getHtmlEncode` 猜测，三级回退）、`decompressed()`（`application/zip` 解一层）。
- `help/http/ObsoleteUrlFactory.kt`（**1201 行**）：实现 `URLStreamHandlerFactory`，把 `java.net.HttpURLConnection` 全部桥接到 OkHttp（`OkHttpURLConnection`），使 Rhino 脚本/Jsoup 里 `new URL(...).openConnection()` 也能复用同一套 UA、Cookie、TLS、代理。
- **Cookie 双层**：`CookieStore` 以二级域名为键持久化到 Room（`getCookie` 结果超 4096 字符时随机剔除 key 防膨胀）；`CookieManager` 分离**会话 cookie（仅内存 `<domain>_session_cookie`）**与**持久 cookie（落库）**，并 `applyToWebView` 同步给系统 WebView。
- **`BackstageWebView`（391 行）**：JS 重站点的"隐藏浏览器"。参数覆盖 `url/html/encode/tag/headerMap/sourceRegex/overrideUrlRegex/javaScript/cacheFirst/timeout/result/isRule`；`WebViewPool.acquire()` 复用实例（`help/webView/WebViewPool.kt`）；注入 `WebCacheManager`/`BaseSource`/`WebJsExtensions` 三个 JS 接口并接管 console；`onPageFinished` 后用 `EvalJsRunnable`（间隔 200/400/600/800/1000ms）轮询取值。
- **`Cronet.kt`**：`CronetLoader`（实现 `CronetEngine.Builder.LibraryLoader`，按 CPU ABI 下载/校验 MD5/解压 native so）+ `CronetInterceptor`；`LoaderInterface` 抽象使 Cronet 可整体降级为纯 OkHttp。
- `StrResponse`：JS/规则层可见的响应包装（`body/code/message/headers/isSuccessful/url/callTime`），支持从纯字符串伪造 200 响应。

### 7.4 并发限速（书源级 QPS）

`help/ConcurrentRateLimiter.kt`（133 行）：`concurrentRate` 语法 `"n/m"`（m 毫秒内最多 n 次）或 `"n"`（等价 `1/n`）。`concurrentRecordMap: ConcurrentHashMap<String, ConcurrentRecord>` 以 `BaseSource.getKey()` 为键**跨实例共享**（`AnalyzeUrl.ConcurrentRecord{time, accessLimit, interval, frequency}`）。`fetchStart()` 在 `synchronized(record)` 内判定：已过 `time+interval` → 重置窗口并放行；窗口内 `frequency < accessLimit` → 放行并自增；否则抛 `ConcurrentException(waitTime = nextTime - now)`（`exception/ConcurrentException.kt`）。`getConcurrentRecord()` 协程版 `delay(waitTime)` 自旋；`getConcurrentRecordBlocking()` 是 `Thread.sleep` 版（Jsoup 同步路径用）。对外 `withLimit{}` / `withLimitBlocking{}`；首次创建记录即占用一次配额。`updateConcurrentRate()` 支持脚本热改（`source.putConcurrent(str)`）。

### 7.5 错误处理约定

- 统一 `constant/AppLog.kt` 的 `AppLog.put(msg, throwable, toast?)`：写日志文件 + 可选 UI 提示；异常展示在 `ui/about/AppLogDialog`/`CrashLogsDialog`。`CrashHandler` 全局兜底。
- 领域异常极简（`exception/` 8 个文件共 48 行）：`NoStackTraceException`（大范围用于"业务性失败"，避免堆栈开销）、`TocEmptyException`、`ContentEmptyException`、`EmptyFileException`、`NoBooksDirException`、`InvalidBooksDirException`、`ConcurrentException`、`RegexTimeoutException`。
- **`NoStackTraceException` 被大量用于控制流**（如"搜索url不能为空"、"下载链接为空"、"没有搜索到<name><author>"），而非返回 null。
- **取消与错误的区分**：`onFailure { currentCoroutineContext().ensureActive() }` 是固定写法——若协程被取消则重抛 `CancellationException`，否则继续把异常记为业务失败。
- **替换规则超时自动禁用**：`BookChapter.getDisplayTitle` / `ContentProcessor.getContent` 捕获 `RegexTimeoutException` 后 `item.isEnabled = false; appDb.replaceRuleDao.update(item)`，即"某条正则跑超时就把这条规则自动关掉"（`BookChapter.kt:156-158`）。
- **JSON 宽松回退 + 告警**：`GSONStrict` 失败 → `GSON` 成功 → `Debug.log("…JSON 格式不规范，请改为规范格式")`。此模式出现在 `UrlOption`、`@put`、请求头、发现规则、书源规则等多处。
- `AnalyzeUrl.executeStrRequest` 的 `isTest` 分支把网络异常映射为负数错误码写进 `callTime`，供"书源校验/测速"展示而不抛异常。

### 7.6 值得注意的算法

1. **`RuleAnalyzer` 手写平衡扫描器**（§3.7）：不用正则、不在中途切片，只用位置标记，专门解决规则里 `&&`/`||`/`%%`/`@`/`{}` 与 JSONPath/XPath 语法冲突。含 `chompCodeBalanced`（处理 `[]` 嵌套 + 引号 + 反斜杠转义）与 `chompRuleBalanced`（引号内不转义）两套平衡策略。
2. **JSoup 元素索引 DSL**（`AnalyzeByJSoup.ElementsSingle`）：同时兼容旧式 `tag.div.-1:10:2`（`:` 分隔索引、`!` 排除、`.` 选择、支持负数）与新式 `tag.div[-1, 3:-2:-10, 2]`（区间 + 步长 + 反向 `[-1:0]`）。
3. **中文字体反爬破解**（`QueryTTF.java` + `java.replaceFont`）：用错误字体的 `glyf` 轮廓数据在正确字体里反查 unicode；`filter=true` 时删除错误字体中不存在的字形。
4. **同名书合并**（`SearchModel.mergeItems`）：四档相关性 + `(name, author)` 归并 + 按来源数排序。
5. **断点续读定位**（`BookHelp.getDurChapter`）：`JaccardSimilarity` 阈值 0.96 + 中文数字章节号解析，索引按新旧章节数比例缩放并 ±10 窗口搜索。
6. **目录/正文多页并发保序**（`mapAsync`）：`Semaphore(n)` + `channelFlow`，先 `async` 全部发出再按序 `await`，兼顾并发与顺序。
7. **阅读排版器**（§7.7）。
8. **RSS/正文的 `prevResponse?.isRedirect` 检测**与 `bookUrlPattern` 命中即"搜索结果直出详情页"的短路优化。

### 7.7 阅读视图与排版（Flutter 移植的头号难点）

`ui/book/read/` 共 58 文件 / 14,882 行。渲染链路：

```
activity_book_read.xml（FrameLayout）
└─ ReadView (ViewGroup, ReadView.kt:771行)
   ├─ prevPage / curPage / nextPage : PageView (FrameLayout, 510行)
   │    └─ ContentTextView (787行) ← 真正 draw
   ├─ pageFactory  : TextPageFactory (provider/TextPageFactory.kt)
   ├─ pageDelegate : Cover/Slide/Simulation/Scroll/NoAnim PageDelegate
   └─ autoPager    : AutoPager
```

- **排版上下文** `page/provider/ChapterProvider.kt`（376 行，object）：持有 `viewWidth/visibleWidth/padding*/titlePaint/contentPaint/reviewPaint/FontMetrics/doublePage`；`getTextChapterAsync()` 异步产出 `TextChapter`；`upStyle()` 按 `ReadBookConfig` 重建 Paint。
- **分页器** `page/provider/TextChapterLayout.kt`（**1,333 行**）：协程 + `Channel` 分块产出页面（支持取消）；正文用 `StaticLayout(text, textPaint, visibleWidth, …)`，HTML 用 `StaticLayout.Builder.obtain()` + `HtmlCompat` + `ImageSpan`；逐字装行有 `addCharsToLineFirst/Middle/Natural`、`addCharToLine`；配套 `measureTextSplit`、`prepareNextPageIfNeed`、`justifyHtmlLine`；进度经 `LayoutProgressListener`（`onPageCompleted/onCompleted/onException`）回调。
- **中文断行** `page/provider/ZhLayout.kt`（277 行）：继承 `Layout` 自研，实现标点禁则（`postPanc/prePanc`）与 `BreakMod{NORMAL, BREAK_ONE_CHAR, BREAK_MORE_CHAR, CPS_1..3}`，解决 `StaticLayout` 不符合中文排版惯例的问题；由 `ReadBookConfig.useZhLayout` 开关。
- **宽度测量** `page/provider/TextMeasure.kt`：码点级缓存（`asciiWidths[128]` + `SparseArray codePointWidths` + 常用汉字宽度）。
- **数据模型**：`TextChapter`(321) / `TextPage`(374) / `TextLine`(302) / `TextPos`(65)，列类型 `BaseColumn/TextColumn/TextHtmlColumn/ImageColumn/ButtonColumn/ReviewColumn`（用于图片点击、段评、按钮的行内命中测试）。
- **翻页动画**：`constant/PageAnim.kt`（cover=0/slide=1/simulation=2/scroll=3/noAnim=4）；`HorizontalPageDelegate` 用 `CanvasRecorderFactory`（`utils/canvasrecorder/`，分 Api23/Api29 实现）把三页录成位图；`SimulationPageDelegate`（612 行）实现卷曲阴影。
- **Paint 复用**：`help/PaintPool.kt`（`object PaintPool : BaseSafeObjectPool<Paint>(8)`）。
- **菜单** `ReadMenu.kt`（`view_read_menu.xml` 34 个 id）：整屏覆盖层 `gone/visible` 切换 + 上下滑入动画，含亮度、进度、目录、朗读、字体、设置、搜索、自动翻页、净化、夜间主题入口。**章节目录不是抽屉**，而是独立 `TocActivity`（ViewPager + TabLayout：章节列表/书签）。
- 配置管道：`help/config/ReadBookConfig.kt`（887 行，`filesDir/readConfig.json`）保存 5 套样式，`Config` 约 50 个字段（三态背景/文字色、`textSize=20`、`letterSpacing=0.1f`、`lineSpacingExtra=12`、`paragraphSpacing=2`、`paragraphIndent="　　"`、`pageAnimEInk=4`、`titleMode`、页眉页脚 6 槽、`padding*`…），支持 zip 导入导出。

---

## 8. 对 Flutter 移植的直接启示（速查）

| 领域 | Legado-E 的做法 | 移植建议 |
|---|---|---|
| UI 范式 | 多 Activity + ViewBinding + LiveEventBus + 回调接口 | 不要找 Compose 参照；按"多页面 + 全局事件总线 + 命令式刷新"映射到 Flutter 的 Navigator + 单例 Notifier/Stream |
| 领域层 | 14 个 `object` 单例直接访问 DAO | 可保留单例（`get_it` 或纯静态），不必强上 Repository |
| 数据层 | Room 21 实体 + 位掩码 type/group + 1 个 DatabaseView；89 版 schema | 优先 drift（SQL 语义最接近）；`book_sources_part` 视图、位掩码 SQL、`UNIQUE(name,author)`、FK CASCADE 都要还原 |
| 规则引擎 | `RuleAnalyzer` 手写平衡扫描器 + `SourceRule` 四段式（rule##regex##replacement###） | 这是**最核心的移植工作**：需自研解析器（Dart 手写同样可行），不能依赖通用正则库 |
| 解析后端 | JSoup / JsoupXpath / json-path / regex | Dart 生态：`html`（css 选择器，但需补 Legado 的 `@text/@ownText/@html/@all` 与索引 DSL）、`xpath_selector`、`json_path`；正则用 Dart RegExp |
| JS 沙箱 | Rhino 1.8.1 + 协程可取消 + class shutter | **无对等物**。可选 QuickJS（`flutter_js`）或自研 DSL 子集；`java.*` 扩展 API 面（§6.3）需要逐个映射为宿主函数 |
| 排版 | StaticLayout + 自研 ZhLayout + PaintPool 位图录制 | Flutter 用 `TextPainter` 无法直接对应；中文禁则需自研 `LineBreaker`，翻页动画需自绘 |
| 缓存 | LruCache50MB + Room caches + ACache + 裸文件树 | 可直接照搬四层结构；文件路径/文件名 `%05d-md5.nb` 建议保持一致以便导数据 |
| 存储路径 | `externalFilesDir/book_cache/<前9字+md5_16(bookUrl)>` | 保持一致可让备份 zip 互操作 |
| 并发 | `Coroutine`(IO→Main) + `mapAsync` 保序 + `ConcurrentRateLimiter` + threadCount 默认 32 / 上限 9 | Dart `Isolate.run`/`Future` + `Pool`；限速算法（滑动窗口 + ConcurrentException 等待）需完整复刻 |
| 备份 | 23 个 JSON + 普通 zip + 2 个字段 AES(ECB, MD5 密码前 16 字节) | 格式需逐字节兼容才能与 Android 版互导 |
| 深链 | `legado://import/{bookSource,rssSource,replaceRule,textTocRule,httpTTS,theme,readConfig,dictRule}?src=` + 类型嗅探 | 需实现同样的 path 映射与"按 JSON 顶层键嗅探类型"逻辑 |
| 书源兼容 | 字段级容错 + 空等价比较 + `lastUpdateTime` 判更新 | 不要引入 schema 版本号，沿用容错策略 |
| 已知缺陷（勿照抄） | ReaderProvider 的 rss 路由复用 BookSource RequestCode；CheckSourceService 误用朗读通知渠道；`ReviewRule` TypeConverter 恒返回 null；rss 正文写回 `description` 而非 `content` | 移植时修正 |
