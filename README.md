# Cholris

Cholris 是一款以 Flutter 构建的跨平台阅读与音乐播放器，面向在线书源、个人本地书库与音频。它可以导入兼容 Legado / Legado-E 格式的书源和规则，搜索、发现并阅读在线内容，也可以管理本地电子书、音乐、RSS 订阅、阅读记录与备份。规则引擎以纯 Dart 编写，Flutter 应用负责界面、存储和平台能力。

Cholris 不提供书城或书籍内容托管服务。在线书籍、订阅文章和规则来自用户配置的第三方站点；书源能否使用取决于站点及其规则当前是否有效。

## 功能一览

### 在线书籍与书源

- **导入书源**：从 JSON 文件、剪贴板或 URL 导入 Legado / Legado-E 书源；也支持 `legado://import/...` 深链。可管理书源启用状态和分组，并查看或编辑规则。
- **多源搜索**：对多个启用的书源并行搜索，结果逐步合并展示；按书名、作者等信息合并重复结果。搜索会扫描全部选定来源，打断后直接重新搜索。
- **发现与书籍详情**：浏览书源提供的发现分类和列表，查看书籍信息、来源、目录与章节；可刷新目录、检查源状态并进入单源调试。
- **换源与校验**：手动换源面板和自动换源共用候选评分与去重逻辑，并通过目录验证；正文为空时也会尝试自动寻找可用来源。可对书源执行批量健康校验。
- **登录与 Cookie**：提供交互式书源登录界面和 Cookie 管理；书源规则可使用持久化 Cookie 与键值存储保存站点登录状态。
- **阅读缓存与下载**：缓存目录及正文，支持章节批量下载和中断后恢复；正文与目录分开存储和管理。

规则引擎实现 CSS、XPath、JSONPath、正则及 URL 解析，并提供 Legado 风格规则数据结构、JS 宿主接口、HTTP 请求、Cookie、加解密和内容处理等能力。不同书源使用的脚本和站点特性不同，复杂 JS、深度 WebView 交互或站点改版可能导致个别规则无法工作。

### 书架与阅读记录

- 在线书和本地书集中管理；书架支持分组、排序、置顶及按书籍身份去重，同一本书可以保留多个来源候选。
- 保存在线及本地阅读进度、阅读记录与章节书签，可从书架继续阅读，并查看全部书签或历史记录。
- 书籍详情包含章节目录、目录刷新、来源切换、缓存状态及下载入口。

### 阅读器

- 支持**覆盖、滑动、滚动和无动画**等翻页方式；支持单页、始终双页或宽屏自动双页布局。
- 可调整字体与字号、行距、段距、页边距、文字粗细和阅读配色；内置阅读字体，并包含适用于中文显示的字体资源。
- 支持简繁转换、替换净化规则、目录规则，以及可选的自动翻页和文字朗读（TTS，依赖设备平台能力）。
- 支持漫画/图文内容的纵向浏览，以及应用可用时的视频、音频内容播放。
- 提供阅读器快捷键；实际可用按键及媒体能力会因设备和平台而异。

### 音乐播放器

- 提供独立音乐播放器，也可播放兼容 Legado-E 的书源音频与章节音频；支持从音频直链、网页、HTML 或 JSON 解析播放地址及请求头。
- 可导入设备音频文件和 LRC / 纯文本歌词；书源提供的 `subContent` 歌词会随章节音频加载。音频编码支持取决于设备和播放后端。
- 同步歌词随播放进度滚动并高亮当前行，点击带时间戳的歌词可跳到对应位置。
- 管理播放队列，切换或移除曲目；支持播放暂停、进度定位、前后跳转、音量、倍速，以及顺序、随机、列表循环和单曲循环。
- 提供定时停止与播放失败重试。支持的平台可通过系统媒体通知或锁屏控件控制播放。
- Web 端通过同源流式代理携带书源请求头，支持 Range 定位与 HLS 播放清单；本地音频使用浏览器文件播放。

### 本地书籍

- 从设备导入 **TXT、EPUB、PDF、MOBI/AZW3、UMD** 文件并加入本地书架。
- TXT 支持编码探测和可配置目录识别规则；EPUB、MOBI/AZW3、UMD 会解析为章节供阅读。
- 本地内容可导出为 TXT 或 EPUB；导出文件名可按模板生成。
- PDF 使用平台可用的阅读组件；内嵌阅读能力因平台而异。

### RSS 订阅

- 管理 RSS / Atom / JSON Feed 订阅源与文章，可导入 Legado 格式的订阅源配置。
- 订阅源可包含发现分类与文章规则；阅读文章时使用统一的阅读体验。

### 规则与配置管理

- 管理正文替换/净化规则、TXT 目录识别规则、字典规则及订阅源；部分规则可在应用内测试或预览。
- 可导入包含 `bookSource.json`、`replaceRule.json`、`txtTocRule.json`、`dictRule.json`、`rssSources.json` 等文件的一键 ZIP 配置包。
- 可备份与恢复应用配置；备份支持 ZIP，并可选择 AES-256-CBC 加密。配置导入用于兼容 Legado 格式，未知字段会尽可能保留。
- 提供 WebDAV 备份文件的列出、上传、下载恢复和删除功能。

### Web 服务与 Web 版

