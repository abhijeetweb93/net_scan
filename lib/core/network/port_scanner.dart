import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';

class PortScanResult {
  final String ip;
  final int port;
  final bool isOpen;
  final String? service;
  final int? latencyMs;
  final String? banner;

  const PortScanResult({
    required this.ip,
    required this.port,
    required this.isOpen,
    this.service,
    this.latencyMs,
    this.banner,
  });
}

/// Full TCP port scanner with banner grabbing
class PortScanner {
  bool _cancelled = false;

  void cancel() => _cancelled = true;
  void reset() => _cancelled = false;

  /// Scan a single port on an IP
  Future<PortScanResult> scanPort(
    String ip,
    int port, {
    Duration timeout = const Duration(milliseconds: 500),
    bool grabBanner = false,
  }) async {
    if (_cancelled) {
      return PortScanResult(ip: ip, port: port, isOpen: false);
    }

    final stopwatch = Stopwatch()..start();
    Socket? socket;

    try {
      socket = await Socket.connect(ip, port, timeout: timeout);
      stopwatch.stop();

      String? banner;
      if (grabBanner) {
        banner = await _grabBanner(socket, port);
      }

      return PortScanResult(
        ip: ip,
        port: port,
        isOpen: true,
        service: PortServices.getService(port),
        latencyMs: stopwatch.elapsedMilliseconds,
        banner: banner,
      );
    } on SocketException {
      return PortScanResult(
        ip: ip,
        port: port,
        isOpen: false,
        service: PortServices.getService(port),
      );
    } on TimeoutException {
      return PortScanResult(
        ip: ip,
        port: port,
        isOpen: false,
        service: PortServices.getService(port),
      );
    } catch (e) {
      AppLogger.debug('Port scan error $ip:$port - $e');
      return PortScanResult(
        ip: ip,
        port: port,
        isOpen: false,
        service: PortServices.getService(port),
      );
    } finally {
      socket?.destroy();
      stopwatch.stop();
    }
  }

  /// Grab service banner from an open socket
  Future<String?> _grabBanner(Socket socket, int port) async {
    try {
      final completer = Completer<String?>();
      final buffer = StringBuffer();

      socket.setOption(SocketOption.tcpNoDelay, true);

      // Send probe for HTTP
      if (port == 80 || port == 8080 || port == 8443) {
        socket.write('HEAD / HTTP/1.0\r\n\r\n');
      }

      final subscription = socket.listen(
        (data) {
          buffer.write(String.fromCharCodes(data));
          if (buffer.length > 256) {
            completer.complete(buffer.toString().substring(0, 256));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.isNotEmpty ? buffer.toString() : null);
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      final result = await completer.future.timeout(
        const Duration(milliseconds: 1000),
        onTimeout: () => buffer.isNotEmpty ? buffer.toString() : null,
      );

      subscription.cancel();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Scan multiple ports on a host concurrently
  Stream<PortScanResult> scanHost({
    required String ip,
    required List<int> ports,
    int concurrency = 20,
    Duration timeout = const Duration(milliseconds: 500),
    bool grabBanners = false,
  }) async* {
    _cancelled = false;

    final controller = StreamController<PortScanResult>();
    var completed = 0;
    var running = 0;
    var index = 0;
    final total = ports.length;

    if (total == 0) return;

    void startNext() {
      while (running < concurrency && index < total && !_cancelled) {
        final port = ports[index++];
        running++;
        scanPort(ip, port, timeout: timeout, grabBanner: grabBanners)
            .then((result) {
          running--;
          completed++;
          if (!controller.isClosed) {
            if (result.isOpen) controller.add(result);
            if (completed == total || _cancelled) {
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

  /// Scan all 65535 ports (resource intensive!)
  Stream<PortScanResult> fullPortScan({
    required String ip,
    Duration timeout = const Duration(milliseconds: 300),
    int concurrency = 100,
  }) {
    final allPorts = List.generate(65535, (i) => i + 1);
    return scanHost(
      ip: ip,
      ports: allPorts,
      concurrency: concurrency,
      timeout: timeout,
    );
  }
}
