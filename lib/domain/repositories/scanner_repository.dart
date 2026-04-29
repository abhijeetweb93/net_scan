import 'package:dartz/dartz.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/core/utils/failures.dart';

abstract class ScannerRepository {
  Stream<Either<Failure, ScanEvent>> startScan({
    required NetworkInfo networkInfo,
    ScanOptions? options,
  });

  Future<void> stopScan();

  Future<Either<Failure, NetworkInfo>> getNetworkInfo();

  Stream<Either<Failure, OpenPort>> scanPorts({
    required String ip,
    required List<int> ports,
  });

  Future<String?> lookupVendor(String macAddress);

  Future<Either<Failure, ScanResult?>> getLastScanResult();

  Future<Either<Failure, void>> saveScanResult(ScanResult result);

  Stream<Either<Failure, DeviceEvent>> monitorNetwork({
    required NetworkInfo networkInfo,
  });
}

class ScanOptions {
  final bool enableArp;
  final bool enableTcpPing;
  final bool enableUdp;
  final bool enableMdns;
  final bool enableSsdp;
  final bool enablePortScan;
  final List<int> portsToScan;
  final Duration timeout;
  final int workerCount;

  const ScanOptions({
    this.enableArp = true,
    this.enableTcpPing = true,
    this.enableUdp = true,
    this.enableMdns = true,
    this.enableSsdp = true,
    this.enablePortScan = false,
    this.portsToScan = const [21, 22, 23, 80, 443, 8080, 8443],
    this.timeout = const Duration(milliseconds: 1500),
    this.workerCount = 80,
  });

  ScanOptions copyWith({
    bool? enableArp,
    bool? enableTcpPing,
    bool? enableUdp,
    bool? enableMdns,
    bool? enableSsdp,
    bool? enablePortScan,
    List<int>? portsToScan,
    Duration? timeout,
    int? workerCount,
  }) {
    return ScanOptions(
      enableArp: enableArp ?? this.enableArp,
      enableTcpPing: enableTcpPing ?? this.enableTcpPing,
      enableUdp: enableUdp ?? this.enableUdp,
      enableMdns: enableMdns ?? this.enableMdns,
      enableSsdp: enableSsdp ?? this.enableSsdp,
      enablePortScan: enablePortScan ?? this.enablePortScan,
      portsToScan: portsToScan ?? this.portsToScan,
      timeout: timeout ?? this.timeout,
      workerCount: workerCount ?? this.workerCount,
    );
  }
}

// ── Domain scan stream events (prefixed with Scan to avoid BLoC name clash) ──

abstract class ScanEvent {}

class DeviceDiscoveredScanEvent extends ScanEvent {
  final NetworkDevice device;
  DeviceDiscoveredScanEvent(this.device);
}

class ScanProgressEvent extends ScanEvent {
  final ScanProgress progress;
  ScanProgressEvent(this.progress);
}

class ScanCompletedScanEvent extends ScanEvent {
  final ScanResult result;
  ScanCompletedScanEvent(this.result);
}

// ── Network monitoring events ─────────────────────────────────────────────────

abstract class DeviceEvent {}

class DeviceJoinedEvent extends DeviceEvent {
  final NetworkDevice device;
  DeviceJoinedEvent(this.device);
}

class DeviceLeftEvent extends DeviceEvent {
  final NetworkDevice device;
  DeviceLeftEvent(this.device);
}