桌面端可以启动 Cholris Web 服务，为浏览器中的 Web 客户端提供在线书籍和配置接口。Web 客户端需要连接一个兼容版本的 Cholris 服务端；服务端不可达或 API 主版本不匹配时，在线功能不可用。当前客户端/服务端契约覆盖书源、书架、搜索/发现、书籍详情、目录、正文、阅读配置、RSS 源和替换规则等接口；并非所有移动端或桌面端功能都由 Web 服务提供。

服务端可配置监听地址和访问令牌。仅在可信网络中开放服务，并妥善保管令牌；不要将带有个人书源、Cookie 或凭据的服务暴露给不可信网络。

### 外观与个性化

- 提供经典、Absolutely 暖纸编辑部和终端三种界面风格。
- 默认使用 Absolutely 界面并跟随系统浅色/深色模式；支持经典主题配色、墨水风格、高对比度与粗体文字。界面设置会保存在本机。
- 内置 PT Serif、Source Sans Pro、IBM Plex Mono 及中文字体资源；内置字体采用 SIL OFL 许可。

## 平台与数据

| 平台 | 主要能力说明 |
| --- | --- |
| Web | 浏览器界面；在线书源、目录和正文通过兼容的 Cholris 服务端访问。浏览器存储受配额限制。 |
| Android / iOS | 本地书籍、在线阅读及设备提供的文件、通知、朗读和媒体能力。 |
| macOS / Windows / Linux | 本地书籍和在线阅读；桌面端可启动 Web 服务。部分媒体与文件能力取决于平台依赖。 |

书架、阅读进度、书签、书源、规则、Cookie 和设置默认保存在本机。只有在用户主动请求书源、订阅内容，或配置 WebDAV、代理和 Web 服务时，应用才会按相应配置进行网络通信。Web 服务会将相应数据交由连接的客户端访问。

## 快速开始

### 环境要求

- Flutter SDK 3.x，Dart SDK `>=3.12.2`（以 `chloris/pubspec.yaml` 的约束为准）。
- Web 发布与运行示例默认在仓库根目录执行；若 SDK 不在 `PATH`，可设置 `FLUTTER_BIN` 和 `DART_BIN`。

### 获取依赖并运行 Web 版

```bash
export FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
export DART_BIN="${DART_BIN:-dart}"

"$FLUTTER_BIN" pub get --directory chloris
"$FLUTTER_BIN" build web --release --no-wasm-dry-run --directory chloris
cd chloris && "$DART_BIN" run tool/serve_web.dart
# 打开 http://127.0.0.1:2328/
```

Web 版需在浏览器设置中连接一个已启动且版本兼容的 Cholris 服务端，才能使用在线书籍相关能力。

### 在设备或桌面运行

```bash
cd chloris
flutter pub get
flutter run
```

要运行指定设备，可使用 `flutter devices` 查看设备列表，再执行 `flutter run -d <设备 ID>`。

### 开发检查

在仓库根目录运行引擎测试、应用测试和静态分析：

```bash
(cd packages/chloris_engine && dart test)
(cd chloris && flutter test)
(cd chloris && flutter analyze)
```

## 发布构建

在仓库根目录执行：

```bash
# Web
flutter build web --release --no-wasm-dry-run --directory chloris

# Android APK
cd chloris && flutter build apk --release

# Apple 平台（需要完整 Xcode）
flutter build macos --release
flutter build ios --release --no-codesign

# Windows / Linux：分别在对应宿主系统执行
flutter build windows --release
flutter build linux --release
```

## 项目结构

```text
packages/chloris_engine/   纯 Dart 规则引擎、在线内容解析、阅读排版和本地文件解析
chloris/lib/app/           应用入口、路由、主题、图标和本地化
chloris/lib/features/      书架、搜索、发现、书源、阅读、音乐、本地书、RSS、规则与设置界面
chloris/lib/application/   跨功能用例与应用服务
chloris/lib/data/          数据库与书架数据访问
chloris/lib/engine/        Flutter 宿主与纯 Dart 引擎之间的适配
chloris/lib/services/      备份、WebDAV、Web 服务、文件导入导出等平台服务
chloris/assets/sources/    随应用提供的默认书源与规则
```

引擎通过 HTTP、JS 运行时、存储和宿主能力接口与 Flutter 解耦，不依赖 Flutter，可单独作为 Dart 包复用。主要实现位于 [`packages/chloris_engine`](packages/chloris_engine)。

## 已知限制

- 书源由第三方维护，网站改版、登录状态失效、反爬或网络变化会影响可用性；需要按来源检查和调整规则。
- 应用不会绕过验证码、DRM 或站点访问控制。复杂 JS 书源、依赖深度 WebView 的交互以及部分特殊字体/加密实现可能无法兼容。
- 不支持 RAR / 7z 本地压缩包解码；PDF 内嵌查看器及音视频、朗读等能力按平台提供。
- Web 端文件访问和存储受浏览器限制；在线抓取由服务端执行，Web 版不等同于离线桌面/移动端。

## 许可

项目以 **GPL-3.0** 许可发布，详见 [LICENSE](LICENSE)。内置字体采用 SIL Open Font License，许可文本见 [`chloris/assets/fonts/OFL.md`](chloris/assets/fonts/OFL.md)。
