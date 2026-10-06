import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:results/core/firebase/switch_latest.dart';

void main() {
  test('a slow cancelled query does not block its replacement', () async {
    final source = StreamController<int>();
    final cleanup = Completer<void>();
    final firstListening = Completer<void>();
    final first = StreamController<String>(
      onListen: firstListening.complete,
      onCancel: () => cleanup.future,
    );
    final next = Completer<void>();
    final subscription =
        switchLatest(
          source.stream,
          (int id) => id == 1 ? first.stream : Stream.value('new'),
        ).listen((value) {
          if (value == 'new') next.complete();
        });
    source.add(1);
    await firstListening.future;
    source.add(2);
    await next.future;
    expect(cleanup.isCompleted, false);
    cleanup.complete();
    await subscription.cancel();
    await first.close();
    await source.close();
  });
  test(
    'profile replacement cancels old query and disposal cancels new query',
    () async {
      final profiles = StreamController<int>();
      final first = StreamController<String>();
      final second = StreamController<String>();
      final firstCancelled = Completer<void>();
      final secondListening = Completer<void>();
      final secondCancelled = Completer<void>();
      first.onCancel = firstCancelled.complete;
      second.onListen = secondListening.complete;
      second.onCancel = secondCancelled.complete;
      final received = <String>[];
      final firstReceived = Completer<void>();
      final lastReceived = Completer<void>();
      final subscription =
          switchLatest(
            profiles.stream,
            (int id) => id == 1 ? first.stream : second.stream,
          ).listen((value) {
            received.add(value);
            if (value == 'first') firstReceived.complete();
            if (value == 'second') lastReceived.complete();
          });
      profiles.add(1);
      first.add('first');
      await firstReceived.future;
      profiles.add(2);
      await firstCancelled.future;
      await secondListening.future;
      first.add('stale');
      second.add('second');
      await lastReceived.future;
      expect(received, ['first', 'second']);
      await subscription.cancel();
      await secondCancelled.future;
      await profiles.close();
      await first.close();
      await second.close();
    },
  );
}
