import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/core/utils/device_icons.dart';

class DeviceStatsWidget extends StatelessWidget {
  final List<NetworkDevice> devices;
  final Duration? scanDuration;

  const DeviceStatsWidget({
    super.key,
    required this.devices,
    this.scanDuration,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) return const SizedBox.shrink();

    final online = devices.where((d) => d.status == DeviceStatus.online).length;
    final withPorts = devices.where((d) => d.openPorts.isNotEmpty).length;
    final gateways = devices.where((d) => d.isGateway).length;
    final byType = _countByType();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Network Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (scanDuration != null)
                Text(
                  'Scanned in ${_formatDuration(scanDuration!)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Stat pills row
          Row(
            children: [
              _StatPill(
                value: '$online',
                label: 'Online',
                color: AppTheme.online,
                icon: Icons.circle,
              ),
              const SizedBox(width: 8),
              _StatPill(
                value: '${devices.length}',
                label: 'Total',
                color: AppTheme.accent,
                icon: Icons.devices_rounded,
              ),
              if (withPorts > 0) ...[
                const SizedBox(width: 8),
                _StatPill(
                  value: '$withPorts',
                  label: 'Open Ports',
                  color: AppTheme.warning,
                  icon: Icons.electrical_services_rounded,
                ),
              ],
            ],
          ),

          if (byType.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Device type breakdown
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: byType.entries.map((e) {
                final color = DeviceIcons.colorFor(e.key);
                return _TypeChip(
                  icon: DeviceIcons.iconFor(e.key),
                  label: '${e.value}× ${_shortLabel(e.key)}',
                  color: color,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Map<DeviceType, int> _countByType() {
    final map = <DeviceType, int>{};
    for (final d in devices) {
      if (d.deviceType != DeviceType.unknown) {
        map[d.deviceType] = (map[d.deviceType] ?? 0) + 1;
      }
    }
    // Sort by count desc
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  String _shortLabel(DeviceType type) {
    switch (type) {
      case DeviceType.router: return 'Router';
      case DeviceType.smartphone: return 'Phone';
      case DeviceType.tablet: return 'Tablet';
      case DeviceType.laptop: return 'Laptop';
      case DeviceType.desktop: return 'Desktop';
      case DeviceType.smartTv: return 'Smart TV';
      case DeviceType.iotDevice: return 'IoT';
      case DeviceType.printer: return 'Printer';
      case DeviceType.gamingConsole: return 'Console';
      case DeviceType.networkCamera: return 'Camera';
      case DeviceType.smartSpeaker: return 'Speaker';
      case DeviceType.unknown: return 'Unknown';
    }
  }

  String _formatDuration(Duration d) {
    final ms = d.inMilliseconds;
    if (ms < 1000) return '${ms}ms';
    return '${d.inSeconds}s';
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatPill({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
