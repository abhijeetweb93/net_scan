import 'package:flutter/material.dart';
import 'package:wifi_scanner/domain/models/scan_result.dart';
import 'package:wifi_scanner/core/utils/app_theme.dart';

class ScanProgressWidget extends StatelessWidget {
  final ScanProgress progress;
  final VoidCallback onStop;

  const ScanProgressWidget({
    super.key,
    required this.progress,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progress.percentage.clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              _PulseDot(),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Scanning Network',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              _StopButton(onStop: onStop),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar — use LayoutBuilder to get actual width safely
          LayoutBuilder(
            builder: (context, constraints) {
              final maxW = constraints.maxWidth;
              final fillW = (maxW * pct / 100).clamp(0.0, maxW);
              return Stack(
                children: [
                  Container(
                    height: 6,
                    width: maxW,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    width: fillW,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.accent, Color(0xFF0088FF)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: fillW > 0
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _StatBadge(
                label: 'Scanned',
                value: '${progress.scannedCount}/${progress.totalCount}',
                icon: Icons.search_rounded,
              ),
              const SizedBox(width: 8),
              _StatBadge(
                label: 'Found',
                value: '${progress.devicesFound}',
                icon: Icons.devices_rounded,
                highlight: true,
              ),
              const SizedBox(width: 8),
              _StatBadge(
                label: 'Time',
                value: _fmt(progress.elapsed),
                icon: Icons.timer_rounded,
              ),
            ],
          ),

          if (progress.currentIp.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.radar, color: Colors.white24, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    progress.currentIp,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (progress.scannedCount > 0 && progress.elapsed.inSeconds > 0)
                  Text(
                    '~${_estimateRemaining(progress)}s left',
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${pct.toStringAsFixed(0)}%',
            style: const TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _estimateRemaining(ScanProgress p) {
    if (p.scannedCount == 0) return '?';
    final rate = p.scannedCount / p.elapsed.inMilliseconds;
    final remaining = (p.totalCount - p.scannedCount) / rate / 1000;
    return remaining.toStringAsFixed(0);
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    return s < 60 ? '${s}s' : '${d.inMinutes}m${d.inSeconds % 60}s';
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween(begin: 0.7, end: 1.2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppTheme.accent.withOpacity(0.5), blurRadius: 6)
            ],
          ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onStop;
  const _StopButton({required this.onStop});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onStop,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stop_rounded, color: AppTheme.error, size: 14),
            SizedBox(width: 4),
            Text('Stop',
                style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppTheme.online : Colors.white54;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: (highlight ? AppTheme.online : Colors.white)
              .withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: color, fontSize: 10)),
            ]),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: highlight ? AppTheme.online : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
