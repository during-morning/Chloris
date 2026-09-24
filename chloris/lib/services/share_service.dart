import 'package:share_plus/share_plus.dart';

/// 分享文本（书源/书籍链接）。
class ShareService {
  const ShareService();

  Future<void> shareText(String text) =>
      SharePlus.instance.share(ShareParams(text: text));
}
