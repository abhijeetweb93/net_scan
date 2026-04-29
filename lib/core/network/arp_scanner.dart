import 'dart:async';
import 'dart:io';
import 'package:wifi_scanner/core/utils/app_logger.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';

class ArpResult {
  final String ip;
  final String? macAddress;
  final bool isReachable;
  const ArpResult({required this.ip, this.macAddress, required this.isReachable});
}

/// Dart-side fallback scanner (used if native channel unavailable).
/// Primary scanning is done natively via MainActivity.kt.
class ArpScanner {
  bool _cancelled = false;

  void cancel() => _cancelled = true;
  void reset() => _cancelled = false;

  Stream<ArpResult> scanSubnet({
    required String localIp,
    void Function(int done, int total)? onProgress,
  }) async* {
    _cancelled = false;
    final subnet = _subnet(localIp);
    final allIps = _prioritizedIps(subnet);
    final total = allIps.length;
    final found = <String>{};
    final ctrl = StreamController<ArpResult>();

    Future(() async {
      // Read ARP table first
      final arp = await _readArpTable(localIp);
      for (final r in arp) {
        if (!found.contains(r.ip)) {
          found.add(r.ip);
          if (!ctrl.isClosed) ctrl.add(r);
        }
      }
      onProgress?.call(10, total);

      // Ping sweep
      await _pingSweep(
        ips: allIps,
        onAlive: (ip) {
          if (!found.contains(ip) && !ctrl.isClosed) {
            found.add(ip);
            ctrl.add(ArpResult(ip: ip, isReachable: true));
          }
        },
        onProgress: (d) => onProgress?.call(10 + d * 80 ~/ total, total),
      );

      // Final ARP read
      final finalArp = await _readArpTable(localIp);
      for (final r in finalArp) {
        if (!found.contains(r.ip) && !ctrl.isClosed) {
          found.add(r.ip);
          ctrl.add(r);
        }
      }

      onProgress?.call(total, total);
      AppLogger.info('Dart scan: ${found.length} devices');
      if (!ctrl.isClosed) ctrl.close();
    });

    yield* ctrl.stream;
  }

  Future<void> _pingSweep({
    required List<String> ips,
    required void Function(String) onAlive,
    required void Function(int) onProgress,
  }) async {
    const concurrent = 60;
    var done = 0, started = 0, running = 0;
    final c = Completer<void>();

    void next() {
      while (running < concurrent && started < ips.length && !_cancelled) {
        final ip = ips[started++];
        running++;
        _ping(ip).then((ok) { if (ok) onAlive(ip); }).whenComplete(() {
          running--;
          done++;
          onProgress(done);
          if (done >= ips.length || _cancelled) {
            if (!c.isCompleted) c.complete();
          } else {
            next();
          }
        });
      }
      if (ips.isEmpty && !c.isCompleted) c.complete();
    }

    next();
    if (ips.isNotEmpty) await c.future;
  }

  Future<bool> _ping(String ip) async {
    try {
      final r = await Process.run('ping', ['-c', '1', '-W', '1', ip])
          .timeout(const Duration(seconds: 2));
      return r.exitCode == 0;
    } catch (_) {
      return _tcpProbe(ip);
    }
  }

  Future<bool> _tcpProbe(String ip) async {
    for (final port in [80, 443, 22, 53, 8080]) {
      Socket? s;
      try {
        s = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 800));
        s.destroy();
        return true;
      } on SocketException catch (e) {
        final code = e.osError?.errorCode ?? 0;
        if (code == 111 || code == 61) return true;
      } catch (_) {} finally { s?.destroy(); }
    }
    return false;
  }

  Future<List<ArpResult>> _readArpTable(String localIp) async {
    final out = <String, ArpResult>{};
    try {
      final f = File('/proc/net/arp');
      if (await f.exists()) {
        for (final line in (await f.readAsLines()).skip(1)) {
          final p = line.trim().split(RegExp(r'\s+'));
          if (p.length < 4) continue;
          final ip = p[0]; final mac = p[3];
          final flags = int.tryParse(p[2].replaceFirst('0x',''), radix:16) ?? 0;
          if (IpUtils.isValidIpv4(ip) && IpUtils.sameSubnet(ip, localIp) &&
              mac != '00:00:00:00:00:00' && mac.contains(':') && flags > 0) {
            out[ip] = ArpResult(ip: ip,
                macAddress: IpUtils.formatMac(mac.replaceAll(':','')),
                isReachable: true);
          }
        }
      }
    } catch (_) {}
    try {
      final r = await Process.run('ip', ['neigh', 'show'], runInShell: true)
          .timeout(const Duration(seconds: 3));
      final re = RegExp(r'^(\d+\.\d+\.\d+\.\d+)\s+.*lladdr\s+([0-9a-fA-F:]{17})',
          multiLine: true);
      for (final m in re.allMatches(r.stdout as String)) {
        final line = m.group(0) ?? '';
        if (line.contains('FAILED') || line.contains('INCOMPLETE')) continue;
        final ip = m.group(1)!;
        if (IpUtils.sameSubnet(ip, localIp)) {
          out.putIfAbsent(ip, () => ArpResult(ip: ip,
              macAddress: IpUtils.formatMac(m.group(2)!.replaceAll(':','')),
              isReachable: true));
        }
      }
    } catch (_) {}
    return out.values.toList();
  }

  List<String> _prioritizedIps(String subnet) {
    final ips = <String>[];
    final added = <int>{};
    void add(int i) { if (added.add(i)) ips.add('$subnet.$i'); }
    for (final i in [1, 254, 2, 3]) {
      add(i);
    }
    for (int i = 4; i <= 50; i++) {
      add(i);
    }
    for (int i = 100; i <= 200; i++) {
      add(i);
    }
    for (int i = 1; i <= 254; i++) {
      add(i);
    }
    return ips;
  }

  String _subnet(String ip) {
    final p = ip.split('.');
    return '${p[0]}.${p[1]}.${p[2]}';
  }
}
