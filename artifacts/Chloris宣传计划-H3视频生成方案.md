# Chloris 宣传计划 —— 参考 Claude 宣传片 × MiniMax H3 生成 × 命令行直拼

> 2026-09-12 起草，多轮修订。参考片：BV129tL6bEDB（Claude Fable 5.1 宣传短片）、BV1xeMs6vEev（Claude 大脑讲解视频）、BV1RedLB6E8J（Claude Design 来了）。
> 生成管线：MiniMax H3（Hailuo 3.0）API 文生/图生视频（国内平台 platform.minimax.cn）；后期由 AI 助手用 ffmpeg + Real-ESRGAN 命令行直接拼接成片（无 Pr）；工作目录 `trail/`。

---

## 一、参考片风格解析

### 1. BV129tL6bEDB《Claude Fable 5.1 宣传短片》—— 主参考

- **基本参数**：28 秒，2160×2160（1:1 方形，适配 X/社媒流），转自 x.com，属官方发布物。
- **视觉语言**（据封面与首帧确认）：
  - **暖色胶片质感**：柔焦、细颗粒，像 Kodak Portra 胶片扫出来的画面；
  - **自然意象**：云、小鸟栖枝、柔和的天空渐变——全部是缓慢、安静、有生命感的东西；
  - **奶油/暖米色调**：低饱和暖色，不出现高对比冷色；
  - **衬线大字标题**：白色衬线体（Anthropic 御用 Copernicus/Tiempos 一路）直接压在画面上，一屏一句，不贪多；
  - **克制运镜**：几乎没有镜头运动，靠被摄物自身的微动（云飘、鸟转头）制造生命感；
  - **博物学画意**（B 站评论区共识）：画面在「复刻科学史经典时刻」，前段是 19 世纪维多利亚博物学黄金时代的画作质感——动植物版画、图谱式构图、纸上肌理。
- **叙事结构**：意象铺陈 → 版本号字卡点题。一条镜头只说一件事。

### 2. BV1xeMs6vEev《Claude 的大脑中心在想什么》—— 结构参考

- **基本参数**：4 分 11 秒，1920×1080，知识讲解向，极致配音 + 章节化进度（00:00 起每 30–50 秒一节）。
- **视觉语言**（据封面确认）：
  - **油画隐喻 + token 文字流**：左侧是古典油画（海浪帆船），右侧把同一意象「解构」成重复的 CLOUDS / OCEAN / BOAT 文字矩阵——具象与抽象对照，直指「AI 内部表征」这个主题；
  - **封面即论点**：大号白字黑边标题「AI也有潜意识」直接喊出钩子；
  - **章节化**：每节一个实验/一个概念，节奏均匀。

### 3. BV1RedLB6E8J《Claude Design 来了》—— 官方视觉语法全参考

82s 讲解片（内嵌官方片段），五帧截图覆盖 Claude 宣传的全部标志性语法（已入库 `brand/ref/`，可直接喂 H3 当风格参考）：

| 语法 | 截图 | 要点 |
| --- | --- | --- |
| 复古油画隐喻 | `claude-油画隐喻.png` | 哑光复古海浪帆船，旧书插画质感，隐喻「意识物流」 |
| 剪影容器 + 标本标签卡 | `claude-剪影容器标签卡.png` | 头部剪影内嵌隐喻场景，白色小标签（Clouds/Boat/Ocean）钉在场景上 |
| 细线圆角框 + 打字点 | `claude-对话框与token网格.png` `claude-细线圆角框.png` | 粉/黄纯色面板 + thin-outline 圆角卡片 + 「…」打字点，像思维气泡 |
| token 网格 | 同上 | 微缩文字瀑布铺满半屏，表现「内部激活」 |
| 红陶大字卡 | `claude-红陶字卡蝴蝶.png` | 红陶底 + 细网格纹理 + 白色衬线大字（Fable 5）+ 蝴蝶标本散布 |
| 双语字幕 | 各帧 | 中文大字 + 英文小字——讲解片做法，宣传成片不用 |

### 4. 提炼出的五条可复用法则

1. **隐喻先行**：不拍功能拍感觉——用「自然生长」类的具象意象承载抽象卖点；
2. **字卡点题**：AI 画面里不放字，全部关键文字用后期字卡，衬线体、大留白；
3. **一条镜头一件事**：单镜单动作单运镜，信息量宁少勿多；
4. **统一暖色**：全片锁一套暖色调，冷色只做点睛；
5. **声音完整**：环境音 + 克制的配乐，安静本身就是高级感。

---

## 二、Chloris 品牌基调与契合度

品牌素材（`brand/icon.png`、`brand/banner.png`）已确认：

- **配色**：奶油底（#F6EFE3 附近）、鼠尾草绿衬线字、花体珊瑚粉/万寿菊黄/橄榄绿、暖棕书壳；
- **符号**：一本摊开的书，花从书页里生长出来；
- **Slogan**：「让阅读，自然生长。」

**结论**：Chloris 的品牌气质与 Fable 5.1 宣传片几乎同源（暖色、自然、衬线、留白），风格迁移不需要翻译，直接沿用即可。核心视觉隐喻就用品牌符号本身——**书页里长出花**。

**成片风格定调（重要）——全面融合 Claude 视觉语法**，按镜头分两条风格通道，色板统一暖色：

