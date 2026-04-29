import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_bloc.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_event.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/core/utils/device_icons.dart';
import 'package:wifi_scanner/presentation/ui/widgets/port_chip_widget.dart';

class DeviceDetailScreen extends StatefulWidget {
  final NetworkDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  late NetworkDevice _device;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
  }

  void _startPortScan() {
    context.read<ScannerBloc>().add(ScanPorts(ip: _device.ip));
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = DeviceIcons.colorFor(_device.deviceType);
    final icon = DeviceIcons.iconFor(_device.deviceType);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          // No-op for now
        },
        builder: (context, state) {
          final portScanState = state is PortScanningState && state.targetIp == _device.ip
              ? state
              : null;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(iconColor, icon),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildIdentityCard(),
                    const SizedBox(height: 12),
                    _buildNetworkCard(),
                    const SizedBox(height: 12),
                    _buildPortsCard(portScanState),
                    const SizedBox(height: 12),
                    if (_device.metadata.isNotEmpty) _buildMetadataCard(),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(Color iconColor, IconData icon) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                iconColor.withOpacity(0.2),
                AppTheme.background,
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: iconColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  _device.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _device.status == DeviceStatus.online
                            ? AppTheme.online
                            : AppTheme.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _device.status == DeviceStatus.online ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: _device.status == DeviceStatus.online
                            ? AppTheme.online
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_device.isGateway) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF7C3AED).withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Gateway',
                          style: TextStyle(
                            color: Color(0xFFA78BFA),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityCard() {
    return _InfoCard(
      title: 'Device Identity',
      icon: Icons.badge_rounded,
      children: [
        _InfoRow(
          label: 'Hostname',
          value: _device.hostname ?? 'Unknown',
          copyable: true,
        ),
        if (_device.vendor != null)
          _InfoRow(label: 'Manufacturer', value: _device.vendor!),
        _InfoRow(label: 'Device Type', value: _device.deviceTypeLabel),
        if (_device.mdnsName != null)
          _InfoRow(label: 'mDNS Name', value: _device.mdnsName!),
        if (_device.ssdpDescription != null)
          _InfoRow(label: 'UPnP Name', value: _device.ssdpDescription!),
        _InfoRow(
          label: 'Last Seen',
          value: _formatDateTime(_device.lastSeen),
        ),
      ],
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildNetworkCard() {
    return _InfoCard(
      title: 'Network',
      icon: Icons.lan_rounded,
      children: [
        _InfoRow(
          label: 'IP Address',
          value: _device.ip,
          highlighted: true,
          copyable: true,
        ),
        if (_device.macAddress != null)
          _InfoRow(
            label: 'MAC Address',
            value: _device.macAddress!,
            copyable: true,
          ),
        if (_device.latency != null)
          _InfoRow(
            label: 'Latency',
            value: '${_device.latency}ms',
            valueColor: _latencyColor(_device.latency!),
          ),
      ],
    ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildPortsCard(PortScanningState? scanState) {
    final isScanning = scanState != null && !scanState.isComplete;
    final ports = scanState?.openPorts ?? _device.openPorts;

    return _InfoCard(
      title: 'Open Ports',
      icon: Icons.electrical_services_rounded,
      trailing: isScanning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.accent),
            )
          : TextButton.icon(
              onPressed: _startPortScan,
              icon: const Icon(Icons.search, size: 16),
              label: Text(ports.isEmpty ? 'Scan Ports' : 'Rescan'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
      children: [
        if (ports.isEmpty && !isScanning)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No open ports detected yet. Tap "Scan Ports" to check.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ports.map((p) => PortChipWidget(port: p)).toList(),
          ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMetadataCard() {
    return _InfoCard(
      title: 'Additional Info',
      icon: Icons.info_outline_rounded,
      children: _device.metadata.entries
          .map((e) => _InfoRow(label: e.key, value: e.value))
          .toList(),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Color _latencyColor(int ms) {
    if (ms < 10) return AppTheme.online;
    if (ms < 50) return const Color(0xFF84CC16);
    if (ms < 100) return AppTheme.warning;
    return AppTheme.error;
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Shared sub-widgets ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.accent, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;
  final bool copyable;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.copyable = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: copyable
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied: $value'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ??
                      (highlighted ? AppTheme.accent : Colors.white),
                  fontSize: 13,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                  fontFamily: highlighted ? 'Courier' : null,
                ),
              ),
            ),
          ),
          if (copyable)
            const Icon(Icons.copy_rounded, size: 14, color: Colors.white24),
        ],
      ),
    );
  }
}
