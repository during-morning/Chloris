# 真机书源闭环验证

- 生成时间：2026-09-12T06:12:52.254252Z
- 关键词：`三国演义`，尝试 756 个书源
- 分组：不含 JS 规则 268 个 / 含 JS 规则 488 个。引擎包内没有 JS 虚拟机，含 JS 的源以 `NoJsRuntime` 跑，单独统计不入通过率。

## 各阶段通过数

| 阶段 | 不含 JS (n=268) | 含 JS (n=488) |
|---|---:|---:|
| search | 16 | 13 |
| detail | 13 | 9 |
| toc | 12 | 9 |
| content | 3 | 3 |
| nextChapter | 2 | 3 |
| changeSource | 0 | 0 |

**完整闭环（搜索→详情→目录→正文→换章）**：不含 JS 2 / 268；含 JS 3 / 488

**只看网络可达的源**（排除 `env` 类：出口代理拦断 / TLS 证书校验失败 / 超时）：不含 JS 闭环 2 / 40。这一列才是引擎相关的分母 —— 沙箱的出口白名单挡住了大部分中文书站，把它们算进去会把结论带偏。

**换源**：不含 JS 0 个源成功改由他源取到正文。

## 未闭环的归因（不含 JS 的源）

| 归因 | 数量 | 含义 |
|---|---:|---|
| env | 228 | 出口代理/TLS/超时等网络层失败，与引擎无关 |
| js | 12 | 规则需要真 JS 虚拟机，本 CLI 环境没有（源本身可达） |
| source | 26 | 站点返回垃圾页或规则已失效；未跑 Legado 对照前无法与引擎缺口区分 |
| engine | 0 | **需要查的**：引擎内部错误或规则求值异常 |

### 站点层失败（可能是书源失效）