- **画意通道**（镜 1/2/3/6）：`vintage storybook painting`——复古书页插画/油画质感、博物学图谱构图、哑光旧纸肌理。花从书页生长、读者剪影里藏书海，都是这条通道；
- **图形通道**（镜 5）：`flat pastel panel + thin outlined card`——奶油/暖粉纯色面板 + 细线圆角框 + 打字点 + 微缩 token 网格，对应阅读行为的「思维感」；
- **字卡通道**（镜 7）：红陶底 + 细网格 + 白色衬线大字 + 蝴蝶，直接复刻 Fable 5 字卡；镜 8 保持奶油底收尾；
- 不再是单一扁平矢量风：扁平元素集中在图形镜与字卡，场景镜用复古画意——这正是 Claude 官方物料「油画隐喻 × 扁平图形」混搭的做法。UI 三镜（真实截图）天然介于两者之间，无需处理。`brand/ref/` 五张参考图可作 r2v 风格参考（声明「图片 N 只控制风格」）。

---

## 三、成片规划

### 交付物

| 版本 | 时长 | 画幅 | 用途 |
| --- | --- | --- | --- |
| 主宣传片 | 30s | 16:9（B 站/视频号主发） | 正式发布 |
| 方形版 | 同素材重排 | 1:1 | X / 小红书（对标 Fable 5.1 的 1:1 规格） |
| 讲解版（可选二期） | 60–90s | 16:9 | 参考BV1xeMs6vEev 的章节化结构，配旁白讲功能 |

### 分镜表（一条出方案：前 15s 氛围 + 后 15s 功能 = 30s）

> 应对「一条出、40s 内」：H3 单次上限 15s，主链按**前 15s / 后 15s** 组织；功能介绍画面（真实 UI）增加到三处，与氛围镜头**无缝混排**——每处转场都借「花瓣糊满 / 光斑聚焦」做 match cut，功能画面像从隐喻里自然长出来；文字全部直接交给 AI 生成。

| 段 | 时间 | 画面 | 介绍什么 |
| --- | --- | --- | --- |
| 链 A | 0–10s | 晨光书桌静谧（0–3s）→ 书本自开、花从书页生长（3–10s），**结尾花瓣扑向镜头糊满画面**（转场铺垫） | 隐喻：阅读自然生长 |
| UI① 书库 | 10–14s | **真实 UI**：从光斑朦胧**聚焦**到书库界面，光标点「导入本地书」 | 功能：本地导入 TXT/EPUB |
| 链 B | 14–22s | 从界面光晕中浮出「书海」，读者剪影浮现、三张标本标签卡钉上，**结尾光斑收拢** | 隐喻：万千书源汇于一处 |
| UI② 详情 | 22–26s | **真实 UI**：书籍详情页，光标点「开始阅读」，换源/缓存按钮入画 | 功能：换源、缓存下载 |
| UI③ 阅读器 | 26–29s | **真实 UI**：阅读器翻页，排版/配色面板一现 | 功能：排版可调、翻页顺滑 |
| 结尾卡 | 29–30s | 红陶底 +「Chloris」+「让阅读，自然生长。」+ 蝴蝶（**AI 直接生成文字**，压 1s 定格也算一镜，与 UI③ 合并为一次 4s 生成的后段） | 定位 + slogan 收口 |

> **无缝混排的四处接缝**：① 链 A 花瓣糊满 → UI① 光斑聚焦到界面；② UI① 点击后光效 → 链 B 从光晕浮出剪影（链 B 用链 A 成品作 r2v 风格参考，保证同画风）；③ 链 B 光斑收拢 → UI② 详情页；④ UI③ 翻页微光 → 结尾卡。所有接缝两端都是「暖光/光斑」语言，观感是同一个连续世界。

> **文字策略（按用户定调）**：全部直接交给 AI——结尾卡不再预制 PNG，红陶底 +「Chloris」+「让阅读，自然生长。」直接写进提示词由 H3 生成；文字保持极短（卡片上 ≤10 字），roll 时挑字形最正的一版；UI 画面文字由真实截图保证。`build_vectors.py` 首帧管线移出主流程（如 AI 卡文字反复出错再启用作为兜底）。

### 开工素材清单（全部进入流水线的东西，工作目录 `trail/`）

| 类别 | 素材 | 来源 / 生成方式 | 状态 |
| --- | --- | --- | --- |
| 品牌类 | `brand/icon.png`、`brand/banner.png` | 已有 | ✅ |
| UI 类 | `brand/ui/书库.png`、`书籍详情.png`、`阅读器.png`（真实 UI 截图，i2v 首帧） | 已入库 | ✅ |
| 风格参考 | `brand/ref/claude-*.png` ×5（官方视觉语法：油画隐喻/剪影标签卡/token 网格/细线框/红陶字卡） | 已入库，可作 r2v 风格参考 | ✅ |
| 音频类 | **BGM MP3：`trail/bgm-ethereal-ai.mp3`**（已从 1600877923-1-192.mp4 提取，167s，上传 H3 做音频参考 + 成片铺底两用） | ✅ 已提取 |
| 文字类 | 无预制 PNG——文字全部直接交给 AI 生成（结尾卡文字写进提示词；UI 文字由真实截图承担） | — | ✅ 简化 |
| AI 生成类 | 生成素材 5 件：链 A（10s t2v）、UI① 书库（4s i2v）、链 B（8s r2v，链 A 作风格参考）、UI② 详情（4s i2v）、UI③+结尾卡（4s i2v），全部 768P | H3 API | 待做 |
| 工程类 | `trail/raw/`（H3 原始素材）、`trail/out/`（成片）；ffmpeg 8.1.2 + Real-ESRGAN | ffmpeg 已就绪（/opt/homebrew/bin），待装 Real-ESRGAN | 半就绪 |
| 字体类 | 思源宋体（字卡首帧用，OFL 可商用） | Google Fonts | 待下 |

