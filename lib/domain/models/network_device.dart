import 'package:equatable/equatable.dart';

enum DeviceType {
  router,
  smartphone,
  tablet,
  laptop,
  desktop,
  smartTv,
  iotDevice,
  printer,
  gamingConsole,
  networkCamera,
  smartSpeaker,
  unknown,
}

enum DeviceStatus {
  online,
  offline,
  unknown,
}

class OpenPort extends Equatable {
  final int port;
  final String? service;
  final String? protocol;
  final bool isOpen;

  const OpenPort({
    required this.port,
    this.service,
    this.protocol,
    required this.isOpen,
  });

  @override
  List<Object?> get props => [port, service, protocol, isOpen];

  OpenPort copyWith({
    int? port,
    String? service,
    String? protocol,
    bool? isOpen,
  }) {
    return OpenPort(
      port: port ?? this.port,
      service: service ?? this.service,
      protocol: protocol ?? this.protocol,
      isOpen: isOpen ?? this.isOpen,
    );
  }

  Map<String, dynamic> toJson() => {
        'port': port,
        'service': service,
        'protocol': protocol,
        'isOpen': isOpen,
      };

  factory OpenPort.fromJson(Map<String, dynamic> json) => OpenPort(
        port: json['port'] as int,
        service: json['service'] as String?,
        protocol: json['protocol'] as String?,
        isOpen: json['isOpen'] as bool,
      );
}

class NetworkDevice extends Equatable {
  final String ip;
  final String? macAddress;
  final String? hostname;
  final String? vendor;
  final DeviceType deviceType;
  final List<OpenPort> openPorts;
  final bool isGateway;
  final int? latency; // in milliseconds
  final DateTime lastSeen;
  final DeviceStatus status;
  final String? mdnsName;
  final String? ssdpDescription;
  final Map<String, String> metadata;

  const NetworkDevice({
    required this.ip,
    this.macAddress,
    this.hostname,
    this.vendor,
    this.deviceType = DeviceType.unknown,
    this.openPorts = const [],
    this.isGateway = false,
    this.latency,
    required this.lastSeen,
    this.status = DeviceStatus.unknown,
    this.mdnsName,
    this.ssdpDescription,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [
        ip,
        macAddress,
        hostname,
        vendor,
        deviceType,
        openPorts,
        isGateway,
        latency,
        lastSeen,
        status,
        mdnsName,
        ssdpDescription,
        metadata,
      ];

  NetworkDevice copyWith({
    String? ip,
    String? macAddress,
    String? hostname,
    String? vendor,
    DeviceType? deviceType,
    List<OpenPort>? openPorts,
    bool? isGateway,
    int? latency,
    DateTime? lastSeen,
    DeviceStatus? status,
    String? mdnsName,
    String? ssdpDescription,
    Map<String, String>? metadata,
  }) {
    return NetworkDevice(
      ip: ip ?? this.ip,
      macAddress: macAddress ?? this.macAddress,
      hostname: hostname ?? this.hostname,
      vendor: vendor ?? this.vendor,
      deviceType: deviceType ?? this.deviceType,
      openPorts: openPorts ?? this.openPorts,
      isGateway: isGateway ?? this.isGateway,
      latency: latency ?? this.latency,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      mdnsName: mdnsName ?? this.mdnsName,
      ssdpDescription: ssdpDescription ?? this.ssdpDescription,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Merge another device's data into this one (non-null fields win)
  NetworkDevice mergeWith(NetworkDevice other) {
    return NetworkDevice(
      ip: ip,
      macAddress: macAddress ?? other.macAddress,
      hostname: hostname ?? other.hostname,
      vendor: vendor ?? other.vendor,
      deviceType: deviceType != DeviceType.unknown ? deviceType : other.deviceType,
      openPorts: {...openPorts, ...other.openPorts}.toList(),
      isGateway: isGateway || other.isGateway,
      latency: latency ?? other.latency,
      lastSeen: lastSeen.isAfter(other.lastSeen) ? lastSeen : other.lastSeen,
      status: status != DeviceStatus.unknown ? status : other.status,
      mdnsName: mdnsName ?? other.mdnsName,
      ssdpDescription: ssdpDescription ?? other.ssdpDescription,
      metadata: {...metadata, ...other.metadata},
    );
  }

  String get displayName {
    if (hostname != null && hostname!.isNotEmpty) return hostname!;
    if (mdnsName != null && mdnsName!.isNotEmpty) return mdnsName!;
    if (vendor != null && vendor!.isNotEmpty) return '$vendor Device';
    return ip;
  }

  String get deviceTypeLabel {
    switch (deviceType) {
      case DeviceType.router:
        return 'Router / Gateway';
      case DeviceType.smartphone:
        return 'Smartphone';
      case DeviceType.tablet:
        return 'Tablet';
      case DeviceType.laptop:
        return 'Laptop';
      case DeviceType.desktop:
        return 'Desktop PC';
      case DeviceType.smartTv:
        return 'Smart TV';
      case DeviceType.iotDevice:
        return 'IoT Device';
      case DeviceType.printer:
        return 'Printer';
      case DeviceType.gamingConsole:
        return 'Gaming Console';
      case DeviceType.networkCamera:
        return 'Network Camera';
      case DeviceType.smartSpeaker:
        return 'Smart Speaker';
      case DeviceType.unknown:
        return 'Unknown Device';
    }
  }

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'macAddress': macAddress,
        'hostname': hostname,
        'vendor': vendor,
        'deviceType': deviceType.name,
        'openPorts': openPorts.map((p) => p.toJson()).toList(),
        'isGateway': isGateway,
        'latency': latency,
        'lastSeen': lastSeen.toIso8601String(),
        'status': status.name,
        'mdnsName': mdnsName,
        'ssdpDescription': ssdpDescription,
        'metadata': metadata,
      };

  factory NetworkDevice.fromJson(Map<String, dynamic> json) => NetworkDevice(
        ip: json['ip'] as String,
        macAddress: json['macAddress'] as String?,
        hostname: json['hostname'] as String?,
        vendor: json['vendor'] as String?,
        deviceType: DeviceType.values.firstWhere(
          (e) => e.name == json['deviceType'],
          orElse: () => DeviceType.unknown,
        ),
        openPorts: (json['openPorts'] as List<dynamic>?)
                ?.map((p) => OpenPort.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        isGateway: json['isGateway'] as bool? ?? false,
        latency: json['latency'] as int?,
        lastSeen: DateTime.parse(json['lastSeen'] as String),
        status: DeviceStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DeviceStatus.unknown,
        ),
        mdnsName: json['mdnsName'] as String?,
        ssdpDescription: json['ssdpDescription'] as String?,
        metadata: Map<String, String>.from(json['metadata'] as Map? ?? {}),
      );
}
