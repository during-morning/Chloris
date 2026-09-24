import 'dart:async';

import 'package:chloris_engine/chloris_engine.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test(
    'PackageHttpPort surfaces terminal 5xx instead of returning an error page',
    () async {
      final client = _SequenceClient((_) => http.Response('server error', 503));
      final port = PackageHttpPort(client: client);
      await expectLater(
        port.send(const HttpRequestSpec(url: 'https://fixture.invalid/error')),
        throwsA(isA<StateError>()),
      );
      expect(client.calls, 1);
    },
  );

  test('PackageHttpPort retries 5xx and returns a later success', () async {
    final client = _SequenceClient((call) {
      if (call == 0) return http.Response('temporary', 502);
      return http.Response('ok', 200);
    });
    final port = PackageHttpPort(client: client);
    final response = await port.send(
      const HttpRequestSpec(url: 'https://fixture.invalid/retry', retry: 1),
    );
    expect(response.code, 200);
    expect(response.body, 'ok');
    expect(client.calls, 2);
  });

  test('cancel search aborts background HTTP without touching detail', () async {
    final hang = _HangClient();
    final ok = _SequenceClient((_) => http.Response('detail-ok', 200));
    final port = PackageHttpPort(client: ok, backgroundClient: hang);
    final search = runZoned(
      () => port.send(
        const HttpRequestSpec(url: 'https://fixture.invalid/search'),
      ),
      zoneValues: {#chlorisHttpSession: 'search'},
    );
    await hang.started.future;
    port.cancelSession('search');
    await expectLater(search, throwsA(isA<HttpCancelledException>()));

    final detail = await runZoned(
      () => port.send(
        const HttpRequestSpec(url: 'https://fixture.invalid/book'),
      ),
      zoneValues: {#chlorisHttpSession: 'detail:https://fixture.invalid/book'},
    );
    expect(detail.body, 'detail-ok');
    expect(ok.calls, 1);
  });

  test('detail and toc coalesce the same interactive GET', () async {
    final gate = Completer<void>();
    var calls = 0;
    final client = _GateClient(() async {
      calls++;
      await gate.future;
      return http.Response('shared', 200);
    });
    final port = PackageHttpPort(client: client);
    final detail = runZoned(
      () => port.send(const HttpRequestSpec(url: 'https://fixture.invalid/book')),
      zoneValues: {#chlorisHttpSession: 'detail:book'},
    );
    final toc = runZoned(
      () => port.send(const HttpRequestSpec(url: 'https://fixture.invalid/book')),
      zoneValues: {#chlorisHttpSession: 'toc:book'},
    );
    await client.started.future;
    expect(calls, 1);
    gate.complete();
    expect((await detail).body, 'shared');
    expect((await toc).body, 'shared');
    expect(calls, 1);
  });
}

class _HangClient extends http.BaseClient {
  final started = Completer<void>();
  final _done = Completer<http.StreamedResponse>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!started.isCompleted) started.complete();
    return _done.future;
  }

  @override
  void close() {
    if (!_done.isCompleted) {
      _done.completeError(http.ClientException('closed'));
    }
  }
}

class _GateClient extends http.BaseClient {
  _GateClient(this.factory);

  final Future<http.Response> Function() factory;
  final started = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!started.isCompleted) started.complete();
    final response = await factory();
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}

class _SequenceClient extends http.BaseClient {
  _SequenceClient(this.factory);

  final http.Response Function(int call) factory;
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = factory(calls++);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
