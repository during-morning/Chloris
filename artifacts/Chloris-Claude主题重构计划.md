# Chloris · Claude 主题彻底重构计划

> **执行状态（2026-09-13）**：P1-P5 已全部实施完成，
> `dart analyze` 0 error / 0 warning（仅存量 info 级 lint）。
> 已落地：官方色表（象牙纸 `#F0EEE6` / 陶土 `#D97757` / 薰衣草辅助 /
> 暖黑深色）、Claude 浅/深可调、衬线字阶修订（永不加粗）、
> Lucide 1.5px 细线图标集（60 枚映射，outline-only 双级墨色）、
> 药丸按钮（墨黑主按钮）、卡片去边框、`ClaudeHeroBlock` /
> `ClaudeDividerGrid` / `ClaudeBannerCard` / `ClaudeSpecimenTag`
> 组件库、MeowEmpty 空状态升级为官方英雄构图、MeowPage eyebrow
> 去大写、书架纸白调色板对齐 `#F0EEE6`。
> 待办：P6 逐屏视觉走查（需真机/模拟器跑起来看）。
>
> 依据：Claude 官方 6 张参考截图（深色错误页、深色功能网格、浅色官网、
> 复古画意场景、剪影标本标签、红陶 Fable 5 字卡）+ 现有
> `chloris/lib/app/theme/app_theme.dart` 代码盘点。

## 〇、Claude 风格定调（分析结论）

### 色彩
| 角色 | 浅色 | 深色 |
|------|------|------|
| 画布 | 象牙纸 `#F0EEE6`（深层 `#E8E6DE`） | 暖黑 `#1F1E1D`（深层 `#191817`） |
| 墨色 | 近黑 `#191919` | 奶油白 `#F0EEE6` |
| 次级文字 | 暖灰 `#6E6A61` | 暖灰 `#B8B5AD` |
| 主强调（陶土） | `#D97757`（省用：主按钮/徽标/选中态） | `#E08A66` |
| 辅助强调 | 薰衣草 `#C6C1F0` 底 + 深字（NEW 徽章类） | 同系暗版 |
| 发丝线 | `#E4E0D5` / 强线 `#C6C0B2` | `#3C3A36` / `#6A655C` |

铁律：**陶土色只出现在主操作与极少数强调**；图标永远单色（墨/暖灰），
永不带色；无阴影、无渐变、无彩色大面。

### 字体
- 展示层（大标题、区块标题、部分副标题）：现代衬线（Copernicus 气质：
  笔画对比强、紧字距 -0.5~-2%、字重 400-500 永不加粗）
- UI 层（按钮、标签、正文）：人文无衬线（Styrene 气质）
- 中文：衬线槽位 NotoSerifSC/Songti，无衬线槽位 NotoSansSC/PingFang

### 图标
- 官方语言：**纯细线**（约 1.5px 描边、圆角端点/圆角拐点、几何骨架、
  20px 网格），永远单色、**从不填充**
- 选中/激活态：换**墨色深浅**（onSurface vs onSurfaceVariant），
  不切换 outline→filled
- 现状冲突：`app_icons.dart` 的 `AppIconPair.resolve` 在 active 时直接
  切 Cupertino 填充图标（`book_fill` 等），需要为 Claude 风格改为
  "outline-only + 双级墨色"

### 布局语法（签名模式）
1. **分隔线网格**：用 1px 竖线/横线分栏，不用卡片盒子（图2）
2. **居中英雄构图**：细线图标 → 衬线大标题 → 灰色窄栏副标题（图1、2）
3. **药丸按钮**：黑/墨色实心胶囊为主，细描边胶囊为次（图1、3）
4. **窄栏编辑排版**：正文约 46-60ch，超大留白
5. **表达层**：复古画意插画、剪影容器 + 标本标签卡、红陶海报卡
   （图4、5、6）——用于空状态、引导页、公告横幅等"时刻"

### 整体排版（字阶与节奏）
- 展示层衬线**永不加粗**（w400-w500），字距随字号增大而收紧
  （44px 级 -1.5%~-2%，22px 级 -0.5%，正文 0）
- 副标题也是衬线（官网 "Hybrid reasoning model…" 做法），
  这是现在缺的槽位
- 无衬线只管 UI 层：按钮、标签、正文、辅助说明；
  标签**不用宽字距大写**（官方无工业标签风）
- 垂直节奏：区块间距 40/48、元素间距 12/16/24，4pt 网格；
  居中构图区块上下留白 ≥48
- 对比锚点：一个区块内最多两级字重（衬线标题 + 无衬线正文），
  靠字号与颜色分层，不靠加粗

## 一、重构步骤

### P1 · Token 层重建（app_theme.dart / app_tokens.dart）
- [ ] 按 0 节色表重写 `_claudeScheme`：纸色改 `#F0EEE6` 系，
      陶土改 `#D97757`（暗版 `#E08A66`），新增薰衣草辅助色
      （挂 tertiary 或 AppColors 新槽位）
