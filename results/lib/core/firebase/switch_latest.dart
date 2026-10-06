import 'dart:async';

/// Replaces live queries, suppressing late results from cancelled queries.
Stream<R> switchLatest<T, R>(Stream<T> source, Stream<R> Function(T) project) {
  late StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;
  final cancellations = <Future<void>>{};
  var generation = 0;
  var cancelled = false;
  var outerDone = false;
  var innerActive = false;
  controller = StreamController<R>(
    onListen: () {
      outer = source.listen(
        (value) {
          final current = ++generation;
          innerActive = true;
          try {
            final old = inner;
            inner = null;
            if (old != null) {
              late Future<void> cancellation;
              cancellation = old
                  .cancel()
                  .catchError((Object error, StackTrace stack) {
                    if (!cancelled && !controller.isClosed) {
                      controller.addError(error, stack);
                    }
                  })
                  .whenComplete(() => cancellations.remove(cancellation));
              cancellations.add(cancellation);
            }
            if (cancelled || current != generation) return;
            inner = project(value).listen(
              (event) {
                if (!cancelled && current == generation) controller.add(event);
              },
              onError: (Object error, StackTrace stack) {
                if (!cancelled && current == generation) {
                  controller.addError(error, stack);
                }
              },
              onDone: () {
                if (cancelled || current != generation) return;
                innerActive = false;
                if (outerDone) controller.close();
              },
            );
          } catch (error, stack) {
            if (!cancelled && current == generation) {
              innerActive = false;
              controller.addError(error, stack);
              if (outerDone) controller.close();
            }
          }
        },
        onError: controller.addError,
        onDone: () {
          outerDone = true;
          if (!innerActive) controller.close();
        },
      );
    },
    onCancel: () async {
      cancelled = true;
      generation++;
      await outer?.cancel();
      await inner?.cancel();
      await Future.wait(cancellations.toList());
    },
  );
  return controller.stream;
}
