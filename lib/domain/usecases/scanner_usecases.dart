import 'package:dartz/dartz.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';
import 'package:wifi_scanner/core/utils/failures.dart';

/// UseCase: Start a full network scan
class StartNetworkScanUseCase {
  final ScannerRepository _repository;

  StartNetworkScanUseCase(this._repository);

  Stream<Either<Failure, ScanEvent>> call({
    required NetworkInfo networkInfo,
    ScanOptions? options,
  }) {
    return _repository.startScan(
      networkInfo: networkInfo,
      options: options,
    );
  }
}

/// UseCase: Stop ongoing scan
class StopNetworkScanUseCase {
  final ScannerRepository _repository;

  StopNetworkScanUseCase(this._repository);

  Future<void> call() => _repository.stopScan();
}

/// UseCase: Get current network information
class GetNetworkInfoUseCase {
  final ScannerRepository _repository;

  GetNetworkInfoUseCase(this._repository);

  Future<Either<Failure, NetworkInfo>> call() => _repository.getNetworkInfo();
}

/// UseCase: Scan ports on a device
class ScanDevicePortsUseCase {
  final ScannerRepository _repository;

  ScanDevicePortsUseCase(this._repository);

  Stream<Either<Failure, OpenPort>> call({
    required String ip,
    List<int>? ports,
  }) {
    final targetPorts = ports ??
        [
          21, 22, 23, 25, 53, 80, 110, 143, 443, 445,
          3389, 5900, 8080, 8443, 8888, 9000,
        ];
    return _repository.scanPorts(ip: ip, ports: targetPorts);
  }
}

/// UseCase: Lookup vendor from MAC address
class LookupVendorUseCase {
  final ScannerRepository _repository;

  LookupVendorUseCase(this._repository);

  Future<String?> call(String macAddress) => _repository.lookupVendor(macAddress);
}

/// UseCase: Get cached scan result
class GetLastScanResultUseCase {
  final ScannerRepository _repository;

  GetLastScanResultUseCase(this._repository);

  Future<Either<Failure, ScanResult?>> call() => _repository.getLastScanResult();
}

/// UseCase: Monitor network for device changes
class MonitorNetworkUseCase {
  final ScannerRepository _repository;

  MonitorNetworkUseCase(this._repository);

  Stream<Either<Failure, DeviceEvent>> call({
    required NetworkInfo networkInfo,
  }) {
    return _repository.monitorNetwork(networkInfo: networkInfo);
  }
}
