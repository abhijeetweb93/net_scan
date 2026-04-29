import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/core/utils/device_icons.dart';

class DeviceListWidget extends StatelessWidget {
  final List<NetworkDevice> devices;
  final void Function(NetworkDevice) onDeviceTap;
  final bool isScanning;

  const DeviceListWidget({
    super.key,
    required this.devices,
    required this.onDeviceTap,
    this.isScanning = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return DeviceListTile(
          key: ValueKey(devices[index].ip),
          device: devices[index],
          onTap: () => onDeviceTap(devices[index]),
          animIndex: isScanning ? 0 : index,
        );
      },
    );
  }
}

class DeviceListTile extends StatelessWidget {
  final NetworkDevice device;
  final VoidCallback onTap;
  final int animIndex;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.onTap,
    this.animIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = DeviceIcons.colorFor(device.deviceType);
    final icon = DeviceIcons.iconFor(device.deviceType);
    final isOnline = device.status == DeviceStatus.online;

    // Best display name: hostname > mDNS name > vendor+IP > IP
    final displayName = _bestName();
    final subtitle = _subtitle(displayName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: device.isGateway
                ? const Color(0xFF7C3AED).withOpacity(0.4)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            // Device icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: iconColor.withOpacity(0.25)),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Device info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name + gateway badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (device.isGateway)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text('GW',
                              style: TextStyle(
                                  color: Color(0xFFA78BFA),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),

                  // Row 2: IP + vendor/type
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        device.ip,
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: Colors.white24, fontSize: 12)),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Row 3: Open ports
                  if (device.openPorts.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      children: device.openPorts
                          .take(5)
                          .map((p) => _PortPill(port: p))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Right: status + latency
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isOnline ? AppTheme.online : AppTheme.offline,
                        shape: BoxShape.circle,
                        boxShadow: isOnline
                            ? [BoxShadow(
                                color: AppTheme.online.withOpacity(0.5),
                                blurRadius: 4)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: isOnline ? AppTheme.online : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (device.latency != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${device.latency}ms',
                    style: TextStyle(
                      color: _latencyColor(device.latency!),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18),
              ],
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: (animIndex * 30).clamp(0, 300)))
        .fadeIn(duration: 250.ms)
        .slideX(begin: 0.04, end: 0);
  }

  /// Best human-readable name for the device
  String _bestName() {
    // 1. Hostname (from DNS or NetBIOS) — most descriptive
    if (device.hostname != null &&
        device.hostname!.isNotEmpty &&
        device.hostname != device.ip) {
      return device.hostname!;
    }
    // 2. mDNS name (e.g. "Living-Room-AppleTV.local")
    if (device.mdnsName != null && device.mdnsName!.isNotEmpty) {
      return device.mdnsName!;
    }
    // 3. SSDP friendly name (e.g. "Samsung Smart TV")
    if (device.ssdpDescription != null &&
        device.ssdpDescription!.isNotEmpty) {
      return device.ssdpDescription!;
    }
    // 4. Vendor + device type (e.g. "Apple Device")
    if (device.vendor != null && device.vendor!.isNotEmpty) {
      if (device.deviceType != DeviceType.unknown) {
        return '${device.vendor} ${device.deviceTypeLabel}';
      }
      return device.vendor!;
    }
    // 5. Gateway label
    if (device.isGateway) return 'Router / Gateway';
    // 6. Device type
    if (device.deviceType != DeviceType.unknown) {
      return device.deviceTypeLabel;
    }
    // 7. Fall back to IP
    return device.ip;
  }

  /// Secondary info line shown below the name
  String _subtitle(String displayName) {
    final parts = <String>[];
    // If name is the hostname, show vendor as subtitle
    if (device.hostname != null &&
        device.hostname == displayName &&
        device.vendor != null) {
      parts.add(device.vendor!);
    }
    // If name is vendor, show device type
    else if (device.vendor != null &&
        displayName.startsWith(device.vendor!) &&
        device.deviceType != DeviceType.unknown) {
      parts.add(device.deviceTypeLabel);
    }
    // If name is IP, show vendor if available
    else if (displayName == device.ip && device.vendor != null) {
      parts.add(device.vendor!);
    }
    return parts.join(' · ');
  }

  Color _latencyColor(int ms) {
    if (ms < 10) return AppTheme.online;
    if (ms < 50) return const Color(0xFF84CC16);
    if (ms < 100) return AppTheme.warning;
    return AppTheme.error;
  }
}

class _PortPill extends StatelessWidget {
  final OpenPort port;
  const _PortPill({required this.port});

  @override
  Widget build(BuildContext context) {
    final service = port.service;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Text(
        service != null ? service : ':${port.port}',
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 10,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
