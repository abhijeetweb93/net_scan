import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';
import 'package:wifi_scanner/core/network/tcp_ping_scanner.dart';
import 'package:wifi_scanner/core/network/arp_scanner.dart';
import 'package:wifi_scanner/core/network/port_scanner.dart';
import 'package:wifi_scanner/core/discovery/mdns_discovery.dart';
import 'package:wifi_scanner/core/discovery/ssdp_discovery.dart';
import 'package:wifi_scanner/core/utils/app_logger.dart';
import 'package:wifi_scanner/core/utils/device_fingerprinter.dart';
import 'package:wifi_scanner/core/utils/failures.dart';
import 'package:wifi_scanner/core/utils/ip_utils.dart';
import 'package:wifi_scanner/data/datasources/network_info_datasource.dart';
import 'package:wifi_scanner/data/datasources/native_scanner_datasource.dart';
import 'package:wifi_scanner/data/datasources/oui_datasource.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  final TcpPingScanner _tcpScanner;
  final ArpScanner _arpScanner;
  final PortScanner _portScanner;
  final MdnsDiscovery _mdnsDiscovery;
  final SsdpDiscovery _ssdpDiscovery;
  final OuiDatasource _ouiDatasource;
  final NetworkInfoDatasource _networkInfoDatasource;
  final NativeScannerDatasource _nativeScanner;

  bool _scanning = false;
  StreamController<Either<Failure, ScanEvent>>? _scanController;

  ScannerRepositoryImpl({
    required TcpPingScanner tcpScanner,
    required ArpScanner arpScanner,
    required PortScanner portScanner,
    required MdnsDiscovery mdnsDiscovery,
    required SsdpDiscovery ssdpDiscovery,
    required OuiDatasource ouiDatasource,
    required NetworkInfoDatasource networkInfoDatasource,
    required NativeScannerDatasource nativeScanner,
  })  : _tcpScanner = tcpScanner,
        _arpScanner = arpScanner,
        _portScanner = portScanner,
        _mdnsDiscovery = mdnsDiscovery,
        _ssdpDiscovery = ssdpDiscovery,
        _ouiDatasource = ouiDatasource,
        _networkInfoDatasource = networkInfoDatasource,
        _nativeScanner = nativeScanner;

  @override
  Stream<Either<Failure, ScanEvent>> startScan({
    required NetworkInfo networkInfo,
    ScanOptions? options,
  }) {
    final opts = options ?? const ScanOptions();
    _scanController?.close();
    _scanController = StreamController<Either<Failure, ScanEvent>>.broadcast();
    _scanning = true;
    _runScan(networkInfo, opts);
    return _scanController!.stream;
  }

  Future<void> _runScan(NetworkInfo networkInfo, ScanOptions opts) async {
    final startTime = DateTime.now();
    final devicesMap = <String, NetworkDevice>{};

    void emit(ScanEvent e) {
      if (_scanController == null || _scanController!.isClosed) return;
      _scanController!.add(Right(e));
    }

    void emitProgress(int done, int total, {String msg = ''}) {
      emit(ScanProgressEvent(ScanProgress(
        scannedCount: done,
        totalCount: total,
        devicesFound: devicesMap.length,
        currentIp: msg.isEmpty ? 'Scanning network...' : msg,
        elapsed: DateTime.now().difference(startTime),
      )));
    }

    Future<void> upsert(NetworkDevice incoming) async {
      final existing = devicesMap[incoming.ip];
      NetworkDevice d = existing != null ? existing.mergeWith(incoming) : incoming;

      if (d.macAddress != null && d.vendor == null) {
        final v = await _ouiDatasource.lookupVendor(d.macAddress!);
        if (v != null) d = d.copyWith(vendor: v);
      }
      if (d.hostname == null || d.hostname!.isEmpty || d.hostname == d.ip) {
        final h = await _networkInfoDatasource.resolveHostname(d.ip);
        if (h != null && h != d.ip) d = d.copyWith(hostname: h);
      }
      if (d.deviceType == DeviceType.unknown) {
        d = d.copyWith(deviceType: DeviceFingerprinter.fingerprint(
          vendor: d.vendor, hostname: d.hostname,
          mdnsName: d.mdnsName, ssdpDescription: d.ssdpDescription,
          openPorts: d.openPorts.map((p) => p.port).toList(),
          isGateway: d.isGateway,
        ));
      }
      devicesMap[d.ip] = d;
      emit(DeviceDiscoveredScanEvent(d));
    }

    try {
      AppLogger.info('=== SCAN START ===');

      // Background: mDNS + SSDP
      _mdnsDiscovery.discover(timeout: const Duration(seconds: 15)).listen(
        (d) async {
          if (!_scanning) return;
          await upsert(NetworkDevice(
            ip: d.ip, mdnsName: d.name, hostname: d.name,
            lastSeen: DateTime.now(), status: DeviceStatus.online,
          ));
        },
      );

      _ssdpDiscovery.discover(timeout: const Duration(seconds: 15)).listen(
        (d) async {
          if (!_scanning) return;
          final enriched = await _ssdpDiscovery.enrichDevice(d);
          await upsert(NetworkDevice(
            ip: d.ip,
            hostname: enriched?.friendlyName ?? d.server,
            vendor: enriched?.manufacturer,
            ssdpDescription: enriched?.friendlyName,
            lastSeen: DateTime.now(), status: DeviceStatus.online,
          ));
        },
      );

      emitProgress(0, 254, msg: 'Starting scan...');

      // ── PRIMARY: Native Android scanner ──────────────────────────────
      // Uses InetAddress.isReachable() (true ICMP) + ARP + TCP
      // This finds ALL devices including iOS with privacy mode
      AppLogger.info('Starting native scan...');
      emitProgress(10, 254, msg: 'Scanning with native engine...');

      final subnet = networkInfo.localIp.split('.').take(3).join('.');
      final nativeDevices = await _nativeScanner.scanNetwork(
        subnet: subnet,
        gateway: networkInfo.gateway,
      );

      AppLogger.info('Native scan: ${nativeDevices.length} devices');

      for (final d in nativeDevices) {
        if (!_scanning) break;
        final ip = d['ip'] as String? ?? '';
        if (ip.isEmpty) continue;
        final mac = d['macAddress'] as String? ?? '';
        await upsert(NetworkDevice(
          ip: ip,
          macAddress: mac.isEmpty ? null : mac,
          isGateway: ip == networkInfo.gateway,
          lastSeen: DateTime.now(),
          status: DeviceStatus.online,
        ));
      }

      emitProgress(200, 254, msg: 'Enriching device info...');

      // ── FALLBACK: Dart scanner for any IPs native missed ─────────────
      if (_scanning && nativeDevices.length < 3) {
        AppLogger.info('Native scan returned few results, running Dart fallback');
        await for (final result in _arpScanner.scanSubnet(
          localIp: networkInfo.localIp,
          onProgress: (done, total) => emitProgress(done, total),
        )) {
          if (!_scanning) break;
          await upsert(NetworkDevice(
            ip: result.ip,
            macAddress: result.macAddress,
            isGateway: result.ip == networkInfo.gateway,
            lastSeen: DateTime.now(),
            status: DeviceStatus.online,
          ));
        }
      }

      if (!_scanning) {
        _scanController?.add(const Left(ScanCancelledFailure()));
        _scanController?.close();
        _scanning = false;
        return;
      }

      // ── Port scan on found devices ────────────────────────────────────
      AppLogger.info('Port scanning ${devicesMap.length} devices');
      emitProgress(220, 254, msg: 'Detecting open ports...');

      await for (final r in _tcpScanner.scanSubnet(
        ips: devicesMap.keys.toList(),
        concurrency: 20,
        timeout: const Duration(milliseconds: 600),
      )) {
        if (!_scanning) break;
        final existing = devicesMap[r.ip];
        if (existing != null && r.openPort != null) {
          await upsert(existing.copyWith(
            latency: existing.latency ?? r.latencyMs,
            openPorts: [
              ...existing.openPorts,
              OpenPort(port: r.openPort!, service: PortServices.getService(r.openPort!), isOpen: true),
            ],
          ));
        }
      }

      emitProgress(254, 254, msg: 'Done');

      final duration = DateTime.now().difference(startTime);
      final devices = devicesMap.values.toList()
        ..sort((a, b) => IpUtils.ipToInt(a.ip).compareTo(IpUtils.ipToInt(b.ip)));

      AppLogger.info('=== DONE: ${devices.length} devices in ${duration.inMilliseconds}ms ===');

      final result = ScanResult(
        devices: devices,
        networkInfo: networkInfo,
        scanDuration: duration,
        completedAt: DateTime.now(),
        status: ScanResultStatus.success,
      );

      saveScanResult(result);
      emit(ScanCompletedScanEvent(result));
    } catch (e, stack) {
      AppLogger.error('Scan failed', e, stack);
      _scanController?.add(Left(NetworkFailure(message: e.toString(), cause: e)));
    } finally {
      _scanning = false;
      _scanController?.close();
    }
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
    await _nativeScanner.stopScan();
    _arpScanner.cancel();
    _tcpScanner.cancel();
    _portScanner.cancel();
    _mdnsDiscovery.cancel();
    _ssdpDiscovery.cancel();
  }

  @override
  Future<Either<Failure, NetworkInfo>> getNetworkInfo() async {
    try {
      // Try native first (more reliable on Android)
      final native = await _nativeScanner.getNetworkInfo();
      if (native != null) {
        final localIp = native['localIp'] as String? ?? '';
        final gateway = native['gateway'] as String? ?? '';
        if (localIp.isNotEmpty && localIp != '0.0.0.0') {
          final subnet = IpUtils.getSubnet(localIp, '255.255.255.0');
          return Right(NetworkInfo(
            localIp: localIp,
            subnetMask: '255.255.255.0',
            gateway: gateway.isEmpty ? IpUtils.guessGateway(localIp) : gateway,
            subnet: subnet,
            ssid: native['ssid'] as String?,
            bssid: native['bssid'] as String?,
          ));
        }
      }
      // Fallback to Dart datasource
      return Right(await _networkInfoDatasource.getNetworkInfo());
    } catch (e) {
      return Left(NetworkFailure(message: 'Network info failed: $e', cause: e));
    }
  }

  @override
  Stream<Either<Failure, OpenPort>> scanPorts({
    required String ip,
    required List<int> ports,
  }) async* {
    _portScanner.reset();
    await for (final r in _portScanner.scanHost(ip: ip, ports: ports)) {
      if (r.isOpen) {
        yield Right(OpenPort(port: r.port, service: r.service, isOpen: true));
      }
    }
  }

  @override
  Future<String?> lookupVendor(String mac) => _ouiDatasource.lookupVendor(mac);

  @override
  Future<Either<Failure, ScanResult?>> getLastScanResult() async {
    try {
      final f = _cacheFile();
      if (!await f.exists()) return const Right(null);
      final raw = await f.readAsString();
      if (raw.isEmpty) return const Right(null);
      return Right(_fromJson(jsonDecode(raw) as Map<String, dynamic>));
    } catch (e) {
      return Left(CacheFailure(message: 'Cache load failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveScanResult(ScanResult result) async {
    try {
      await _cacheFile().writeAsString(jsonEncode(_toJson(result)));
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: 'Cache save failed: $e'));
    }
  }

  File _cacheFile() =>
      File('${Directory.systemTemp.path}/wifi_scanner_cache.json');

  @override
  Stream<Either<Failure, DeviceEvent>> monitorNetwork({
    required NetworkInfo networkInfo,
  }) async* {
    final known = <String, NetworkDevice>{};
    await for (final e in startScan(networkInfo: networkInfo)) {
      e.fold((_) {}, (ev) {
        if (ev is DeviceDiscoveredScanEvent) known[ev.device.ip] = ev.device;
      });
    }
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      final current = <String, NetworkDevice>{};
      await for (final e in startScan(networkInfo: networkInfo)) {
        e.fold((_) {}, (ev) {
          if (ev is DeviceDiscoveredScanEvent) current[ev.device.ip] = ev.device;
        });
      }
      for (final ip in current.keys) {
        if (!known.containsKey(ip)) {
          yield Right(DeviceJoinedEvent(current[ip]!));
          known[ip] = current[ip]!;
        }
      }
      for (final ip in known.keys.toList()) {
        if (!current.containsKey(ip)) {
          yield Right(DeviceLeftEvent(known[ip]!));
          known.remove(ip);
        }
      }
    }
  }

  Map<String, dynamic> _toJson(ScanResult r) => {
    'devices': r.devices.map((d) => d.toJson()).toList(),
    'networkInfo': {
      'localIp': r.networkInfo.localIp, 'subnetMask': r.networkInfo.subnetMask,
      'gateway': r.networkInfo.gateway, 'subnet': r.networkInfo.subnet,
      'ssid': r.networkInfo.ssid, 'bssid': r.networkInfo.bssid,
    },
    'scanDurationMs': r.scanDuration.inMilliseconds,
    'completedAt': r.completedAt.toIso8601String(),
    'status': r.status.name,
  };

  ScanResult _fromJson(Map<String, dynamic> j) {
    final ni = j['networkInfo'] as Map<String, dynamic>;
    return ScanResult(
      devices: (j['devices'] as List)
          .map((d) => NetworkDevice.fromJson(d as Map<String, dynamic>)).toList(),
      networkInfo: NetworkInfo(
        localIp: ni['localIp'] as String, subnetMask: ni['subnetMask'] as String,
        gateway: ni['gateway'] as String, subnet: ni['subnet'] as String,
        ssid: ni['ssid'] as String?, bssid: ni['bssid'] as String?,
      ),
      scanDuration: Duration(milliseconds: j['scanDurationMs'] as int),
      completedAt: DateTime.parse(j['completedAt'] as String),
      status: ScanResultStatus.values.firstWhere(
        (e) => e.name == j['status'], orElse: () => ScanResultStatus.success),
    );
  }
}
