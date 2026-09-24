import 'package:chloris_engine/chloris_engine.dart';
import 'package:test/test.dart';

void main() {
  test('DomainError classifies retryable transport failures', () {
    final error = DomainError.from(
      StateError('TimeoutException: request timed out'),
      stage: DomainErrorStage.content,
      sourceId: 'source-1',
    );
    expect(error.code, 'request_timeout');
    expect(error.stage, DomainErrorStage.content);
    expect(error.retryable, isTrue);
    expect(error.sourceId, 'source-1');
  });

  test('TaskState exposes terminal and partial outcomes', () {
    const running = TaskRunning<int>(progress: .5, value: 2);
    const partial = TaskPartial<int>(value: 3);
    const failed = TaskFailed<int>(
      DomainError(code: 'x', stage: DomainErrorStage.search, message: '失败'),
    );
    expect(running.isTerminal, isFalse);
    expect(partial.isTerminal, isTrue);
    expect(failed.isTerminal, isTrue);
  });

  test('DomainError classifies empty, auth and cancellation failures', () {
    expect(
      DomainError.from(StateError('章节内容为空'), stage: DomainErrorStage.content),
      isA<DomainError>().having((e) => e.code, 'code', 'content_empty'),
    );
    expect(
      DomainError.from(
        StateError('login required'),
        stage: DomainErrorStage.content,
      ).code,
      'auth_required',
    );
    expect(
      DomainError.from(
        StateError('request cancelled'),
        stage: DomainErrorStage.search,
      ).recoverable,
      isFalse,
    );
  });
}
