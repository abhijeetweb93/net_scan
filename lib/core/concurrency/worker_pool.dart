import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

/// A task to be processed by an isolate worker
class WorkerTask<T, R> {
  final T input;
  final Future<R> Function(T) computation;
  final Completer<R> _completer = Completer<R>();

  WorkerTask({required this.input, required this.computation});

  Future<R> get future => _completer.future;

  void complete(R result) => _completer.complete(result);
  void completeError(Object error, [StackTrace? trace]) =>
      _completer.completeError(error, trace);
}

/// Worker pool that manages concurrent execution of tasks
/// Uses Flutter's compute() for cross-platform isolate support
class WorkerPool<T, R> {
  final int workerCount;
  final Future<R> Function(T) _taskFunction;

  bool _isDisposed = false;
  final List<Future<void>> _activeWorkers = [];
  final StreamController<R> _resultsController = StreamController<R>.broadcast();

  WorkerPool({
    required this.workerCount,
    required Future<R> Function(T) taskFunction,
  }) : _taskFunction = taskFunction;

  Stream<R> get results => _resultsController.stream;

  /// Execute all tasks concurrently with controlled parallelism
  Future<List<R>> executeBatch(List<T> inputs) async {
    if (_isDisposed) throw StateError('WorkerPool is disposed');

    final results = <R>[];
    final semaphore = Semaphore(workerCount);
    final futures = <Future<void>>[];

    for (final input in inputs) {
      final future = semaphore.acquire().then((_) async {
        try {
          final result = await _taskFunction(input);
          results.add(result);
          if (!_resultsController.isClosed) {
            _resultsController.add(result);
          }
        } catch (e) {
          // Silently skip failed tasks in batch mode
        } finally {
          semaphore.release();
        }
      });
      futures.add(future);
    }

    await Future.wait(futures);
    return results;
  }

  /// Stream results as tasks complete
  Stream<R> executeStream(List<T> inputs) async* {
    if (_isDisposed) throw StateError('WorkerPool is disposed');

    final semaphore = Semaphore(workerCount);
    final controller = StreamController<R>();
    var pending = inputs.length;

    if (pending == 0) return;

    for (final input in inputs) {
      semaphore.acquire().then((_) async {
        try {
          final result = await _taskFunction(input);
          if (!controller.isClosed) controller.add(result);
        } catch (_) {
          // Skip failed individual tasks
        } finally {
          semaphore.release();
          pending--;
          if (pending == 0 && !controller.isClosed) {
            controller.close();
          }
        }
      });
    }

    yield* controller.stream;
  }

  void dispose() {
    _isDisposed = true;
    _resultsController.close();
  }
}

/// Simple semaphore for limiting concurrent operations
class Semaphore {
  final int maxCount;
  int _currentCount;
  final List<Completer<void>> _waiters = [];

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() {
    if (_currentCount > 0) {
      _currentCount--;
      return Future.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter.complete();
    } else {
      _currentCount++;
    }
  }

  int get availablePermits => _currentCount;
  int get waitingCount => _waiters.length;
}

/// Task queue with priority and cancellation support
class TaskQueue<T> {
  final int _maxConcurrency;
  int _running = 0;
  bool _cancelled = false;

  final List<_QueuedTask<T>> _pending = [];

  TaskQueue({int maxConcurrency = 50}) : _maxConcurrency = maxConcurrency;

  Future<List<T>> processAll(
    List<Future<T> Function()> taskFactories, {
    void Function(T)? onResult,
    void Function(int done, int total)? onProgress,
  }) async {
    _cancelled = false;
    final results = <T>[];
    final completer = Completer<List<T>>();
    var completed = 0;
    var started = 0;
    final total = taskFactories.length;

    void startNext() {
      while (_running < _maxConcurrency && started < total && !_cancelled) {
        final idx = started++;
        _running++;
        taskFactories[idx]().then((result) {
          if (!_cancelled) {
            results.add(result);
            onResult?.call(result);
          }
        }).catchError((_) {
          // ignore individual failures
        }).whenComplete(() {
          _running--;
          completed++;
          onProgress?.call(completed, total);
          if (completed == total || _cancelled) {
            if (!completer.isCompleted) completer.complete(results);
          } else {
            startNext();
          }
        });
      }
    }

    startNext();

    if (total == 0) return [];
    return completer.future;
  }

  void cancel() {
    _cancelled = true;
  }

  bool get isCancelled => _cancelled;
}

class _QueuedTask<T> {
  final Future<T> Function() factory;
  final Completer<T> completer;

  _QueuedTask(this.factory) : completer = Completer<T>();
}

/// Isolate-based compute wrapper for CPU-intensive tasks
class IsolateManager {
  IsolateManager._();

  /// Run a pure function in an isolate
  static Future<R> compute<T, R>(
    ComputeCallback<T, R> callback,
    T message,
  ) async {
    return Flutter.compute(callback, message);
  }
}

// Alias to avoid naming conflict
class Flutter {
  Flutter._();
  static Future<R> compute<T, R>(
    ComputeCallback<T, R> callback,
    T message,
  ) {
    return computeWithFlutter(callback, message);
  }
}

Future<R> computeWithFlutter<T, R>(
  ComputeCallback<T, R> callback,
  T message,
) {
  return compute(callback, message);
}
