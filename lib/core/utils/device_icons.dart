import 'package:flutter/material.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';

class DeviceIcons {
  DeviceIcons._();

  static IconData iconFor(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return Icons.router_rounded;
      case DeviceType.smartphone:
        return Icons.smartphone_rounded;
      case DeviceType.tablet:
        return Icons.tablet_rounded;
      case DeviceType.laptop:
        return Icons.laptop_rounded;
      case DeviceType.desktop:
        return Icons.desktop_windows_rounded;
      case DeviceType.smartTv:
        return Icons.tv_rounded;
      case DeviceType.iotDevice:
        return Icons.device_hub_rounded;
      case DeviceType.printer:
        return Icons.print_rounded;
      case DeviceType.gamingConsole:
        return Icons.sports_esports_rounded;
      case DeviceType.networkCamera:
        return Icons.videocam_rounded;
      case DeviceType.smartSpeaker:
        return Icons.speaker_rounded;
      case DeviceType.unknown:
        return Icons.devices_other_rounded;
    }
  }

  static Color colorFor(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.network);
      case DeviceType.smartphone:
      case DeviceType.tablet:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.mobile);
      case DeviceType.laptop:
      case DeviceType.desktop:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.computer);
      case DeviceType.smartTv:
      case DeviceType.gamingConsole:
      case DeviceType.smartSpeaker:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.media);
      case DeviceType.iotDevice:
      case DeviceType.networkCamera:
      case DeviceType.printer:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.iot);
      case DeviceType.unknown:
        return AppTheme.deviceTypeColor(DeviceTypeCategory.other);
    }
  }
}
