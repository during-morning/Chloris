# 真机书源闭环验证

- 生成时间：2026-09-12T06:18:23.686609Z
- 关键词：`萌娘三国演义`，尝试 322 个书源
- 分组：不含 JS 规则 113 个 / 含 JS 规则 209 个。引擎包内没有 JS 虚拟机，含 JS 的源以 `NoJsRuntime` 跑，单独统计不入通过率。

## 各阶段通过数

| 阶段 | 不含 JS (n=113) | 含 JS (n=209) |
|---|---:|---:|
| search | 22 | 19 |
| detail | 18 | 15 |
| toc | 10 | 13 |
| content | 2 | 7 |
| nextChapter | 2 | 6 |
| changeSource | 0 | 1 |

**完整闭环（搜索→详情→目录→正文→换章）**：不含 JS 2 / 113；含 JS 6 / 209

**只看网络可达的源**（排除 `env` 类：出口代理拦断 / TLS 证书校验失败 / 超时）：不含 JS 闭环 2 / 108。这一列才是引擎相关的分母 —— 沙箱的出口白名单挡住了大部分中文书站，把它们算进去会把结论带偏。

**换源**：不含 JS 0 个源成功改由他源取到正文。

## 未闭环的归因（不含 JS 的源）

| 归因 | 数量 | 含义 |
|---|---:|---|
| env | 5 | 出口代理/TLS/超时等网络层失败，与引擎无关 |
| js | 13 | 规则需要真 JS 虚拟机，本 CLI 环境没有（源本身可达） |
| source | 93 | 站点返回垃圾页或规则已失效；未跑 Legado 对照前无法与引擎缺口区分 |
| engine | 0 | **需要查的**：引擎内部错误或规则求值异常 |

### 站点层失败（可能是书源失效）

