/// Shared error and asynchronous task contracts for the application boundary.
///
/// The engine does not know about Flutter or a particular state-management
/// library.  These small value types let adapters report the stage and
/// recoverability of a failure without leaking transport exceptions into UI.
enum DomainErrorStage {
  request,
  search,
  detail,
  toc,
  content,
  render,
  persist,
  unknown,
}

class DomainError implements Exception {
  const DomainError({
    required this.code,
    required this.stage,
    required this.message,
    this.cause,
    this.sourceId,
    this.bookId,
    this.chapterId,
    this.recoverable = true,
    this.retryable = false,
    this.suggestedAction,
  });

  final String code;
  final DomainErrorStage stage;
  final String message;
  final Object? cause;
  final String? sourceId;
  final String? bookId;
  final String? chapterId;
  final bool recoverable;
  final bool retryable;
  final String? suggestedAction;

  factory DomainError.from(
    Object error, {
    DomainErrorStage stage = DomainErrorStage.unknown,
    String? sourceId,
    String? bookId,
    String? chapterId,
  }) {
    if (error is DomainError) {
      // Keep the most specific error code/message while filling in identity
      // information that is only known at the application boundary. This is
      // especially important for content_empty: a page may be empty for one
      // chapter but perfectly valid for the next one.
      if ((error.sourceId == null || error.sourceId!.isEmpty) &&
              (sourceId != null && sourceId.isNotEmpty) ||
          (error.bookId == null || error.bookId!.isEmpty) &&
              (bookId != null && bookId.isNotEmpty) ||
          (error.chapterId == null || error.chapterId!.isEmpty) &&
              (chapterId != null && chapterId.isNotEmpty) ||
          (stage != DomainErrorStage.unknown &&
              error.stage == DomainErrorStage.unknown)) {
        return error.copyWith(
          stage: stage == DomainErrorStage.unknown ? error.stage : stage,
          sourceId: error.sourceId ?? sourceId,
          bookId: error.bookId ?? bookId,
          chapterId: error.chapterId ?? chapterId,
        );
      }
      return error;
    }
    final text = error.toString();
    final lower = text.toLowerCase();
    final timeout = lower.contains('timeout');
    final cancelled = lower.contains('cancel') || lower.contains('aborted');
    final network =
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('failed host lookup') ||
        lower.contains('clientexception');
    final empty =
        lower.contains('内容为空') ||
        lower.contains('content empty') ||
        lower.contains('empty content') ||
        lower.contains('章节为空');
    final auth =
        lower.contains('登录') ||
        lower.contains('login') ||
        lower.contains('captcha') ||
        lower.contains('验证码') ||
        lower.contains('cloudflare');
    final parse =
        lower.contains('parse') ||
        lower.contains('解析') ||
        lower.contains('invalid') ||
        lower.contains('格式');
    final code = cancelled
        ? 'cancelled'
        : empty
        ? 'content_empty'
        : auth
        ? 'auth_required'
        : timeout
        ? 'request_timeout'
        : network
        ? 'network_error'
        : parse
        ? 'parse_error'
        : 'operation_failed';
    return DomainError(
      code: code,
      stage: stage,
      message: text.split('\n').first,
      cause: error,
      sourceId: sourceId,
      bookId: bookId,
      chapterId: chapterId,
      recoverable: !cancelled,
      retryable: !cancelled && (timeout || network || empty),
      suggestedAction: cancelled
          ? '任务已取消'
          : auth
          ? '请完成登录或更换书源'
          : empty
          ? '请检查正文规则、登录状态或更换书源'
          : timeout || network
          ? '请检查网络后重试或更换书源'
          : parse
          ? '请检查规则和响应格式'
          : null,
    );
  }

  /// Rebind an error to a request identity without changing its category.
  /// Subclasses may override when they need to retain a richer type.
  DomainError copyWith({
    String? code,
    DomainErrorStage? stage,
    String? message,
    Object? cause,
    String? sourceId,
    String? bookId,
    String? chapterId,
    bool? recoverable,
    bool? retryable,
    String? suggestedAction,
  }) => DomainError(
    code: code ?? this.code,
    stage: stage ?? this.stage,
    message: message ?? this.message,
    cause: cause ?? this.cause,
    sourceId: sourceId ?? this.sourceId,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    recoverable: recoverable ?? this.recoverable,
    retryable: retryable ?? this.retryable,
    suggestedAction: suggestedAction ?? this.suggestedAction,
  );

  @override
  String toString() => '$code: $message';
}

sealed class TaskState<T> {
  const TaskState();

  bool get isTerminal =>
      this is TaskCompleted<T> ||
      this is TaskPartial<T> ||
      this is TaskFailed<T> ||
      this is TaskCancelled<T>;
}

final class TaskIdle<T> extends TaskState<T> {
  const TaskIdle();
}

final class TaskQueued<T> extends TaskState<T> {
  const TaskQueued();
}

final class TaskRunning<T> extends TaskState<T> {
  const TaskRunning({this.progress = 0, this.value});

  final double progress;
  final T? value;
}

final class TaskPaused<T> extends TaskState<T> {
  const TaskPaused({this.progress = 0, this.value});

  final double progress;
  final T? value;
}

final class TaskCancelling<T> extends TaskState<T> {
  const TaskCancelling({this.progress = 0, this.value});

  final double progress;
  final T? value;
}

final class TaskPartial<T> extends TaskState<T> {
  const TaskPartial({required this.value, this.errors = const []});

  final T value;
  final List<DomainError> errors;
}

final class TaskCompleted<T> extends TaskState<T> {
  const TaskCompleted(this.value);

  final T value;
}

final class TaskFailed<T> extends TaskState<T> {
  const TaskFailed(this.error, {this.value});

  final DomainError error;
  final T? value;
}

final class TaskCancelled<T> extends TaskState<T> {
  const TaskCancelled({this.value});

  final T? value;
}
