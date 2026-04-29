import 'package:equatable/equatable.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';

class ScanProgress extends Equatable {
  final int scannedCount;
  final int totalCount;
  final int devicesFound;
  final String currentIp;
  final double percentage;
  final Duration elapsed;

  const ScanProgress({
    required this.scannedCount,
    required this.totalCount,
    required this.devicesFound,
    required this.currentIp,
    required this.elapsed,
  }) : percentage = totalCount > 0 ? (scannedCount / totalCount) * 100 : 0.0;

  @override
  List<Object?> get props =>
      [scannedCount, totalCount, devicesFound, currentIp, elapsed];

  ScanProgress copyWith({
    int? scannedCount,
    int? totalCount,
    int? devicesFound,
    String? currentIp,
    Duration? elapsed,
  }) {
    return ScanProgress(
      scannedCount: scannedCount ?? this.scannedCount,
      totalCount: totalCount ?? this.totalCount,
      devicesFound: devicesFound ?? this.devicesFound,
      currentIp: currentIp ?? this.currentIp,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class NetworkInfo extends Equatable {
  final String localIp;
  final String subnetMask;
  final String gateway;
  final String subnet;
  final String? ssid;
  final String? bssid;
  final int? signalStrength;

  const NetworkInfo({
    required this.localIp,
    required this.subnetMask,
    required this.gateway,
    required this.subnet,
    this.ssid,
    this.bssid,
    this.signalStrength,
  });

  @override
  List<Object?> get props =>
      [localIp, subnetMask, gateway, subnet, ssid, bssid, signalStrength];

  List<String> get allHostIps {
    final parts = subnet.split('.');
    if (parts.length < 3) return [];
    final base = '${parts[0]}.${parts[1]}.${parts[2]}';
    return List.generate(254, (i) => '$base.${i + 1}');
  }
}

class ScanResult extends Equatable {
  final List<NetworkDevice> devices;
  final NetworkInfo networkInfo;
  final Duration scanDuration;
  final DateTime completedAt;
  final ScanResultStatus status;
  final String? errorMessage;

  const ScanResult({
    required this.devices,
    required this.networkInfo,
    required this.scanDuration,
    required this.completedAt,
    required this.status,
    this.errorMessage,
  });

  @override
  List<Object?> get props =>
      [devices, networkInfo, scanDuration, completedAt, status, errorMessage];

  int get onlineDeviceCount =>
      devices.where((d) => d.status == DeviceStatus.online).length;
}

enum ScanResultStatus { success, partial, failed, cancelled }
