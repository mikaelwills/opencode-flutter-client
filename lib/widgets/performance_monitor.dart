import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/performance_tracker.dart';

class PerformanceMonitor extends StatefulWidget {
  final bool showInProduction;
  
  const PerformanceMonitor({
    super.key,
    this.showInProduction = false,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  Timer? _updateTimer;
  PerformanceReport _lastReport = const PerformanceReport(
    averageLatency: 0,
    p95Latency: 0,
    maxLatency: 0,
    minLatency: 0,
    averageUpdateFrequency: 0,
    maxUpdateFrequency: 0,
    sampleCount: 0,
  );

  @override
  void initState() {
    super.initState();
    
    // Only show in debug mode unless explicitly enabled for production
    if (kDebugMode || widget.showInProduction) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _lastReport = PerformanceTracker.generateReport();
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show in production unless explicitly enabled
    if (!kDebugMode && !widget.showInProduction) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.speed, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Performance Monitor',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'Samples: ${_lastReport.sampleCount}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildMetricRow('Avg Latency', '${_lastReport.averageLatencyMs.toStringAsFixed(1)}ms', 
                         _getLatencyColor(_lastReport.averageLatencyMs)),
          _buildMetricRow('P95 Latency', '${_lastReport.p95LatencyMs.toStringAsFixed(1)}ms', 
                         _getLatencyColor(_lastReport.p95LatencyMs)),
          _buildMetricRow('Max Latency', '${_lastReport.maxLatencyMs.toStringAsFixed(1)}ms', 
                         _getLatencyColor(_lastReport.maxLatencyMs)),
          _buildMetricRow('Updates/sec', _lastReport.averageUpdateFrequency.toStringAsFixed(1), 
                         _getFrequencyColor(_lastReport.averageUpdateFrequency)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatusIndicator('Target: <5ms', _lastReport.averageLatencyMs < 5),
              const SizedBox(width: 16),
              _buildStatusIndicator('60fps', _lastReport.averageUpdateFrequency <= 60),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isGood) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isGood ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: isGood ? Colors.green : Colors.red,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Color _getLatencyColor(double latencyMs) {
    if (latencyMs < 5) return Colors.green;
    if (latencyMs < 10) return Colors.yellow;
    if (latencyMs < 20) return Colors.orange;
    return Colors.red;
  }

  Color _getFrequencyColor(double frequency) {
    if (frequency <= 60) return Colors.green;
    if (frequency <= 90) return Colors.yellow;
    return Colors.red;
  }
}

// Performance overlay for easy debugging
class PerformanceOverlay extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const PerformanceOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || !kDebugMode) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 10,
          child: const PerformanceMonitor(),
        ),
      ],
    );
  }
}