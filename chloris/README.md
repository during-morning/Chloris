# chloris

Chloris Flutter 应用（跨平台阅读器）。规则引擎见 `../packages/chloris_engine`。

## 运行
```bash
flutter pub get --offline
flutter run -d chrome --release
```

Web 发布包必须用 **release**（debug 的 Canvas 经常整体发糊），浏览器缩放保持 **100%**：

```bash
flutter build web --release
dart run tool/serve_web.dart
```

## 目录
- `lib/app`：应用壳/主题/路由/本地化
- `lib/application`：UseCase、Port 与跨功能编排
- `lib/features`：书架/搜索/探索/书源/阅读/本地/RSS/规则/设置
- `lib/engine`：引擎装配（HTTP/JS/书源库）
- `lib/data`：drift 数据库骨架
- `lib/services`：Web 服务/备份/WebDAV/配置导入/导出/扫描
- `assets/sources`：默认书源与规则

功能介绍、当前状态与进行中的计划统一见根目录 `README.md`；在办计划另见 `artifacts/规则引擎算法与legado-E差异.md`。
