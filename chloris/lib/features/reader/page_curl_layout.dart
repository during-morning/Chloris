/// 仿真翻页的卷页几何（纯 Dart，不依赖 Flutter，便于脱离 UI 单测）。
///
/// 采用「可见区 + 折叠背页 + 软阴影」的层叠模型：
/// - 前翻（去下一页）：当前页从右缘卷起，可见区从左向右收缩，
///   折缝左侧是卷起部分的「纸背」，折缝右侧透出下一页并投软阴影；
/// - 后翻（回上一页）：上一页从左缘展开铺回，展开区右侧是
///   尚未放平的「纸背」，再往右是当前页与阴影。
///
/// 说明：这是风格化的卷页（fold+shadow），不是逐像素采样的物理卷曲。
/// 物理卷曲需要把页面栅格化后按曲线重排，属于后续升级项。
library;

class CurlGeometry {
  const CurlGeometry({
    required this.visibleLeft,
    required this.visibleWidth,
    required this.flapLeft,
    required this.flapWidth,
    required this.shadowLeft,
    required this.shadowWidth,
  });

  /// 起翻页（前翻=当前页，后翻=上一页）仍平铺可见的区域。
  final double visibleLeft;
  final double visibleWidth;

  /// 折缝左侧的纸背条（卷起但未放平的部分背面）。
  final double flapLeft;
  final double flapWidth;

  /// 投在下层页面上的软阴影区。
  final double shadowLeft;
  final double shadowWidth;

  bool get hasVisible => visibleWidth > 0.5;
  bool get hasFlap => flapWidth > 0.5;
  bool get hasShadow => shadowWidth > 0.5;
}

/// 纸背最大占空比：折叠部分在视觉上被压缩，只占已卷起宽度的一部分。
const double kCurlFlapRatio = 0.45;

/// 软阴影最大宽度（像素）。
const double kCurlShadowWidth = 56.0;

/// 前翻：p ∈ [0,1]，0=未动，1=当前页完全卷起。
CurlGeometry curlForward(double p, double w) {
  p = p.clamp(0.0, 1.0);
  final visibleWidth = w * (1 - p);
  final fold = visibleWidth;
  final flapWidth = (w * p * kCurlFlapRatio).clamp(0.0, w - fold);
  final shadowWidth = p > 0 ? kCurlShadowWidth.clamp(0.0, w - fold - flapWidth) : 0.0;
  return CurlGeometry(
    visibleLeft: 0,
    visibleWidth: visibleWidth,
    flapLeft: fold,
    flapWidth: flapWidth,
    shadowLeft: fold + flapWidth,
    shadowWidth: shadowWidth,
  );
}

/// 后翻：q ∈ [0,1]，0=未动，1=上一页完全铺平。
CurlGeometry curlBackward(double q, double w) {
  q = q.clamp(0.0, 1.0);
  final visibleWidth = w * q;
  final fold = visibleWidth;
  // 纸背随展开进度先增后减：q=0 不可见，q→1 时折叠部分收合为 0。
  final flapWidth = (w * q * kCurlFlapRatio).clamp(0.0, w - fold);
  final shadowWidth = q > 0 && q < 1
      ? kCurlShadowWidth.clamp(0.0, w - fold - flapWidth)
      : 0.0;
  return CurlGeometry(
    visibleLeft: 0,
    visibleWidth: visibleWidth,
    flapLeft: fold,
    flapWidth: flapWidth,
    shadowLeft: fold + flapWidth,
    shadowWidth: shadowWidth,
  );
}