---

## 四、MiniMax H3 使用要点（调研结论）

### 4.1 模型规格速查

- **官方名称**：MiniMax H3（即 Hailuo 3.0 / Hailuo-03），2026-07-31 发布，API 模型名 `MiniMax-H3`；
- **输出**：768P 与 2K 两档，24fps，**原生 32kHz 立体声**（画面与声音同一次推理生成，对口型、音画同步）；
- **时长**：4–15 秒，整数秒——所以分镜按 4–6s 一镜设计；
- **提示词**：上限 7000 字符，中文可直接使用；复杂场景建议写到 350–450 词；
- **参考素材**：单次最多 12 个文件（9 图 + 3 视频 + 3 音频），**每个素材必须在提示词里声明职责**（如「图片 1 只控制环境与光线」）；
- **国内官方刊例价**（platform.minimax.cn「Token 计划 · API 企业」页，2026-09 查证）：
  | 项目 | 价格 |
  | --- | --- |
  | 生成视频 2K | ¥0.80/秒 |
  | 生成视频 768P | ¥0.50/秒 |
  | **视频再生成 768P → 2K** | **¥0.30/秒**（草稿定稿后转 2K 走这条，比直接渲 2K 便宜） |
  | 输入图片 | 5 张以内免费，超出 ¥0.20/张 |
  | 输入音频 | 免费 |
  | H3-Context-IR（官方结构化预处理） | 输入 ¥5.80/百万 tokens、输出 ¥23.00/百万 tokens |
- **平台域名**：国内 `platform.minimax.cn`（本项目使用），国际 `platform.minimax.io`；开放权重 33B 已开源（MiniMax Community License，年营收 < $2000 万的组织可商用）。

### 4.2 三种生成模式（按附带素材自动路由）

| 模式 | 输入 | 本片用途 |
| --- | --- | --- |
| t2v 文生视频 | 纯提示词（必须显式指定画幅） | 镜 1/2/3/5/6 主体 |
| i2v / flf 首尾帧 | 首帧图（±尾帧图） | **镜 4a–4c 真实 UI 截图、镜 7/8 字卡 PNG**（文字保真的关键） |
| r2v 参考生成 | 提示词 + 参考图/视频/音频（各司其职） | 可选：丢品牌横幅图控制色调、丢运镜参考视频控制镜头 |

### 4.3 提示词公式（H3 是「结构化文档」模型，不是聊天模型）

官方管线内部有一个 H3-Context-IR 预处理器把随意的话改写成结构；走 API 直连基础模型时**你就是预处理者**。按此结构写：

```text
integrated_multimodal_description:
  [Shot 1] 视觉风格 + 初始构图 + 主体 + 动作 + 运镜（按播放顺序写）
  （多镜头时：[Shot 2] At 00:04.500, ... 时间戳严格递增）
overall_soundscape: 环境音、动作音、呼吸衣物声（1–4 句，不写对白和配乐）
non_diegetic_music: 画外配乐（写具体乐器和动态，禁止「紧张的氛围音乐」这类抽象词；无配乐写 N/A）
```

**十条军规**（来自多篇 H3 提示指南的共识）：

1. **一次生成只用一种运镜**（固定/推进/环绕/跟拍/拉远，选一个写死）；写「固定机位、不切镜头」可防止镜头乱动；
2. 禁用「电影感」这类空词替代具体镜头指令——H3 不猜；
3. i2v 时**首行写保护声明**：哪些元素不许变（Logo、外形、配色）；
4. 每张参考图只分配**一个职责**，否则模型会全部混在一起；
5. 一个场景一个动作，不要给 6 秒写 3 个情节节拍；
6. 对白用时间段标注（0–5 秒 A 说……），一次只让一人说话；
7. 配乐写乐器与节奏（「稀疏钢琴慢速单音 + 渐强低音提琴」），不写情绪词；
8. 声音要写具体（脚步材质、雨声大小），「好听的背景音」会生成平庸音景；
9. 迭代法：先 768P 草稿 → 找最大问题 → **只改一处** → 固定 seed 重roll → 定稿走本地超分（4.6），预算宽裕再考虑 2K；
10. 不要让 AI 裸写文字——含字画面一律走「首帧保真法」（`build_vectors.py` 或真实截图先定字形，AI 只加动效），裸生成的中文/长句字形必错。

### 4.4 官方 API 调用（✅ 2026-09-13 实测通过）

**端点**：`https://api.minimax.cn/v2/video_generation`（注意：H3 必须用 **V2**，打 `/v1/video_generation` 会提示「该模型请使用 /v2/video_generation 接口」）。

