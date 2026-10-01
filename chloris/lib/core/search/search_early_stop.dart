/// 搜索早停（early stop）判定——纯函数，不依赖 flutter / engine。
///
/// 设计背景：合并视图命中数达到阈值时，发起中的请求不取消（自然归并），
/// 但不再向尚未开始的源发起新请求。这样能在「命中足够多」时省去对剩余
/// 书源的扫描；普通搜索默认关闭早停，显式调用方才启用该策略。
///
/// 阈值 [earlyStopHits] 来自 [EngineLimits.searchEarlyStopHits]。该值为
/// `<= 0` 时视为关闭早停（兼容历史设置中把阈值调到 0 的情况）。
bool searchShouldEarlyStop({
  required int mergedHits,
  required int earlyStopHits,
}) {
  if (earlyStopHits <= 0) return false;
  return mergedHits >= earlyStopHits;
}
