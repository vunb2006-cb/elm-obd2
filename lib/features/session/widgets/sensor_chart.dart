import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/obd/pid_constants.dart';
import '../../../shared/theme.dart';
import '../session_provider.dart';

/// Seconds visible at 1× zoom while live data is streaming.
const _liveWindowSeconds = 45.0;

// ─── Per-PID normalization ranges ─────────────────────────────────────────────

/// Known expected ranges for each PID name (symbolic, e.g. 'rpm').
/// Values outside these ranges are clamped rather than rejected so the chart
/// stays readable even with unusual sensor data.
const _pidRanges = <String, (double min, double max)>{
  'rpm': (0, 6000),
  'speed': (0, 200),
  'coolant_temp': (-40, 130),
  'iat': (-40, 130),
  'engine_load': (0, 100),
  'throttle': (0, 100),
  'fuel_level': (0, 100),
  'stft_b1': (-30, 30),
  'ltft_b1': (-30, 30),
  'stft_b2': (-30, 30),
  'ltft_b2': (-30, 30),
  'map': (0, 255),
  'fuel_pressure': (0, 800),
  'maf': (0, 200),
  'o2_b1s1': (0, 1.0),
  'o2_b1s2': (0, 1.0),
  'engine_run_time': (0, 3600),
  'distance_mil_on': (0, 65535),
  'egr_commanded': (0, 100),
  'baro_pressure': (60, 110),
  'oil_temp': (-40, 150),
};

double _normalize(String pid, double value) {
  final range = _pidRanges[pid];
  if (range == null) return value.clamp(0, 100);
  final (min, max) = range;
  if (max == min) return 0;
  return ((value - min) / (max - min) * 100).clamp(0, 100);
}

// ─── Chart color palette ───────────────────────────────────────────────────────

const _palette = [
  Color(0xFFE8B84B), // amber — accent
  Color(0xFF4CAF82), // green
  Color(0xFF5B9CF6), // blue
  Color(0xFFCF4747), // red
  Color(0xFFB86BE8), // purple
  Color(0xFFE8724B), // orange
  Color(0xFF4BE8D8), // teal
  Color(0xFFE84BAA), // pink
];

Color _colorForIndex(int i) => _palette[i % _palette.length];

// ─── SensorChart ──────────────────────────────────────────────────────────────

/// Multi-line normalized chart showing selected PIDs over elapsed time.
///
/// The Y axis is normalized 0–100 % of each PID's known range so that sensors
/// with wildly different scales (RPM vs O2 voltage) can be meaningfully
/// overlaid. Tooltips show the raw (un-normalized) value with units.
///
/// Pinch to zoom horizontally and drag to pan (fl_chart 0.70+). While live data
/// streams, the chart keeps a rolling window on the latest readings at 1× zoom.
class SensorChart extends StatefulWidget {
  /// Full time-series history for the current test, keyed by PID name.
  final Map<String, List<ChartPoint>> history;

  /// Which PIDs are currently toggled on.
  final Set<String> selectedPids;

  /// When true, keeps a rolling window on the latest readings at default zoom.
  final bool followLatest;

  const SensorChart({
    super.key,
    required this.history,
    required this.selectedPids,
    this.followLatest = true,
  });

  @override
  State<SensorChart> createState() => _SensorChartState();
}

class _SensorChartState extends State<SensorChart> {
  late final TransformationController _transformController;
  var _isTransformed = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final translation = _transformController.value.getTranslation();
    final transformed = _transformController.value.getMaxScaleOnAxis() > 1.01 ||
        translation.x.abs() > 1.0 ||
        translation.y.abs() > 1.0;
    if (transformed != _isTransformed) {
      setState(() => _isTransformed = transformed);
    }
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  List<String> _activePids() => widget.selectedPids
      .where((p) => (widget.history[p]?.isNotEmpty ?? false))
      .toList();

  double _maxElapsedSeconds(List<String> activePids) {
    var maxX = 10.0;
    for (final pid in activePids) {
      final pts = widget.history[pid]!;
      if (pts.isNotEmpty && pts.last.t > maxX) {
        maxX = pts.last.t.toDouble();
      }
    }
    return maxX;
  }

  (double minX, double maxX) _xRange(double maxElapsed) {
    if (!widget.followLatest || _isTransformed) {
      return (0, maxElapsed);
    }
    if (maxElapsed <= _liveWindowSeconds) {
      return (0, maxElapsed);
    }
    return (maxElapsed - _liveWindowSeconds, maxElapsed);
  }

