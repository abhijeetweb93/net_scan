import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';

class TcpPingResult {
  final String ip;
  final bool isReachable;
  final int? latencyMs;
  final int? openPort;

  const TcpPingResult({
    required this.ip,
    required this.isReachable,
    this.latencyMs,
    this.openPort,
  });
}

/// TCP port scanner — finds OPEN PORTS on already-discovered devices.
/// NOT used for host discovery (ARP handles that).
/// Runs against devices found by ARP to detect services.
class TcpPingScanner {
  /// Common ports that indicate a device type / running service
  static const List<int> _commonPorts = [
    21, 22, 23, 25, 53, 80, 110, 143,
    443, 445, 548, 554, 631, 993, 995,
    1883, 3389, 5000, 5900, 7547,
    8080, 8443, 8888, 9000, 9100, 49152,
  ];

  bool _cancelled = false;

  void cancel() => _cancelled = true;
  void reset() => _cancelled = false;

  /// Check which ports are open on a single IP
  Future<TcpPingResult> scanOpenPorts(
    String ip, {
    Duration timeout = const Duration(milliseconds: 400),
    List<int>? ports,
  }) async {
    if (_cancelled) return TcpPingResult(ip: ip, isReachable: false);

    final targetPorts = ports ?? _commonPorts;
    final completer = Completer<TcpPingResult>();
    var pending = targetPorts.length;

    if (pending == 0) return TcpPingResult(ip: ip, isReachable: false);

    final stopwatch = Stopwatch()..start();

    for (final port in targetPorts) {
      if (_cancelled) break;
      _tryConnect(ip, port, timeout).then((connected) {
        if (connected && !completer.isCompleted) {
          completer.complete(TcpPingResult(
            ip: ip,
            isReachable: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            openPort: port,
          ));
        }
        pending--;
        if (pending <= 0 && !completer.isCompleted) {
          completer.complete(TcpPingResult(ip: ip, isReachable: false));
        }
      });
    }

    return completer.future;
  }

  Future<bool> _tryConnect(String ip, int port, Duration timeout) async {
    Socket? s;
    try {
      s = await Socket.connect(ip, port, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    } finally {
      s?.destroy();
    }
  }

  Stream<TcpPingResult> scanSubnet({
    required List<String> ips,
    Duration timeout = const Duration(milliseconds: 400),
    int concurrency = 30,
    void Function(int scanned, int total)? onProgress,
  }) async* {
    _cancelled = false;
    final controller = StreamController<TcpPingResult>();
    var completed = 0;
    var running = 0;
    var index = 0;
    final total = ips.length;

    if (total == 0) return;

    void startNext() {
      while (running < concurrency && index < total && !_cancelled) {
        final ip = ips[index++];
        running++;
        scanOpenPorts(ip, timeout: timeout).then((result) {
          running--;
          completed++;
          onProgress?.call(completed, total);
          if (!controller.isClosed) {
            if (result.isReachable) controller.add(result);
            if (completed >= total || _cancelled) {
              controller.close();
            } else {
              startNext();
            }
          }
        });
      }
    }

    startNext();
    yield* controller.stream;
  }
}