**请求**（JSON，实测有效字段）：

```bash
curl -X POST "https://api.minimax.cn/v2/video_generation" \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "MiniMax-H3",
    "content": [{"type": "text", "text": "<提示词，含标准信息头>"}],
    "duration": 10,
    "resolution": "768p",
    "ratio": "16:9"
  }'
# 成功返回 {"task_id":"441173813166367"}
```

实测要点：
- 提示词放 **`content` 数组**（`[{"type":"text","text":...}]`），不是顶层 `prompt`；
- 画幅字段名是 **`ratio`**（`aspect_ratio` 会被忽略，t2va 纯文本场景必须显式指定且不能为 adaptive）；
- 可用值：`ratio: 16:9/4:3/1:1/3:4/9:16/21:9`；分辨率 `768p/2k`；`duration` 整数 4–15；
- 参考素材同样放 `content` 数组（如 `{"type":"image","url":...}`、`{"type":"video",...}`、`{"type":"audio",...}`）；
- 任务查询：`/v2/query/video_generation?task_id=`（备选 `/v1/query/video_generation`），轮询脚本：`trail/tools/poll_download.py <task_id> <out>`；
- 音频参考（BGM MP3）与首帧/风格参考图按 4.5 的职责声明写进提示词文本。

### 4.5 给歌卡点（《Ethereal》驱动节奏）

歌曲要「喂给 AI + 后期卡点」两头用（BGM：**`trail/bgm-ethereal-ai.mp3`**，已从 1600877923-1-192.mp4 提取，167s，即传即用）：

1. **生成端（r2v 音频参考）**：把音频文件与提示词一起提交（`audio` 参数 + r2v 模式），提示词里声明职责——`Audio 1 only controls rhythm and dynamics, not content`。画面内部动作（花瓣绽开、翻页、光斑流动）会跟着节拍走。音频输入免费；无音频参考时 t2v/i2v 也可单独提交，只是动效不保证踩拍。
2. **后期端（ffmpeg 卡点拼接，由 AI 助手执行）**：
   - 高仿曲铺主音轨，先用 Python/ffmpeg 做节拍检测（onset/重拍时刻列表），或按波形手动指定；
   - 所有镜头切点落在重拍上；镜长取整拍/整小节倍数（按曲子实际 BPM 换算，拼接前核对）；
   - 链 A 的花绽放高潮、链 B 的光斑收拢，分别对准曲子的情绪起伏点（前奏结束、主歌进入）；
   - H3 镜头自带的原生音轨压到 -12dB 只当环境音（`volume=-12dB` + `amix`），主旋律一律用高仿曲，避免打架。

### 4.6 清晰度方案：768P 直出 + 本地超分（省钱关键）

不再购买「768P→2K 再生成」（省 ¥11），改为 768P 直出 + 免费本地超分：

1. **工具**：Real-ESRGAN（开源免费）的 **realesr-animevideov3** 模型——专为插画/动画视频设计，对本片的油画色块风格极友好；GUI 可用 Video2X，或一行命令：
   `realesrgan-ncnn-vulkan -i 链A.mp4 -o 链A_1080p.mp4 -n realesr-animevideov3 -s 2`
2. **目标**：768P → 1440p/1080p 输出，交付 1080P（B 站/视频号上传后还会二压，1080P 与 2K 观感几乎无差）；
3. **文字软肋与对策**：超分对油画/扁平色块效果好，但对小字边缘偏软——UI① 与字卡①②的文字画面多 roll 几次挑字形最锐的一版；精细图形镜（「正在打开」token 网格）留二期，必要时单独重生成；
4. 音频不受影响（H3 音轨只留环境音，主旋律是《Ethereal》原曲）。

---

## 五、逐镜提示词（可直接复制到 API）

一条出方案的提示词按「链」组织。全部 768P 草稿、16:9；i2v 镜不传 aspect_ratio（跟随首帧）。中文提示词可用，结构字段名保留英文原文。

### 标准信息头（每条提示词都以它开头）

按用户定调，每条提示词先给足三层信息——**项目语境 → 风格定义（Claude 人文科技风）→ 排版规格**——再进入镜头内容；并显式授权 AI 在色板与情绪内自行补足细节（"让 AI 自己长入"）。模板如下，粘贴在每条提示词最前面：

```text
CONTEXT: This clip is one shot of a 30-second brand film for "Chloris", a cross-platform reading app that reads Legado-compatible online book sources and local TXT/EPUB/MOBI/PDF files. The film's mood: quiet, warm, unhurried intelligence — reading as something that grows naturally.
STYLE: Claude-style humanist tech aesthetic. Vintage storybook oil painting on aged cream paper (#F6EFE3), muted palette of sage green, coral pink, marigold yellow and warm brown; painterly brush texture, subtle paper grain. Editorial composition: generous margins, rule-of-thirds, one clear focal point per shot. Wherever text appears: elegant serif letterforms, generous letter-spacing, clear size hierarchy, aligned baselines. No photographic realism, no neon, no cyberpunk, no cold blue tones.
IMPROVISE: You may freely add small in-world details — drifting dust motes, stray petals, tiny wildflowers, faint marginalia on pages — as long as they stay inside the palette and the calm mood.
```