  @override
  Widget build(BuildContext context) {
    final activePids = _activePids();

    if (activePids.isEmpty) {
      return _empty(context);
    }

    final maxElapsed = _maxElapsedSeconds(activePids);
    final (minX, maxX) = _xRange(maxElapsed);
    final xSpan = math.max(maxX - minX, 1.0);
    final xLabelInterval =
        ((xSpan / 5).ceilToDouble()).clamp(5.0, 60.0).toDouble();

    final bars = <LineChartBarData>[];
    for (var i = 0; i < activePids.length; i++) {
      final pid = activePids[i];
      final pts = widget.history[pid]!;
      final color = _colorForIndex(i);

      bars.add(LineChartBarData(
        spots: pts
            .map((p) => FlSpot(p.t.toDouble(), _normalize(pid, p.v)))
            .toList(),
        color: color,
        barWidth: 2,
        isCurved: true,
        curveSmoothness: 0.2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
    }

    return Stack(
      children: [
        LineChart(
          duration: const Duration(milliseconds: 120),
          transformationConfig: FlTransformationConfig(
            scaleAxis: FlScaleAxis.horizontal,
            minScale: 1.0,
            maxScale: 6.0,
            transformationController: _transformController,
          ),
          LineChartData(
            lineBarsData: bars,
            minY: 0,
            maxY: 100,
            minX: minX,
            maxX: maxX,
            clipData: const FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 25,
              verticalInterval: xLabelInterval,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: Color(0xFF2A2A30),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (_) => const FlLine(
                color: Color(0xFF2A2A30),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: const Color(0xFF2A2A30)),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                axisNameWidget: Text(
                  'normalized %',
                  style: TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 25,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: const Text(
                  'seconds',
                  style: TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: xLabelInterval,
                  getTitlesWidget: (v, _) => Text(
                    '${v.toInt()}s',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF1A1A1F),
                tooltipBorder:
                    const BorderSide(color: Color(0xFF2A2A30)),
                getTooltipItems: (spots) {
                  return List.generate(spots.length, (i) {
                    final spot = spots[i];
                    final pid = activePids[i];
                    final raw = _rawValueAt(pid, spot.x.toInt());
                    final unit = PidConstants.unitFor(
                        PidConstants.codeForName(pid) ?? pid);
                    final label = PidConstants.nameFor(
                        PidConstants.codeForName(pid) ?? pid);
                    return LineTooltipItem(
                      '$label\n${raw.toStringAsFixed(2)} $unit',
                      TextStyle(
                        color: _colorForIndex(i),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ),
        if (_isTransformed)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: _resetTransform,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.fit_screen_outlined,
                    size: 16,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _rawValueAt(String pid, int elapsed) {
    final pts = widget.history[pid];
    if (pts == null || pts.isEmpty) return 0;
    ChartPoint best = pts.first;
    int bestDiff = (best.t - elapsed).abs();
    for (final p in pts) {
      final d = (p.t - elapsed).abs();
      if (d < bestDiff) {
        best = p;
        bestDiff = d;
      }
    }
    return best.v;
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart, color: AppTheme.muted, size: 40),
          const SizedBox(height: 8),
          Text(
            'No data yet — select sensors below',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

// ─── PID selector bar ─────────────────────────────────────────────────────────

/// Horizontal chip row for toggling which PIDs appear on the chart.
///
/// [availablePids] — all PIDs defined for the current test (by name).
/// [vehicleSupportedPidCodes] — hex codes the ECU reported as supported.
///   Chips for unsupported PIDs are shown dimmed so the user knows why they
///   have no data.
/// [selected] / [onToggle] — controlled selection state.
class PidSelectorBar extends StatelessWidget {
  final List<String> availablePids;
  final Set<String> vehicleSupportedPidCodes;
  final Set<String> selected;
  final void Function(String pid, bool isSelected) onToggle;

  const PidSelectorBar({
    super.key,
    required this.availablePids,
    required this.vehicleSupportedPidCodes,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: availablePids.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final pid = availablePids[i];
          final code = PidConstants.codeForName(pid) ?? pid;
          final isSupported = vehicleSupportedPidCodes.isEmpty ||
              vehicleSupportedPidCodes.contains(code.toUpperCase());
          final isSelected = selected.contains(pid);
          final label = _shortName(pid);
          final colorIndex = availablePids.indexOf(pid);
          final chipColor = _colorForIndex(colorIndex);

          return FilterChip(
            label: Text(label, style: const TextStyle(fontSize: 11)),
            selected: isSelected,
            onSelected: isSupported ? (v) => onToggle(pid, v) : null,
            selectedColor: chipColor.withValues(alpha: 0.25),
            checkmarkColor: chipColor,
            side: BorderSide(
              color: isSelected
                  ? chipColor
                  : isSupported
                      ? const Color(0xFF3A3A40)
                      : const Color(0xFF2A2A2A),
            ),
            backgroundColor: const Color(0xFF1A1A1F),
            disabledColor: const Color(0xFF1A1A1F),
            labelStyle: TextStyle(
              color: isSelected
                  ? chipColor
                  : isSupported
                      ? AppTheme.muted
                      : const Color(0xFF3A3A3A),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            visualDensity: VisualDensity.compact,
            tooltip: isSupported ? null : 'Not supported by this vehicle',
          );
        },
      ),
    );
  }

  /// Short display name for a PID chip — truncated at 10 chars.
  String _shortName(String pid) {
    const overrides = {
      'coolant_temp': 'Coolant',
      'stft_b1': 'STFT B1',
      'ltft_b1': 'LTFT B1',
      'stft_b2': 'STFT B2',
      'ltft_b2': 'LTFT B2',
      'engine_load': 'Load',
      'o2_b1s1': 'O2 ↑B1',
      'o2_b1s2': 'O2 ↓B1',
      'iat': 'IAT',
      'throttle': 'TPS',
      'egr_commanded': 'EGR',
      'baro_pressure': 'Baro',
      'oil_temp': 'Oil °C',
      'engine_run_time': 'Run time',
      'distance_mil_on': 'MIL km',
    };
    return overrides[pid] ?? pid.replaceAll('_', ' ');
  }
}
