import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_bloc.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_event.dart';
import 'package:wifi_scanner/presentation/bloc/scanner_state.dart';
import 'package:wifi_scanner/presentation/viewmodels/scan_screen_viewmodel.dart';
import 'package:wifi_scanner/presentation/ui/widgets/scan_progress_widget.dart';
import 'package:wifi_scanner/presentation/ui/widgets/device_list_widget.dart';
import 'package:wifi_scanner/presentation/ui/widgets/network_info_card.dart';
import 'package:wifi_scanner/presentation/ui/widgets/scan_button.dart';
import 'package:wifi_scanner/presentation/ui/widgets/empty_state_widget.dart';
import 'package:wifi_scanner/presentation/ui/widgets/device_stats_widget.dart';
import 'package:wifi_scanner/presentation/ui/screens/device_detail_screen.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';
import 'package:wifi_scanner/domain/models/network_device.dart';
import 'package:wifi_scanner/domain/repositories/scanner_repository.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScannerBloc>().add(const InitializeScanner());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: _handleStateChanges,
        builder: (context, state) {
          final vm = ScanScreenViewModel(state);
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ScannerBloc>().add(const RefreshNetwork());
              await Future.delayed(const Duration(milliseconds: 300));
            },
            color: AppTheme.accent,
            backgroundColor: AppTheme.cardBg,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              slivers: [
                _buildAppBar(vm),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (vm.networkInfo != null) ...[
                        NetworkInfoCard(networkInfo: vm.networkInfo!)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0),
                        const SizedBox(height: 16),
                      ],
                      if (vm.isScanning)
                        ScanProgressWidget(
                          progress: vm.progress!,
                          onStop: () =>
                              context.read<ScannerBloc>().add(const StopScan()),
                        )
                      else
                        ScanButton(
                          state: state,
                          onScan: () =>
                              context.read<ScannerBloc>().add(const StartScan()),
                          onRefresh: () =>
                              context.read<ScannerBloc>().add(const RefreshNetwork()),
                        ),
                      const SizedBox(height: 20),
                      if (vm.isComplete && vm.devices.isNotEmpty) ...[
                        DeviceStatsWidget(
                          devices: vm.devices,
                          scanDuration: vm.lastResult?.scanDuration,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (vm.devices.isNotEmpty || vm.isScanning) ...[
                        _buildDeviceHeader(vm),
                        const SizedBox(height: 10),
                      ],
                      if (vm.isInitializing)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(
                                color: AppTheme.accent, strokeWidth: 2),
                          ),
                        )
                      else if (vm.devices.isEmpty && !vm.isScanning)
                        const EmptyStateWidget()
                      else
                        DeviceListWidget(
                          devices: vm.sortedDevices,
                          onDeviceTap: _openDeviceDetail,
                          isScanning: vm.isScanning,
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(ScanScreenViewModel vm) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      stretch: true,
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(16, 0, 70, 16),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: const Icon(Icons.wifi_tethering, color: AppTheme.accent, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('NetScan',
                style: TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ],
        ),
        background: Container(color: AppTheme.background),
      ),
      actions: [
        IconButton(
          onPressed: () => _showSettingsSheet(context),
          icon: const Icon(Icons.tune_rounded, color: Colors.white70),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildDeviceHeader(ScanScreenViewModel vm) {
    return Row(
      children: [
        Text(
          vm.isScanning ? 'Discovering Devices' : 'Devices on Network',
          style: const TextStyle(color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        const Spacer(),
        if (vm.devices.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.online.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.online.withOpacity(0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (vm.isScanning)
                const SizedBox(width: 8, height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.online))
              else
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppTheme.online, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${vm.devices.length}',
                  style: const TextStyle(color: AppTheme.online, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    );
  }

  void _handleStateChanges(BuildContext context, ScannerState state) {
    if (state is ScannerError) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(state.message)),
        ]),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
    if (state is ScannerCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('${state.result.devices.length} devices in ${state.result.scanDuration.inSeconds}s'),
        ]),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
    }
  }

  void _openDeviceDetail(NetworkDevice device) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, _) => BlocProvider.value(
        value: context.read<ScannerBloc>(),
        child: DeviceDetailScreen(device: device),
      ),
      transitionsBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => BlocProvider.value(
        value: context.read<ScannerBloc>(),
        child: const _ScanOptionsSheet(),
      ),
    );
  }
}

class _ScanOptionsSheet extends StatefulWidget {
  const _ScanOptionsSheet();
  @override
  State<_ScanOptionsSheet> createState() => _ScanOptionsSheetState();
}

class _ScanOptionsSheetState extends State<_ScanOptionsSheet> {
  bool _enablePortScan = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Scan Options', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Deep Port Scan', style: TextStyle(color: Colors.white, fontSize: 14)),
              Text('Detect open services (slower)', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ])),
            Switch(value: _enablePortScan, onChanged: (v) => setState(() => _enablePortScan = v),
                activeThumbColor: AppTheme.warning),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<ScannerBloc>().add(StartScan(
                    options: ScanOptions(enablePortScan: _enablePortScan)));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent, foregroundColor: AppTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Start Scan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
