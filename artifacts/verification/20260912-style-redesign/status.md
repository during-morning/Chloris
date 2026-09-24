# Chloris 风格重构 — 验证记录（2026-09-12）

## 范围

按 `claude.com/product/cowork` 的暖色编辑部语言与 `opencode.ai` 的黑白终端语言，
重做 `AppUiStyle.claude` 与 `AppUiStyle.terminal` 两套界面风格：全局字体、排版、
按钮/描边、页面布局、阅读器外观，图标统一为黑白单色两级。

`AppUiStyle.classic`（13 套配色 / 墨水屏 / Material 3）**保持不变**——见下方像素级比对。

## 验证命令

```
flutter analyze lib          # 0 error
flutter test                 # 302 passed / 1 failed（见「既有失败」）
flutter build web --release  # ✓ Built build/web
dart run tool/serve_web.dart 2328
```

## 截图

| 文件 | 内容 |
| --- | --- |
| `screenshots/final-claude.png` | Claude 风格：暖纸画布、衬线大标题、细线分栏、赤陶主按钮、黑白图标 |
| `screenshots/final-terminal.png` | 终端风格：纯黑、等宽、1px 线框、白色方框选中态、反白按钮 |
| `screenshots/final-classic.png` | 经典风格（应与改动前完全一致） |
| `screenshots/cjk-probe.png` | 内置 Noto Sans JP 的简体覆盖探针：以纯拉丁字体为唯一 fallback，零豆腐块 |

经典风格截图的 SHA-256 与改动前一致（`8a75da71…`），即像素级未变。

## 本次发现并修复的缺陷

### 1. Web 端离线无法启动（既有）

- `web/index.html` 只写了 `useLocalCanvasKit: true`，但引擎的解析逻辑是
  `canvasKitBaseUrl` 优先，否则回落到 `www.gstatic.com`。该主机在本机不可达，
  页面白屏。
- 修复：显式指定 `canvasKitBaseUrl: "canvaskit/"`，使用构建产物内置的引擎。

### 2. 渲染阻塞的 webfont（既有）

- `<link href="https://fonts.googleapis.com/css2?...">` 在无法访问该主机时会挂起，
  阻塞首次绘制。
- 而且 CanvasKit 使用自己的字体集合，**不消费 DOM 的 `@font-face`**，这个链接对
  实际界面文字没有任何作用。
- 修复：移除该链接，字体栈改为内置字体族（见 `assets/fonts/OFL.md`）。

### 3. 中文豆腐块（既有）

- CanvasKit 的中文 fallback 从 `fonts.gstatic.com` 下载。该主机不可达时，界面
  文字全部退化为 `□`。
- 修复：内置 OFL 许可的 Noto Sans JP（Source Han 系，简体覆盖完整，已用
  `screenshots/cjk-probe.png` 验证），并作为每种字体栈的末位 fallback。
- **遗留**：引擎仍会在启动时尝试拉取默认 Roboto，本机上约 **30s** 后超时放弃
  才完成首屏（`BOOTED after 30.0s with no interception`）。这是引擎层行为，
  有网络时无感；离线首次启动会明显变慢。

### 4. `MeowPage` 布局约束错误（本次改动引入，已修复）

新排版把标题块放进 `Column`（高度无界）、正文放进 `Expanded`（高度有界），
但两者共用了同一个 `SizedBox(height: maxHeight)` 包裹，导致标题侧拿到
`infinity` 高度、内容子树布局失败并在 release 下渲染为空。
已拆分为 `headerBox`（只约束宽度）与 `bodyBox`（透传高度），并由
`test/widgets/meow_style_test.dart` 三种风格逐一守护。

### 5. 阅读纸张 id 冲突（本次改动引入，测试捕获）

新增的「纸白」纸张曾使用 id `paper`，但该 id 是旧版本持久化的
「跟随应用」别名，会造成老用户配色被改写。已改名为 `canvas`。

## 既有失败（与本次改动无关）

| 项 | 位置 | 说明 |
| --- | --- | --- |
| 3 个 analyze error | `test/engine/file_port_io_test.dart`、`test/services/web_api_test.dart` | 服务端/FilePort 层在改动前就在重构中（`ChlorisServer` 参数、`createFilePort` 歧义导入） |
| 1 个 test failure | `test/engine_js_runtime_io_test.dart` | `js_unsupported: 规则 JS 无法求值`，`packages/chloris_engine` 的 JS 运行时 |

## 字体

内置 4 族（全部 SIL OFL 1.1，可再分发），合计约 5.5MB，详见
`chloris/assets/fonts/OFL.md`：

| 字体族 | 用途 |
| --- | --- |
| `PTSerif` | Claude 标题/正文衬线、阅读器默认纸面 |
| `SourceSansPro` | Claude 界面无衬线（标签、按钮、正文） |
| `IBMPlexMono` | 终端风格全量等宽 |
| `NotoSansJP` | 全风格的中日韩 fallback |

移除方式与影响见该文件。
