import 'dart:async';
import 'package:flutter/foundation.dart';

class PerformanceTracker {
  static final Map<String, int> _timestamps = {};
  static final List<int> _latencies = [];
  static final List<int> _updateFrequencies = [];
  static Timer? _frequencyTimer;
  static int _updateCount = 0;
  static int _idleCount = 0;
  
  // Track SSE event received timestamp
  static void markSSEReceived([String? eventId]) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final id = eventId ?? 'default';
    _timestamps[id] = timestamp;
    
    if (kDebugMode) {
      print('📊 [Performance] SSE received: $id at $timestampμs');
    }
  }
  
  // Track UI update timestamp and calculate latency
  static void markUIUpdated([String? eventId]) {
    final currentTime = DateTime.now().microsecondsSinceEpoch;
    final id = eventId ?? 'default';
    
    if (_timestamps.containsKey(id)) {
      final latency = currentTime - _timestamps[id]!;
      _latencies.add(latency);
      _timestamps.remove(id);
      
      if (kDebugMode) {
        print('📊 [Performance] UI updated: $id, Latency: $latencyμs (${(latency / 1000).toStringAsFixed(2)}ms)');
      }
      
      // Keep only last 100 measurements to prevent memory growth
      if (_latencies.length > 100) {
        _latencies.removeAt(0);
      }
    }
  }
  
  // Track update frequency (calls per second)
  static void trackUpdate() {
    _updateCount++;
    
    // Start frequency tracking timer if not already running
    _frequencyTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateFrequencies.add(_updateCount);
      if (kDebugMode && _updateCount > 0) {
        print('📊 [Performance] Updates per second: $_updateCount');
      }
      
      // Stop tracking if no updates for 5 seconds
      if (_updateCount == 0) {
        _idleCount++;
        if (_idleCount >= 5) {
          if (kDebugMode) {
            print('📊 [Performance] Stopping tracking due to inactivity');
          }
          _stopTracking();
        }
      } else {
        _idleCount = 0;
      }
      
      _updateCount = 0;
      
      // Keep only last 60 measurements (1 minute)
      if (_updateFrequencies.length > 60) {
        _updateFrequencies.removeAt(0);
      }
    });
  }
  
  // Get performance statistics
  static PerformanceReport generateReport() {
    if (_latencies.isEmpty) {
      return const PerformanceReport(
        averageLatency: 0,
        p95Latency: 0,
        maxLatency: 0,
        minLatency: 0,
        averageUpdateFrequency: 0,
        maxUpdateFrequency: 0,
        sampleCount: 0,
      );
    }
    
    final sortedLatencies = List<int>.from(_latencies)..sort();
    final p95Index = (sortedLatencies.length * 0.95).floor();
    
    return PerformanceReport(
      averageLatency: _latencies.reduce((a, b) => a + b) / _latencies.length,
      p95Latency: sortedLatencies[p95Index].toDouble(),
      maxLatency: sortedLatencies.last.toDouble(),
      minLatency: sortedLatencies.first.toDouble(),
      averageUpdateFrequency: _updateFrequencies.isEmpty 
          ? 0 
          : _updateFrequencies.reduce((a, b) => a + b) / _updateFrequencies.length,
      maxUpdateFrequency: _updateFrequencies.isEmpty 
          ? 0 
          : _updateFrequencies.reduce((a, b) => a > b ? a : b).toDouble(),
      sampleCount: _latencies.length,
    );
  }
  
  // Stop frequency tracking
  static void _stopTracking() {
    _frequencyTimer?.cancel();
    _frequencyTimer = null;
    _updateCount = 0;
    _idleCount = 0;
  }
  
  // Clear all performance data
  static void reset() {
    _timestamps.clear();
    _latencies.clear();
    _updateFrequencies.clear();
    _updateCount = 0;
    _idleCount = 0;
    _frequencyTimer?.cancel();
    _frequencyTimer = null;
  }
  
  // Dispose resources
  static void dispose() {
    _frequencyTimer?.cancel();
    _frequencyTimer = null;
    _updateCount = 0;
    _idleCount = 0;
    reset();
  }
}

class PerformanceReport {
  final double averageLatency;
  final double p95Latency;
  final double maxLatency;
  final double minLatency;
  final double averageUpdateFrequency;
  final double maxUpdateFrequency;
  final int sampleCount;
  
  const PerformanceReport({
    required this.averageLatency,
    required this.p95Latency,
    required this.maxLatency,
    required this.minLatency,
    required this.averageUpdateFrequency,
    required this.maxUpdateFrequency,
    required this.sampleCount,
  });
  
  // Convert microseconds to milliseconds for display
  double get averageLatencyMs => averageLatency / 1000;
  double get p95LatencyMs => p95Latency / 1000;
  double get maxLatencyMs => maxLatency / 1000;
  double get minLatencyMs => minLatency / 1000;
  
  @override
  String toString() {
    return '''
Performance Report:
  Average Latency: ${averageLatencyMs.toStringAsFixed(2)}ms
  P95 Latency: ${p95LatencyMs.toStringAsFixed(2)}ms
  Max Latency: ${maxLatencyMs.toStringAsFixed(2)}ms
  Min Latency: ${minLatencyMs.toStringAsFixed(2)}ms
  Avg Updates/sec: ${averageUpdateFrequency.toStringAsFixed(1)}
  Max Updates/sec: ${maxUpdateFrequency.toStringAsFixed(1)}
  Sample Count: $sampleCount
''';
  }
}