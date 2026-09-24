# Chloris ·「Claude → Absolutely」主题切换计划

> **执行状态（2026-09-13）**：P1-P8 全部完成。
> - P1-P5 原子改名链一次过：枚举 `AppUiStyle.absolutely`（id `'absolutely'`，
>   `byId` 兼容 `'claude'`）、主题层/图标映射/组件（absolutely_widgets.dart，
>   `Absolutely*` 四组件）/13 个文件全量更名，`dart analyze` 0 error。
> - main.dart 启动时一次性迁移：读到 `'claude'` 回写 `'absolutely'` 并同步 vault。
> - P6 web CSS：`data-ui-style="absolutely"`、画布 `#F0EEE6`、theme-color、
>   陶土选区洗、墨色药丸滚动条、JS 端 legacy 归一。
> - P7：MeowRule 短刊头线（64px 墨短线 + 发丝延展）、关于页三栏
>   `AbsolutelyDividerGrid`（版本/许可/血统）、书架"最近 · n"标本标签落地。
> - P8：lib+web 残留审计仅剩迁移映射 3 处（带注释）；
>   `flutter build web --release` ✓ Built build/web。
> - 待真机视觉走查（深浅两态、迁移路径、三风格切换回归）。
>
> 目标：彻底移除 `claude` 命名与旧视觉残留，以《Absolutely 风格全集》为准绳，
> 全面切换为 **Absolutely** 主题。触点审计：11 个 Dart 文件（24 处分支）+
> `web/index.html`。

## 决策点（默认按建议执行）

1. **持久化兼容**：枚举 id 改为 `absolutely`，`byId('claude')` 继续映射到
   absolutely（老用户无感），且首次解析到旧值时回写 prefs 完成一次性迁移。
2. **公开 API 改名范围**：`AppTheme.claudeSerif / claudeSans / claudeSubtitle /
   claudeSerifFallback / claudeColumn / claudeRail` 全部更名；组件
   `Claude* → Absolutely*`；`claude_widgets.dart → absolutely_widgets.dart`。
3. **终端/经典风格零回归**：两风格只跟随改名，不改视觉。

---

## P1 · 枚举与持久化（app_theme.dart / theme_provider.dart）

- [ ] `AppUiStyle.claude → AppUiStyle.absolutely`：
      `id='absolutely'`、`label='Absolutely'`、
      `blurb='暖纸编辑部 · 衬线标题 · 浅/深可调'`
- [ ] `byId`：`'claude' | 'absolutely' => absolutely`（兼容旧值）
- [ ] 启动时一次性迁移：读到 `'claude'` 即调用 `applyUiStyle` 回写
      `'absolutely'`（放 theme_provider 初始化处，带注释说明）
- [ ] `fixedThemeMode / blurb / 设置页三卡文案` 同步更名

## P2 · 主题层更名（app_theme.dart 内部 + 对外静态成员）

- [ ] `_claudeScheme → _absolutelyScheme`、`_claudeTheme → _absolutelyTheme`
- [ ] `claudeSerif → absolutelySerif`、`claudeSerifFallback → absolutelySerifFallback`
- [ ] `claudeSans → absolutelySans`、`claudeSansFallback → absolutelySansFallback`
- [ ] `claudeSubtitle → absolutelySubtitle`
- [ ] `cjkSansFallback / cjkSerifFallback` 保留（中性命名）
- [ ] `AppTokens.claudeColumn / claudeRail → absolutelyColumn / absolutelyRail`
- [ ] `readerFallbackFor` 分支同步
- [ ] 更新引用方：`reading_settings_sheet.dart`（claudeSerif/claudeSans）、
      `reader_screen.dart`（readerFallbackFor）、`home_shell.dart`（claudeRail）

## P3 · 图标层（app_icons.dart）

- [ ] `_claudeLine → _absolutelyLine`（Lucide 300 映射原样保留）
- [ ] `styled/styledAt` 注释措辞更新（"Absolutely 风格 outline-only"）
- [ ] 逻辑零改动——映射本身即 Absolutely 规范

## P4 · 组件层（claude_widgets.dart → absolutely_widgets.dart）

- [ ] 文件改名 + 类名：
      `AbsolutelyHeroBlock / AbsolutelyDividerGrid / AbsolutelyBannerCard /
      AbsolutelySpecimenTag`
- [ ] 引用方同步：`welcome_screen.dart`（BannerCard）
- [ ] 类注释改为引用《风格全集》章节号（§5/§6/§8）

## P5 · 分支点清扫（meow.dart / home_shell.dart / settings / reader）

- [ ] `meow.dart`：MeowPage、MeowEmpty、MeowLabel、MeowQueryField、
      MeowIconButton 的 `AppUiStyle.claude` 分支全部改为 absolutely
- [ ] `home_shell.dart`：品牌标、rail 分支改名
- [ ] `settings_screen.dart`：模式解锁判断、文案（"固定浅色"等沿用）
- [ ] `reader_palette.dart`：`forStyle` 分支 + canvas 注释
- [ ] `app_style_shell.dart`：`_ClaudeShell → _AbsolutelyShell`（渐变保留
      新纸色三段）
- [ ] `legal_texts.dart / settings 文案`：界面语言里"Claude"→"Absolutely"

## P6 · Web CSS 主题重写（web/index.html）

- [ ] `html[data-ui-style="claude"] → [data-ui-style="absolutely"]`
- [ ] 背景与 meta theme-color：`#faf9f5 → #F0EEE6`
- [ ] `::selection`：陶土洗（`rgba(217,119,87,.18)`）替换旧 `#f6e4db`
- [ ] 滚动条 thumb：墨色药丸（rgba(25,25,25,.16/.28)）——替换旧 `31,30,29`
- [ ] h1-h3 字栈：`absolutelySerif` 命名对齐（PTSerif 优先级不变）
- [ ] `setChlorisUiStyle('claude')` 兼容：JS 端把 'claude' 归一为
      'absolutely'（或依赖 Flutter 侧已迁移，仅改注释）

## P7 · 收尾强化（可选，本轮建议一并做）

- [ ] `MeowRule`：Absolutely 下标题规则线改为**短版**（左对齐 64px 墨色
      2px 短线 + 右侧余段发丝线），更接近刊头语法
- [ ] `AbsolutelyDividerGrid` 落地一个真实页面（设置页「关于」区三栏：
      版本/协议/致谢），验证分栏语法
- [ ] `AbsolutelySpecimenTag` 落地：书架"最近阅读"计数标签（fig. 语义）

## P8 · 验证与回归

- [ ] `dart analyze`：0 error / 0 warning
- [ ] 全局 grep：`lib/` 与 `web/` 内 `claude` 仅允许出现在
      byId 迁移映射与 JS 归一处（各 1 处，带注释）
- [ ] `flutter build web` 通过（index.html 引用无误）
- [ ] 手测清单：切换三风格 → Absolutely 浅/深/跟随、外观面板文案、
      欢迎页红陶卡、搜索药丸聚焦、书架/阅读器深浅两态、
      旧持久值 `'claude'` 启动迁移一次成功
- [ ] 终端/经典风格截图对比，确认零视觉回归

## 执行顺序与风险

P1→P2→P3→P4→P5 为一条**原子改名链**（必须一次性完成，中间态无法编译）；
P6 独立可并行；P7 可选；P8 收口。最大风险是漏改引用——
以 `dart analyze` 0 error 为唯一通过标准，预计全链一次过。