**排版规格细化**（各镜在信息头之后追加对应的 Typography/Composition 行）：

- 书桌/书页镜：`Composition: book pages show a single centered column of serif text with wide line spacing, large even page margins, a small chapter heading top-center; desk items arranged on rule-of-thirds lines.`
- UI 镜：`Composition: preserve the screenshot's exact layout grid — header bar, content column, button hierarchy, consistent spacing; motion must not shift or reflow any element.`
- 结尾卡：`Typography: "Chloris" in large white serif (about one quarter of card height), tagline "让阅读，自然生长。" one line below at one third that size, wide letter-spacing, both vertically centered with a 2:1 top-to-bottom margin ratio; three butterflies scattered asymmetrically (upper right, lower left).`

**全片风格通道**：场景链统一锁定 `Vintage storybook oil painting, muted antique tones, aged paper texture`；字卡走红陶/奶油纯色。禁词不变：任何提示词里出现 Live-action / cinematic / film grain 都会跑偏。`brand/ref/claude-*.png` 五张官方截图可作 r2v 风格参考图（声明「图片 N 只控制风格，不控制内容」）。

### 链 A｜书桌 → 花生长（t2v，duration=10，信息头已拼入）

```text
CONTEXT: This clip is one shot of a 30-second brand film for "Chloris", a cross-platform reading app that reads Legado-compatible online book sources and local TXT/EPUB/MOBI/PDF files. The film's mood: quiet, warm, unhurried intelligence — reading as something that grows naturally.
STYLE: Claude-style humanist tech aesthetic. Vintage storybook oil painting on aged cream paper (#F6EFE3), muted palette of sage green, coral pink, marigold yellow and warm brown; painterly brush texture, subtle paper grain. Editorial composition: generous margins, rule-of-thirds, one clear focal point per shot. Wherever text appears: elegant serif letterforms, generous letter-spacing, clear size hierarchy, aligned baselines. No photographic realism, no neon, no cyberpunk, no cold blue tones.
IMPROVISE: You may freely add small in-world details — drifting dust motes, stray petals, tiny wildflowers, faint marginalia on pages — as long as they stay inside the palette and the calm mood.
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. Fixed medium shot, camera still: a closed warm-brown book rests on a simple wooden desk beside a small ceramic cup, soft morning light falls across the scene in gentle painted rays, tiny dust specks drift slowly as glowing dots. Composition: book on the lower-left third line, cup on the right third, generous empty desk margin. The open pages show a single centered column of serif text with wide line spacing once the book opens.
[Shot 2] At 00:03.000, the book opens by itself and the camera pushes in very slowly; delicate wildflowers in coral pink, marigold yellow and sage green grow and bloom out from between the pages, stems unfurling in smooth elegant curves, like a Victorian botanical plate coming alive. The book shape and cover stay unchanged.
[Shot 3] At 00:08.000, a burst of petals lifts off the pages and flies toward the camera, softly filling the entire frame with warm blurred coral and cream tones at the end — a ready transition for a match cut.
overall_soundscape: Quiet room tone, a distant bird, then soft paper rustling and delicate stem-and-petal rustle as flowers grow, ending in a soft whoosh of petals.
non_diegetic_music: Sparse piano single notes at a slow tempo, entering gently.
```

> 其余各镜提交时同样把「标准信息头 + 对应排版规格行」粘贴在提示词最前，下文各镜只展示镜头内容部分，不再重复信息头。

### 链 B｜光晕 → 书海剪影（r2v 独立生成，duration=8，音频参考=bgm-ethereal-ai.mp3）

> 链 B 前面隔了 UI① 书库镜，无法用延长模式接链 A——改为**独立生成**：`video` 参数传链 A 成品作参考（`Video 1 only controls painting style and palette, not content`），保证两条链同画风；`audio` 参数传 BGM MP3（`Audio 1 only controls rhythm and dynamics`）。

```text
Video 1 only controls painting style, palette and texture, not content. Audio 1 only controls rhythm and dynamics.
[标准信息头：CONTEXT + STYLE + IMPROVISE，同链 A]
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. The shot opens inside a soft warm glow of light; a rolling miniature sea of open book pages emerges from the glow, then is revealed to be inside the solid dark silhouette of a reader's head in profile, with no face. Three small ivory label cards with thin borders pop onto the scene one by one like specimen tags, each bearing one short English word: "Title", then "Chapter", then "Progress". In the final two seconds the painted light gently gathers and narrows into a bright soft glow, ready for a match cut.
overall_soundscape: Page-wave rustling like a distant sea swelling, then quieting down.
non_diegetic_music: Piano joined by a soft warm string swell, resolving gently.
```

> 标签词 roll 出错字就删掉三个词改成空白标签；链 B 崩了只重 roll 链 B，链 A 不动。

### 插镜与结尾卡（功能画面无缝混排）

按播放顺序四段，全部 i2v（duration=4，首帧=真实截图/参考图，不传 aspect_ratio）；BGM MP3 作音频参考让点击与翻页动效踩拍：