| 书源 | 节点 | 断在哪一步 | 原因 |
|---|---|---|---|
| 五二书库 | shukuw.cc | content | ContentEmpty: 阅读记录 (https://www.52shukuw.cc/bookcase.html?#) |
| 万象书城 | wxscs.com%e7%bb%86%e9%9b%a8%e5%b0%98%e5%af%b0 | content | ContentEmpty: 万相书城 (https://www.wxscs.com/?#) |
| 殓师灵异（优） | rulianshi.org | content | ContentEmpty: 194回：诸葛乘雪破羌兵 司马克日擒孟达 (http://www.rulianshi.org/sanguoyanyitongsu/48358846.html?#) |
| 去读书啊 | qudushu.org | search | Bad state: 搜索返回空列表 |
| 新笔趣阁 | xbiquge.la | search | Bad state: 搜索返回空列表 |
| 新笔趣阁 | m.bbiquge8.net | toc | Bad state: 目录为空 |
| 新笔趣阁 | m.xxbqg5200.com | search | Bad state: 搜索返回空列表 |
| 大帝书阁 | bbqsk.net | search | Bad state: 搜索返回空列表 |
| 八零电子 | balingtxt.com | search | Bad state: 搜索返回空列表 |
| 精华书阁 | m.jhsssd.com | content | ContentEmpty: 第1章 三国鼎立＆桃园结义 (https://m.jhsssd.com/131908/56341148.html?#) |
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
| 坤马小说 | 25zw.com | search | Bad state: 搜索返回空列表 |
| 临高启明同人 | lgqm.huijiwiki.com/wiki/%E5%90%8C%E4%BA%BA%E4%BD%9C%E5%93%81%E5%88%97%E8%A1%A8 | search | Bad state: 搜索返回空列表 |

### 缺 JS 虚拟机（源本身可达，需要真机运行时）

| 书源 | 节点 | 断在哪一步 | 原因 |
|---|---|---|---|
| 就爱读小说网 | m.dxs.org | detail | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 新笔趣阁 | qidianxin.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 必看悦读 | api.97yd.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
| 九七阅读 | 97yd.com | search | js_unsupported: 规则 JS 无法求值，且不允许回退为原输入 |
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
| 精华书阁 | babahome.net | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//www.babahome.net:443 |
| 精华书阁 | wap.jhssd.com | content | network_error: ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//m.jhsssd.com:443 |
| 精华书阁 | m.jhssd.com | detail | HandshakeException: Connection terminated during handshake |
| 星星小说 | xxtxt.com | search | TimeoutException after 0:00:15.000000: Future not completed |
| 星星小说 | m.xingxingxsw.com | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//m.xingxingxsw.com:443 |
| 星星小说 | m.zbcxw.cn | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//m.zbcxw.cn:443 |
| 星星小说 | zbcxw.cn | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//www.zbcxw.cn:443 |
| 新笔趣阁 | m.bqg369.com | detail | HandshakeException: Connection terminated during handshake |
| 快眼看书 | ibotaodz.com | search | HandshakeException: Handshake error in client (OS Error:  	CERTIFICATE_VERIFY_FAILED: application verification failure(h… |
| 快眼看书（优+） | booksky.cc | search | ClientException: Connection closed before full header was received, uri=http://www.booksky.cc/modules/article/search.php… |
| 精华书阁 | m.babahome.net | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//m.babahome.net:443 |
| 精华书阁 | m.xbyuan.com | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//m.xbyuan.com:443 |
| 独步小说（优） | dbxsn.com | nextChapter | network_error: ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//dbxsn.com:443 |
| 坤坤书库（魔法） | 52shuku.vip | search | ClientException: Proxy failed to establish tunnel (502 Bad Gateway), uri=//www.52shuku.vip:443 |
| 开心文学网 | kxwx.org | content | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.kxdu.net:443 |
| 种田小说 | m.zhongtianwen.cn | content | ContentEmpty: ↓直达页面底部 (https://m.zhongtianwen.cn/SanGuoYanYiXiaoShuo18224712/zhaojiemulu.html?#) |
| 系统小说 | xitongliu.cn | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//xitongliu.cn:443 |
| 追书神器① | zhuishushenqi.com%e5%81%9c | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.zhuishushenqi.com:443 |
| 落霞小说 | luoxia123.com | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.luoxia123.com:443 |
| 画本阅读 | so.ihuaben.com | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//so.ihuaben.com:443 |
| 话本小说 | ihuaben.com | search | Bad state: HTTP 503 http://so.ihuaben.com/search?keyword=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89&page=1 |
| 话本小说 | so.ihuaben.com/search | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//so.ihuaben.com:443 |
| 话本小说 | ihuaben.com%e2%99%a4yc | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//so.ihuaben.com:443 |
| 话本小说 | ihuaben.comyc | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//so.ihuaben.com:443 |
| 有度轻说（优+） | yodu.org/qingxiaoshuo | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.yodu.org:443 |
| 笔趣阁⑧ | boquge.com | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.boquge.com:443 |
| 商店小说（优） | 16kbook.net | search | Bad state: HTTP 503 http://www.16kbook.net/search.php?q=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89&p=1 |
| 夜天连看（优） | yetianlian.com | search | Bad state: HTTP 503 http://www.yetianlian.com/s.php?ie=gbk&q=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 夜天连看 | yetianlian.cc | search | Bad state: HTTP 503 http://www.yetianlian.cc/s.php?ie=utf-8&q=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 何以笙箫默小说电脑 | yetianlian.net | search | Bad state: HTTP 503 http://www.yetianlian.net/s.php?ie=utf-8&q=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 奇书网页 | xqishuta.net | search | Bad state: HTTP 503 http://www.xqishuta.net/search.html?searchkey=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 奇书网吧 | iqishu.la | search | Bad state: HTTP 503 http://www.iqishu.la/search.html?searchkey=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 全本小说 | xs5200.com | search | Bad state: HTTP 503 http://www.xs5200.com/modules/article/search.php?s=10362325638345863231&q=%E4%B8%89%E5%9B%BD%E6%BC%9… |
| 全本小说 | quanben.so | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.quanben.so:443 |
| 全本小说 | qb520.cc | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.qb520.cc:443 |
| 笔趣阁㉛ | m.boquge.com | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//m.boquge.com:443 |
| 落霞小说 | luoxia.com | search | Bad state: HTTP 503 http://luoxia.com/?s=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89 |
| 落霞小说 | luoxiadushu.com | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//luoxiadushu.com:443 |
| 久久下载（下载） | m.9191net.com | search | Bad state: HTTP 503 http://m.9191net.com/search.html?keywords=%E4%B8%89%E5%9B%BD%E6%BC%94%E4%B9%89&submit= |
| 言情小说吧 | xs.cn | search | ClientException: Proxy failed to establish tunnel (503 Service Unavailable), uri=//www.xs8.cn:443 |

### 已闭环的源

| 书源 | 选用书 | 首章字数 | 换源 |
|---|---|---:|---|
| 五二书库 | 续三国演义 | 1859 | — |
| 潇湘书院 | 萌娘三国演义 | 16996 | — |