- [ ] 新增 **Claude 深色模式**：`fixedThemeMode` 从锁定 light 改为
      可选（设置里加"浅/深/跟随"），深色严格按官方暖黑色表
- [ ] 按钮/输入半径 8 → **药丸化**（按钮 999，输入框保持 10-12）
- [ ] AppColors 增加语义槽：`lavender`、`paperDeep`、`specimenPaper`

### P2 · 字体层
- [ ] 评估衬线替换：候选 Source Serif 4（已装）/ 加载更贴近
      Copernicus 的开源现代衬线；若维持 PTSerif 则调大字号、收紧字距
- [ ] 展示层副标题改衬线（官网做法），标题字重降到 w400-w500
- [ ] 验证 CanvasKit 下 CJK 回退不破坏图标 PUA（沿用现有注释的教训）

### P2 · 排版系统（字阶 · 节奏 · 栅格）
- [ ] 字阶修订（对照官方）：
  - display/headline：保持衬线，字重 w500→**w400-w500**，
    displayLarge 字距收紧到 -1.8~-2%
  - titleLarge：衬线 w600→**w500**（官方衬线无加粗）
  - 新增**衬线副标题槽位**：titleMedium/titleLarge 下挂
    `height 1.45 + onSurfaceVariant` 衬线变体（供英雄区副标题）
  - labelSmall：去掉 1.6 宽字距 + w600 的工业标签风，
    改 w500 / letterSpacing 0.2-0.4
  - 正文 measure：body 区块最大宽度 `AppTokens.claudeColumn` 内
    再约束 46-60ch（约 620-680px）
- [ ] 垂直节奏明文化：区块间 40/48、组间 24、元素间 12/16，
      补进 `AppTokens` 并在设置页/首页落一版校准
- [ ] 英雄构图组件 `ClaudeHeroBlock`：居中细线图标(40) →
      衬线标题(displaySmall) → 窄栏副标题(bodyLarge 灰)，
      上下留白 ≥48 —— 空状态/引导/设置分区头共用
- [ ] 栅格：列表页统一 maxListWidth 960 + 内容列 720；
      阅读器保持 maxReadWidth 760

### P3 · 图标系统
- [ ] Claude 风格切换为 **outline-only**：`AppStyleExtension` 增加
      `filledIcons: bool`（claude=false, terminal=false, classic=true），
      `AppIconPair.resolve` 按风格决定是否切填充
- [ ] 激活态双色规则：active=onSurface（墨），inactive=onSurfaceVariant
      （暖灰），封装成 `AppIconPair.resolveClaude(active)`
- [ ] 线重：评估为 Claude 风格引入细线图标集（Lucide，1.5px、圆端点、
      MIT）替换 Cupertini——先替换高频 30 枚（导航 4 + 常用操作），
      其余继续用 Cupertino outline 过渡；Stroke 不做运行时参数
- [ ] 尺寸规范：导航 24 / 行内 20 / 卡片角标 18，图标永不带色
      （陶土色只给 Logo 与极少数强调点）
- [ ] 空状态/引导的大图标（40-48px）统一走 `ClaudeHeroBlock`，
      不再散落各屏

### P4 · 组件语法（新建 app_widgets / 改造现有）
- [ ] `ClaudeDividerGrid`：发丝线分栏网格组件（替代功能卡片矩阵）
- [ ] 主按钮：墨黑实心胶囊（白字）；次按钮：细描边胶囊——
      陶土实心只留给"最关键的单个动作"
- [ ] 卡片降级：默认无框（surface 同色），hover/选中才浮现发丝线；
      保留"细线面板"变体给确实需要边界的场景
- [ ] 空状态组件：居中细线图标 + 衬线标题 + 窄栏灰字（图1 语法）

### P5 · 表达层（宣传片资产反哺 App）
- [ ] 公告/横幅卡：红陶底 + 白衬线 + 细网格纹（图6 语法）
- [ ] 引导/特色页：剪影容器 + 标本标签卡构图（图5 语法）
- [ ] 空状态插画位：预留复古画意插画槽（图4 语法，可后补素材）

### P6 · 逐屏落地与验收
- [ ] 设置页（外观选择器三卡）、书架/首页、阅读器 chrome、
      弹窗/底部面板/SnackBar 全部过一遍组件映射
- [ ] 验收清单：无阴影、无彩色图标、无填充图标（Claude 风格内）、
      衬线无加粗、陶土出现频次、深浅两态对比度（AA）、CJK 无豆腐、
      终端/经典主题零回归

## 二、开放决策点
1. 深色模式：做成 Claude 风格内可选，还是保持锁定浅色？（建议：可选）
2. 衬线字体：换字体（包体增加）还是 PTSerif 调参？（建议：先调参，
   证实差距大再换 Source Serif 4）
3. 图标：引入 Lucide 细线集替换高频 30 枚（建议：是，MIT 无风险），
   还是全部保留 Cupertino outline-only？
4. 表达层（P5）是否本期做，还是先交付 P1-P4、P6？（建议：分两期）