1. **UI① 书库**（首帧 `brand/ui/书库.png`）：提示词见下方镜 4a——开场一句改为「the frame starts slightly hazy in warm light and focuses onto the interface」（接链 A 花瓣糊满）；
2. **UI② 详情**（首帧 `brand/ui/书籍详情.png`）：提示词见镜 4b，结尾「光标点击后界面轻微放大」接 UI③；
3. **UI③ 阅读器**（首帧 `brand/ui/阅读器.png`）：提示词见镜 4c，结尾「翻页后画面微微提亮虚化」接结尾卡；
4. **结尾卡**（**文字直接 AI 生成，t2v，duration=4**）：

```text
[标准信息头：CONTEXT + STYLE + IMPROVISE，同链 A]
integrated_multimodal_description:
[Shot 1] Flat graphic card in warm terracotta red with a faint thin grid texture, in the style of a vintage naturalist poster. Centered white serif wordmark "Chloris", beneath it one line of small white serif text "让阅读，自然生长。", and a few delicate butterflies fluttering slowly around the letters. A very soft warm light sweep crosses the card once; the letters stay crisp and still, only butterflies and light move. Camera completely still.
Typography: "Chloris" in large white serif (about one quarter of card height), tagline "让阅读，自然生长。" one line below at one third that size, wide letter-spacing, both vertically centered with a 2:1 top-to-bottom margin ratio; three butterflies scattered asymmetrically (upper right, lower left).
overall_soundscape: Very quiet room tone, a faint wing flutter.
non_diegetic_music: N/A
```

> 结尾卡文字极短（卡上 ≤10 字），roll 出错字就重 roll；若 AI 卡文字反复失败，兜底方案：恢复 build_vectors.py 预制首帧 PNG 再 i2v（管线已留档）。

### 备用素材库（单镜版提示词，改回分镜方案或做二期时用）

以下为分镜方案的逐镜提示词，链式方案未用到的部分留作素材库。

### 镜 1｜晨光书桌（定调）

```text
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. A fixed medium shot, camera does not move: a closed warm-brown book rests on a simple wooden desk beside a small ceramic cup, soft morning light falls across the scene in gentle painted rays, tiny dust specks drift slowly as glowing dots. Muted palette of cream, sage green, coral pink, marigold yellow and warm brown, painterly brush texture like an old naturalist illustration, no photographic realism.
overall_soundscape: Quiet room tone, a distant bird outside the window, faint rustle, soft clock ticking far away.
non_diegetic_music: Sparse piano single notes at a slow tempo, entering gently after two seconds.
```

### 镜 2｜花从书页生长（核心隐喻）

```text
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. Close-up of an open book lying on cream linen, composed like a Victorian botanical plate. The pages stir, then delicate wildflowers in coral pink, marigold yellow and sage green grow and bloom out from between the pages, stems unfurling in smooth elegant curves, petals painted like a naturalist field-sketch coming alive. Camera: slow push-in, constant speed, no other camera movement. The book shape and cover stay unchanged.
overall_soundscape: Soft paper rustling, a gentle breeze, delicate stem-and-petal rustle as flowers grow.
non_diegetic_music: Warm string swells, slow and gentle, gradually joined by a soft glockenspiel.
```

### 镜 3｜读者剪影 × 书海（Claude 标志性构图）

```text
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. Fixed camera: the solid dark silhouette of a reader's head in profile fills the frame; inside the silhouette there is no face — instead a miniature sea of open book pages rolls like ocean waves, and small coral flowers rise from the waves like sailing ships. Three small ivory label cards with thin borders pop onto the scene one by one like specimen tags, each bearing one short English word: "Title", then "Chapter", then "Progress". Warm cream border surrounds the silhouette, subtle paper grain.
overall_soundscape: Soft page-wave rustling like a distant sea, quiet room tone.
non_diegetic_music: Sparse piano single notes at a slow tempo.
```

> 标签词用短英文（对齐参考片的 Clouds/Boat/Ocean，H3 对短英文单词成功率远高于中文）；roll 后仍错字就改用**空白标签卡**（去掉三个词即可），语义由画面自明。

### 镜 5｜「正在打开」细线圆角框（i2v，图形通道）

首帧由 `build_vectors.py` 生成：暖粉/奶油双色面板 + 细线圆角卡片，框内文字「正在打开 · 我的模拟长生路 · 第 1781 章」（文字精确），右侧纸面铺微缩章节名 token 网格——复刻 Claude 思维气泡 + token 流语法。

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded card: the thin outlined rounded rectangle, its Chinese text and the tiny text grid on the right panel stay exactly as in the image, no redrawing or warping of any glyphs. Motion: the three typing dots below the card pulse in sequence; the tiny grid lines on the right drift upward very slowly like a rising token stream; a subtle warm light shift crosses the panel. Camera completely still.
overall_soundscape: Faint paper flutter and a soft tick like quiet typing.
non_diegetic_music: N/A
```

### 镜 6｜风吹书页花瓣起飞（收束）

```text
integrated_multimodal_description:
[Shot 1] Vintage storybook oil painting, muted antique tones, aged paper texture. The open book on the desk catches a gust: pages flutter in a wave, several coral petals lift off the pages and drift upward through soft painted light. Camera: slow pull-back revealing the desk, the window and warm light filling the room. Muted warm palette with coral pink accents, painterly texture.
overall_soundscape: Rushing flutter of pages, light breeze swelling, petals whispering in the air.
non_diegetic_music: Piano and soft strings swell gently, resolving to a single sustained warm chord.
```

### 镜 4a–4c｜真实 UI 展示（i2v，文字由首帧保真）

调用方式：`mode=i2v`，`image` 传截图 URL（本地路径上传），**不传 aspect_ratio**（跟随首帧）。首帧图承担全部信息，提示词只写动效 + 保护声明。`duration=4`。《Ethereal》音频文件可作为音频参考一并传入（见 4.5 卡点），让 UI 动效踩拍。

**镜 4a｜书库 → 导入本地书**（首帧 `brand/ui/书库.png`）：

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded screenshot: every Chinese glyph, icon, layout line and color must stay exactly as in the image, no redrawing, no distortion, no new elements. Motion is minimal: a very slow gentle zoom-in toward the center; a soft cursor pointer fades in, moves to the orange button and clicks it, the button shows a brief pressed state. Flat, calm, nothing else moves.
overall_soundscape: A single soft UI click, very quiet room tone.
non_diegetic_music: N/A
```

