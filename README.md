# Chloris

Chloris 是一个用 Flutter 写的跨平台阅读器（包名 `com.during.chloris`）。兼容 Legado / Legado-E 书源规则，可搜书、追更、换源、离线缓存；本地直接读 TXT / EPUB / MOBI(KF8) / PDF / UMD。规则引擎为纯 Dart 重写，同一套代码跑在 Web / Android / iOS / macOS / Windows / Linux。

## 核心特性

- **书源生态**：多源聚合搜索（可停止/续搜/早停）、发现页、一键/自动换源（源空自动寻找可用源）、单源调试、批量校验、书源登录
- **阅读器**：覆盖/滑动/滚动/无动画/仿真翻页、双页模式、排版与多套配色、简繁转换、替换净化（含作用域）、漫画与音视频播放
- **书架**：本地+在线统一、分组/排序/置顶、阅读进度与书签
- **本地书**：TXT（编码探测+目录规则）/EPUB/MOBI/PDF/UMD，可导出 TXT/EPUB
- **RSS**：RSS2 / Atom / JSON Feed，标准源与规则源
- **数据**：备份/恢复（兼容 Legado 配置导入）、WebDAV、桌面端 Web 服务
- **外观**：三套界面外壳（经典 / Claude 暖纸编辑部 / 终端），内置四套 OFL 字体，离线可用

## 快速开始

```bash
# Web 版（release 构建；项目自带 Flutter SDK）
reference/flutter-sdk/flutter/bin/flutter pub get --directory chloris
reference/flutter-sdk/flutter/bin/flutter build web --release --no-wasm-dry-run --directory chloris
cd chloris && ../reference/flutter-sdk/flutter/bin/dart run tool/serve_web.dart
# → http://127.0.0.1:2328/
```

```bash
# 引擎测试（432 项）与应用静态分析
cd packages/chloris_engine && ../../reference/flutter-sdk/flutter/bin/dart test
cd ../../chloris && ../reference/flutter-sdk/flutter/bin/flutter analyze
```

## 状态与边界

- 计划与完成度：见 **[plan.md](plan.md)**（唯一计划表，含与 Legado-E 的差异大表）。
- 书源是社区维护的第三方数据，站点改版会使规则失效——逐源校准是常态，不绕过验证码与访问控制。
- 复杂 JS 书源、DRM、深度 WebView 依赖在纯 Dart / Web 目标下无法完全等价（详见 plan.md ➖ 项）。

## 许可

参考 Legado-E 代码与行为时遵守 GPL-3.0 及相关许可义务；内置字体均为 OFL 许可。
