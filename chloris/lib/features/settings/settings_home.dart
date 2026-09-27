part of 'settings_screen.dart';

class _SettingsHome extends ConsumerWidget {
  const _SettingsHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.paper,
      body: MeowPage(
        eyebrow: '我的',
        title: '我的',
        fullBleedBody: true,
        child: ListView(
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.tune),
              title: const Text('书源管理'),
              subtitle: const Text('导入、启用、分组'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SourcesScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.rss),
              title: const Text('RSS 订阅'),
              subtitle: const Text('订阅源与文章'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RssScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.list),
              title: const Text('替换净化 / 目录规则 / 字典'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RulesScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.library),
              title: const Text('阅读设置'),
              onTap: () => showReadingSettingsSheet(context),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.notification),
              title: const Text('测试通知'),
              onTap: () => const NotificationService().showTest(),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.palette),
              title: const Text('外观'),
              subtitle: Text(
                [
                  if (ref.watch(uiStyleProvider).fixedThemeMode != null)
                    ref.watch(uiStyleProvider).fixedThemeMode == ThemeMode.dark
                        ? '固定深色'
                        : '固定浅色'
                  else ...[
                    SettingsScreen._themeLabel(ref.watch(themeModeProvider)),
                  ],
                  if (ref.watch(uiStyleProvider) == AppUiStyle.classic &&
                      ref.watch(einkThemeProvider))
                    '扁平墨水'
                  else if (ref.watch(uiStyleProvider) == AppUiStyle.classic)
                    AppThemeFamily.byId(ref.watch(themeFamilyIdProvider)).label,
                  ref.watch(uiStyleProvider).label,
                  '阅读器同步',
                ].join(' · '),
              ),
              onTap: () => const SettingsScreen()._pickTheme(context, ref),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.flash),
              title: const Text('新手引导'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.list),
              title: const Text('规则管理'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RulesScreen()),
              ),
            ),
            SwitchListTile(
              secondary: const AppIcon(AppIcons.bold),
              title: const Text('粗体文字'),
              value: ref.watch(boldTextProvider),
              onChanged: (v) {
                ref.read(boldTextProvider.notifier).state = v;
                ref.read(settingsWriteUseCaseProvider).setBool('boldText', v);
              },
            ),
            SwitchListTile(
              secondary: const AppIcon(AppIcons.contrast),
              title: const Text('高对比度'),
              subtitle: const Text('提高文字、描边与阅读纸的对比，不只改系统标志'),
              value: ref.watch(highContrastProvider),
              onChanged: (v) {
                ref.read(highContrastProvider.notifier).state = v;
                ref
                    .read(settingsWriteUseCaseProvider)
                    .setBool('highContrast', v);
              },
            ),
            ListTile(
              leading: const AppIcon(AppIcons.restart),
              title: const Text('重置网络相关设置'),
              subtitle: const Text('超时 / 并发 / UA / 详细日志 恢复默认'),
              onTap: () {
                ref.read(httpTimeoutSecProvider.notifier).state = 30;
                ref.read(searchTimeoutSecProvider.notifier).state = 30;
                ref.read(searchPoolProvider.notifier).state = 32;
                ref.read(downloadPoolProvider.notifier).state = 8;
                ref.read(debugVerboseProvider.notifier).state = true;
                ref.read(userAgentProvider.notifier).state = '';
                EngineLimits.apply(
                  httpTimeoutSec: 30,
                  searchTimeoutSec: 30,
                  tocTimeoutSec: 30,
                  contentTimeoutSec: 30,
                  searchPool: 32,
                  searchEarlyStopHits: 8,
                  downloadPool: 8,
                  debugVerbose: true,
                  userAgent: '',
                );
                ref.read(settingsWriteUseCaseProvider).resetNetworkDefaults();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已重置网络相关设置')));
              },
            ),
            const _UserAgentTile(),
            ListTile(
              leading: const AppIcon(AppIcons.download),
              title: const Text('下载并发'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.watch(downloadPoolProvider).toString() + ' 路'),
                  Slider(
                    value: ref
                        .watch(downloadPoolProvider)
                        .toDouble()
                        .clamp(2, 16),
                    min: 2,
                    max: 16,
                    divisions: 14,
                    onChanged: (v) {
                      final n = v.round();
                      ref.read(downloadPoolProvider.notifier).state = n;
                      EngineLimits.apply(downloadPool: n);
                      ref
                          .read(settingsWriteUseCaseProvider)
                          .setInt('downloadPool', n);
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.swap),
              title: const Text('搜索并发'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${ref.watch(searchPoolProvider)} 路 · 全源都会搜完，快源优先出结果'),
                  Slider(
                    value: ref
                        .watch(searchPoolProvider)
                        .toDouble()
                        .clamp(8, 64),
                    min: 8,
                    max: 64,
                    divisions: 56,
                    onChanged: (v) {
                      final n = v.round();
                      ref.read(searchPoolProvider.notifier).state = n;
                      EngineLimits.apply(searchPool: n);
                      ref
                          .read(settingsWriteUseCaseProvider)
                          .setInt('searchPool', n);
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.timer),
              title: const Text('HTTP 超时'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.watch(httpTimeoutSecProvider).toString() + ' 秒'),
                  Slider(
                    value: ref
                        .watch(httpTimeoutSecProvider)
                        .toDouble()
                        .clamp(6, 60),
                    min: 6,
                    max: 60,
                    divisions: 54,
                    onChanged: (v) {
                      final n = v.round();
                      ref.read(httpTimeoutSecProvider.notifier).state = n;
                      EngineLimits.apply(httpTimeoutSec: n);
                      ref
                          .read(settingsWriteUseCaseProvider)
                          .setInt('httpTimeoutSec', n);
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.search),
              title: const Text('单源搜索超时'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.watch(searchTimeoutSecProvider).toString() + ' 秒'),
                  Slider(
                    value: ref
                        .watch(searchTimeoutSecProvider)
                        .toDouble()
                        .clamp(15, 60),
                    min: 15,
                    max: 60,
                    divisions: 45,
                    onChanged: (v) {
                      final n = v.round();
                      ref.read(searchTimeoutSecProvider.notifier).state = n;
                      EngineLimits.apply(searchTimeoutSec: n);
                      ref
                          .read(settingsWriteUseCaseProvider)
                          .setInt('searchTimeoutSec', n);
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const AppIcon(AppIcons.bug),
              title: const Text('详细调试日志'),
              subtitle: const Text('记录 HTTP 成功等 info 级日志'),
              value: ref.watch(debugVerboseProvider),
              onChanged: (v) {
                ref.read(debugVerboseProvider.notifier).state = v;
                EngineLimits.apply(debugVerbose: v);
                ref
                    .read(settingsWriteUseCaseProvider)
                    .setBool('debugVerbose', v);
              },
            ),
            SwitchListTile(
              secondary: const AppIcon(AppIcons.remove),
              title: const Text('减少动画'),
              subtitle: const Text('关闭主题过渡；系统减少动态效果也会生效'),
              value: ref.watch(reduceMotionProvider),
              onChanged: (v) {
                ref.read(reduceMotionProvider.notifier).state = v;
                ref
                    .read(settingsWriteUseCaseProvider)
                    .setBool('reduceMotion', v);
              },
            ),
            ListTile(
              leading: const AppIcon(AppIcons.tune),
              title: const Text('界面文字大小'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (ref.watch(uiTextScaleProvider) * 100).round().toString() +
                        '%',
                  ),
                  Slider(
                    value: ref.watch(uiTextScaleProvider).clamp(0.85, 1.4),
                    min: 0.85,
                    max: 1.4,
                    divisions: 11,
                    onChanged: (v) {
                      ref.read(uiTextScaleProvider.notifier).state = v;
                      ref
                          .read(settingsWriteUseCaseProvider)
                          .setDouble('uiTextScale', v);
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.translate),
              title: const Text('语言'),
              subtitle: Text(
                ref.watch(localeProvider) == 'en' ? 'English' : '中文',
              ),
              onTap: () => const SettingsScreen()._pickLang(context, ref),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.lock),
              title: const Text('Cookie 管理'),
              subtitle: const Text('查看 / 复制 / 删除已保存 Cookie'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CookieManageScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.web),
              title: const Text('Web 服务'),
              subtitle: const Text('接口 / 导出'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebServiceScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.bookmark),
              title: const Text('全部书签'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AllBookmarksScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.archive),
              title: const Text('备份与同步'),
              subtitle: const Text('WebDAV / 本地 zip'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.web),
              title: const Text('WebDAV'),
              subtitle: const Text('列出 / 上传备份 / 下载恢复'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WebDavScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.download),
              title: const Text('缓存管理'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CacheManageScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.history),
              title: const Text('阅读记录'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReadRecordScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.folder),
              title: const Text('文件管理'),
              subtitle: const Text('本地 TXT / EPUB'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FileManageScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.bug),
              title: const Text('日志'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugLogScreen()),
              ),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.info),
              title: const Text('关于'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