**镜 4b｜书籍详情 → 开始阅读**（首帧 `brand/ui/书籍详情.png`）：

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded screenshot: all text, cover thumbnail, buttons and layout stay exactly as in the image, no redrawing or warping of any glyphs. Motion: slow subtle zoom toward the button row; a soft cursor glides to the red-orange button and clicks; the page gives a gentle upward nudge as if starting to scroll, then settles. Flat and calm.
overall_soundscape: Soft click and a faint page-swipe.
non_diegetic_music: N/A
```

**镜 4c｜阅读器翻页**（首帧 `brand/ui/阅读器.png`）：

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded screenshot: chapter title, body text glyphs, margins and toolbar stay exactly as in the image, no regenerating or melting of characters. Motion: the page content scrolls up smoothly once, like turning to the next section, then eases to a stop; a very slight zoom-out at the end. Nothing else changes.
overall_soundscape: A soft paper-like swipe, quiet room tone.
non_diegetic_music: N/A
```

### 镜 7/8｜字卡（i2v，文字由首帧保真）

首帧由 `build_vectors.py` 生成两张 2K PNG（SVG 描字保证字形 100% 正确），再交 H3 做微动——「文字让 AI 加上去」的安全实现。

**镜 7｜「Chloris」红陶字卡**（复刻 Fable 5 字卡：红陶底 #C4674A 附近 + 细网格纹理 + 白色衬线大字 + 蝴蝶标本散布）：

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded title card: the terracotta background with its faint grid, the white serif wordmark "Chloris" and the scattered butterfly illustrations must remain pixel-sharp and unchanged for the whole clip, no morphing, no rewriting. Motion only: two butterflies flutter gently in place and one slowly lands near the wordmark; a very soft warm light sweep crosses the card once. Camera completely still.
overall_soundscape: Very quiet room tone, a faint wing flutter.
non_diegetic_music: N/A
```

**镜 8｜Slogan 卡**（首帧：奶油底 + 细网格 + 图标 + 「让阅读，自然生长。」）：

```text
integrated_multimodal_description:
[Shot 1] Strictly preserve the uploaded card: the book-and-flowers icon and the Chinese line "让阅读，自然生长。" must stay exactly as in the image, every glyph unchanged and sharp. Motion: soft golden light panels slowly brighten behind the card, one tiny petal drifts past the lower corner; final second settles into complete stillness as an ending frame.
overall_soundscape: Quiet room tone, a single faint page-settle sound at the end.
non_diegetic_music: N/A
```
> roll 不理想时的排查顺序：运镜是否唯一 → 色彩词是否被场景词稀释 → 是否写了保护声明。每次只改一处并固定 seed。
>
> **关于 `non_diegetic_music`**：以下提示词中的配乐描述仅用于草稿阶段的氛围预览。成片 BGM 已定为 Txmy《Ethereal》，终稿渲染时请把各镜 `non_diegetic_music` 改为 `N/A`，只保留环境音，由后期统一铺《Ethereal》。

---

## 六、后期拼接方案（ffmpeg 直拼，由 AI 助手执行，无 Pr）

**工作目录**：`trail/`（BGM 已就位：`trail/1600877923-1-192.mp4`，AI 生成的无版权高仿版《Ethereal》，MP3 版已提取：`trail/bgm-ethereal-ai.mp3`（167s，即传即用），26s 成片从中截取一段）。建议子目录：`trail/raw/`（H3 原始素材）、`trail/out/`（成片）。ffmpeg 已就绪（系统 Homebrew 版 8.1.2，含 ffprobe，路径 `/opt/homebrew/bin/`）。

流水线五步，全部命令行可复现：

1. **超分**：H3 素材 768P → 1080P，Real-ESRGAN（realesr-animevideov3 模型，见 4.6）；每段先 `ffmpeg -i` 核查时长与帧率（24fps）；
2. **拼接**：四段 concat（链 A → 链 B → UI① → 结尾卡），`ffmpeg concat demuxer` 无损串联；切点对齐曲子重拍（用 ffmpeg `astats`/`silencedetect` 或 Python onset 检测找重拍时刻，微调各段 `trim` 点）；
3. **混音**：《Ethereal》高仿曲作主音轨（截前奏至主歌段），H3 各镜原生音轨 `volume=-12dB` 作环境音垫底，`amix` 合成；结尾卡处 BGM `afade` 收在钢琴音上；
4. **调色/字卡**：主链连续画面不调色；段落间明度落差用 `eq=brightness/saturation` 轻推；字卡文字全部来自 AI 生成（首帧保真），不在命令行里造字；
5. **导出**：主版 `libx264 -crf 16 -preset slow` 1080P；方形版 `scale=1080:1080:force_original_aspect_ratio=decrease, pad=1080:1080:(ow-iw)/2:(oh-ih)/2:color=0xF6EFE3` 补奶油底；另出 720p 预览。

**剪辑节奏（30s 一条出）**：0–10 链 A（结尾花瓣糊满）→ 10–14 UI① 书库（光斑聚焦）→ 14–22 链 B（光晕浮出剪影 → 光斑收拢）→ 22–26 UI② 详情 → 26–29 UI③ 阅读器 → 29–30 结尾卡定格；六段全部靠「花瓣糊 / 光斑」语言无缝相接，切点全落 BGM 重拍。

**字卡（文字全部 AI 生成）**：两张字卡都走「首帧保真法」——`build_vectors.py` 出 2K 首帧 PNG：①红陶卡（terracotta + 细网格 + 白衬线「Chloris」+ 定位行「跨平台阅读器 · 兼容 Legado 书源」+ 蝴蝶）；②slogan 卡（奶油底 + 图标 +「让阅读，自然生长。」）；H3 i2v 只加动效。字形崩了就重 roll 或改空白标签，不用剪辑端补救。

**声音与卡点**：BGM 用本地高仿曲 MP3（`trail/bgm-ethereal-ai.mp3`），**同一文件两用**——生成端喂 H3 音频参考让画面踩拍（4.5），后期端铺底并按重拍选切点；H3 原生音轨压 -12dB 只留环境音。Txmy《Ethereal》原曲不再依赖授权，若未来想要原版再向 OpenWorld Recordings 谈 sync。

---

## 七、排期与预算

### 排期（按业余时间，约 5 个工作日）

| 天 | 任务 |
| --- | --- |
| D1 | ~~开通 platform.minimax.cn~~ ✅ 已跑通（api.minimax.cn 端点已验证）；装 Real-ESRGAN（ffmpeg 已就绪）；BGM MP3 ✅ 已提取 |
| D2 | 链 A（10s）草稿迭代（≤3 roll）；链 B（8s r2v）与 UI①②③、结尾卡 i2v（各 1–2 roll） |
| D3 | 全部定稿 → Real-ESRGAN 超分 1080P（零成本） |
| D4 | ffmpeg 拼接（一条主链 + 三处直切）+ BGM 混音、按重拍选切点 |
| D5 | 双版本导出（16:9 / 1:1）、内测反馈微调 |

### 预算估算（极限压缩版：768P 直出 + 本地超分，不走 2K 再生成）

| 项 | 计算 | 金额 |
| --- | --- | --- |
| 链 A（10s t2v） | 10s × 3 roll 上限 × ¥0.50 | ≈ ¥15 |
| 链 B（8s r2v） | 8s × 3 roll 上限 × ¥0.50 | ≈ ¥12 |
| UI①②③（4s × 3 i2v） | 12s × 2 roll × ¥0.50 | ≈ ¥12 |
| 结尾卡（4s i2v） | 4s × 2 roll × ¥0.50 | ≈ ¥4 |
| 超分 / 拼接混音 | Real-ESRGAN + ffmpeg 本地，由 AI 助手执行 | ¥0 |
| **合计** | 顺利 ≈ **¥21–25**；上限 ≈ **¥43** | |

对比最初分镜方案（¥60–110）砍掉约七成，且后期零软件成本。压缩阀门：① 链 B 反复失败拆两段各 4s（¥8 上限）；② BGM 已用本地无版权高仿曲，无授权费用。

### 风险与对策

- **字形错误（文字由 AI 加的核心风险）**：已用「首帧保真法」把风险压到最低——文字正确性由首帧 PNG/真实截图保证，AI 只做动效；提示词首行写保护声明；某镜 roll 完仍崩字 → 重 roll 或改空白标签；
- **768P 文字边缘偏软**：超分对油画色块友好、对小字一般——多 roll 挑字形最锐的一版；「正在打开」等更精细的图形镜留二期再上；
- **链 B 崩坏**：独立生成、崩了只重 roll 链 B；连续 3 roll 不出则改用 r2v 丢链 A 成品 + 官方参考图双保险，成片结构不变；
- **镜 2 花生长（链 A 内节拍）易翻车**：包含在链 A 的 3 roll 上限里；链 A 反复失败时把双节拍拆成两条 8s+8s 分别生成再拼，牺牲连贯性保交付；
- **价格/参数以官方控制台为准**：视频价格与再生成价格已在 2026-09-12 按 `platform.minimax.cn`「Token 计划 · API 企业」页刊例核实（¥0.80/¥0.50/¥0.30 每秒）；请求字段名以控制台「接口说明」页为准；
- **版权**：成片为 Chloris 开源项目宣传。BGM 使用 AI 生成的无版权高仿曲（`trail/bgm-ethereal-ai.mp3`，已提取），无授权依赖；发布时在简介中按来源标注即可。H3 生成内容的商用需符合 MiniMax 服务条款。