| 书源 | 节点 | 断在哪一步 | 原因 |
|---|---|---|---|
| 五二书库 | shukuw.cc | content | ContentEmpty: 阅读记录 (https://www.52shukuw.cc/bookcase.html?#) |
| 五二书库 | po5.net | search | Bad state: 搜索返回空列表 |
| 万象书城 | wxscs.com%e7%bb%86%e9%9b%a8%e5%b0%98%e5%af%b0 | content | ContentEmpty: 万相书城 (https://www.wxscs.com/?#) |
| 殓师灵异（优） | rulianshi.org | content | ContentEmpty: 第035章 刘备南漳遇隐士 单福新野投明主 (http://www.rulianshi.org/sanguoyanyibaihuaban/51118160.html?#) |
| 去读书啊 | qudushu.org | content | ContentEmpty: 全本 (http://www.qudushu.la/fulltop/allvisit/1.html?#) |
| 新笔趣阁 | xbiquge.la | search | Bad state: 搜索返回空列表 |
| 新笔趣阁 | m.bbiquge8.net | search | Bad state: 搜索返回空列表 |
| 新笔趣阁 | m.xxbqg5200.com | search | Bad state: 搜索返回空列表 |
| 大帝书阁 | bbqsk.net | search | Bad state: 搜索返回空列表 |
| 八零电子 | balingtxt.com | search | Bad state: 搜索返回空列表 |
| 精华书阁 | m.jhsssd.com | content | ContentEmpty: 求书催更 (https://m.jhsssd.com/qiushu.html?#) |
| 精华书阁 | jhssd.com | content | ContentEmpty: 求书催更 (https://jhssd.com/qiushu.html?#) |
| 精华书阁 | richvv.com | search | Bad state: 搜索返回空列表 |
| 精华书阁 | m.richvv.com | search | Bad state: 搜索返回空列表 |
| 快眼看书 | m.xbotaodz.com | search | Bad state: 搜索返回空列表 |
| 万象书城 | wxscs.com | content | ContentEmpty: 玄幻·奇幻 (https://wxscs.com/nav/xuanhuan.html?#) |
| 咋填小说 | m.rulianshi.la | search | Bad state: 搜索返回空列表 |
| 新笔趣阁 | m.xinbqg.com | search | Bad state: 搜索返回空列表 |
| 快眼看书 | botaodz.com | search | Bad state: 搜索返回空列表 |
| 快眼看书（优+） | xbotaodz.com | search | Bad state: 搜索返回空列表 |
| 穿越小说 | kk.org | search | Bad state: 搜索返回空列表 |
| 穿越小说 | kk169.org | search | Bad state: 搜索返回空列表 |
| 穿越小说 | m.kk169.net | search | Bad state: 搜索返回空列表 |
| 穿越小说 | kk169.net | search | Bad state: 搜索返回空列表 |
| 思路客子 | siluke.cc | search | Bad state: 搜索返回空列表 |
| 种田小说 | m.zhongtianwen.cn | content | ContentEmpty: 阅读记录 (https://m.zhongtianwen.cn/user/history/index.html?#) |
| 话本小说 | ihuaben.com | search | Bad state: 搜索返回空列表 |
| 商店小说（优） | 16kbook.net | search | Bad state: 搜索返回空列表 |
| 夜天连看（优） | yetianlian.com | search | Bad state: 搜索返回空列表 |
| 夜天连看 | yetianlian.cc | search | Bad state: 搜索返回空列表 |
| 何以笙箫默小说电脑 | yetianlian.net | search | Bad state: 搜索返回空列表 |
| 奇书网页 | xqishuta.net | search | Bad state: 搜索返回空列表 |
| 三千小说 | xs3000.com | search | Bad state: 搜索返回空列表 |
| 啃书阁 | kenshuwx.com | search | Bad state: 搜索返回空列表 |
| 奇书网吧 | uidzhx.com | toc | Bad state: 目录为空 |
| 🎉 啃书小说 | kenshuzw.com | toc | Bad state: 目录为空 |
| ️顶点中文 | wap.ddsk.org | toc | Bad state: 目录为空 |
| 全本小说 | apap.net | toc | Bad state: 目录为空 |
| 全本小说 | iqb8.org | toc | Bad state: 目录为空 |
| 全本小说 | m.iquanben.net | toc | Bad state: 目录为空 |

### 缺 JS 虚拟机（源本身可达，需要真机运行时）

| 书源 | 节点 | 断在哪一步 | 原因 |
|---|---|---|---|
| 就爱读小说网 | m.dxs.org | detail | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 新笔趣阁 | qidianxin.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 必看悦读 | api.97yd.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 九七阅读 | 97yd.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 落霞小说 | luoxia.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 下书网吧 | txtdown.cc | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 全本小说 | esstr.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 全本小说 | qbxsw.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 小说网 | xiaoshuo.net | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 华丽家族BL文学 | hljzc.cc | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 无限小说 | txt97.cc | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 阿皮小说 | pixiaoshuo.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 猫九小说 | maojiuxs.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |

### 环境层失败（代理/TLS/超时）

| 书源 | 节点 | 断在哪一步 | 原因 |
|---|---|---|---|
| 奇书网吧 | iqishu.la | search | ClientException: Connection closed before full header was received, uri=http://www.iqishu.la/search.html?searchkey=%E8%9… |
| 全本小说 | xs5200.com | search | ClientException: Connection closed before full header was received, uri=http://www.xs5200.com/modules/article/search.php… |
| QQ文学 | m.qqwx.win | detail | TimeoutException after 0:00:18.000000: Future not completed |
| 无限小说 | wuxianxs.cc | detail | TimeoutException after 0:00:18.000000: Future not completed |
| 绿茶小说 | 92popo.cc | detail | TimeoutException after 0:00:18.000000: Future not completed |

### 已闭环的源

| 书源 | 选用书 | 首章字数 | 换源 |
|---|---|---:|---|
| 潇湘书院 | 萌娘三国演义 | 16965 | — |
| 久久下载（下载） | 全本 | 50 | — |

