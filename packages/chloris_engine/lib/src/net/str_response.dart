class StrResponse {
  const StrResponse({
    required this.url,
    required this.body,
    this.code = 200,
    this.headers = const {},
    this.error,
    this.callTime = 0,
  });

  final String url;
  final String? body;
  final int code;
  final Map<String, String> headers;
  final Object? error;

  /// 对齐 Legado-E `StrResponse.callTime`（`AnalyzeUrl.kt:513-514,533-535`）。
  ///
  /// 正常情况是本次请求的耗时（毫秒）；源检查（`isTest`）模式下被复用为**负
  /// 错误码**：-1 超过设定时间、-2 超时、-3 未找到域名、-4 连接被拒绝、
  /// -5 Socket 错误、-6 SSL 错误、-7 其它。
  final int callTime;

  bool get isSuccessful => code >= 200 && code < 400;
}
