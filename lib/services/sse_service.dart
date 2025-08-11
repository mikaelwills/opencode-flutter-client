import 'dart:async';
import 'dart:convert';
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import '../config/opencode_config.dart';
import '../models/opencode_event.dart';

class SSEService {
  StreamSubscription? _subscription;
  StreamController<OpenCodeEvent>? _eventController;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;

  SSEService();



  Stream<OpenCodeEvent> connectToEventStream() {
    if (_eventController != null && !_eventController!.isClosed) {
      return _eventController!.stream;
    }

    
    _eventController = StreamController<OpenCodeEvent>.broadcast();
    _connectToSSE();
    return _eventController!.stream;
  }

  void _connectToSSE() {
    _reconnectAttempts++;
    _subscription = SSEClient.subscribeToSSE(
            method: SSERequestType.GET,
            url: '${OpenCodeConfig.baseUrl}${OpenCodeConfig.sseEndpoint}',
            header: {
              "Accept": "text/event-stream",
              "Cache-Control": "no-cache",
            })
        .listen(
      (event) {
        if (!_isConnected) {
          _isConnected = true;
        }
        _reconnectAttempts = 0;
        
        if (event.data != null && event.data!.isNotEmpty) {
          try {
            // PerformanceTracker.markSSEReceived(event.id);
            
            // Fast path for text streaming - bypass full JSON parsing
            final openCodeEvent = _tryFastTextExtraction(event.data!) ?? 
                                  _parseFullEvent(event.data!);
            
            if (openCodeEvent != null) {
              // Only log message.part.updated events content
              if (openCodeEvent.type == 'message.part.updated') {
                final text = openCodeEvent.data?['properties']?['part']?['text'] ?? '';
                print('💬 message.part.updated | ${openCodeEvent.sessionId?.substring(0, 8) ?? 'null'}');
                print('   "${text.toString().length > 50 ? '${text.toString().substring(0, 50)}...' : text}"');
              }
              
              if (_eventController?.isClosed == false) {
                _eventController!.add(openCodeEvent);
              }
            }
          } catch (e) {
            print('❌ [SSEService] Parse error: $e');
            if (_eventController?.isClosed == false) {
              _eventController!.addError(
                FormatException('Failed to parse SSE event data: $e'),
              );
            }
          }
        }
      },
      onError: (error) {
        _isConnected = false;
        if (_eventController?.isClosed == false) {
          _eventController!.addError(error);
        }
        _reconnect();
      },
      onDone: () {
        _isConnected = false;
        _reconnect();
      },
    );
  }

  void _reconnect() {
    if (_eventController == null || _eventController!.isClosed) {
      return;
    }

    _subscription?.cancel();
    _reconnectTimer?.cancel();
    final delay =
        Duration(seconds: (_reconnectAttempts * 2).clamp(2, 30).toInt());

    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        _connectToSSE();
      }
    });
  }

  bool get isConnected => _isConnected;
  
  bool get isActive => _eventController != null && !_eventController!.isClosed;
  
  /// Restart the SSE connection with fresh URL from config
  /// This properly cleans up the old connection and establishes a new one
  void restartConnection() {
    print('🔄 [SSEService] Restarting SSE connection...');
    
    // Clean up existing connection
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    
    // Close existing stream controller if it exists
    if (_eventController != null && !_eventController!.isClosed) {
      _eventController!.close();
    }
    
    // Reset connection state
    _isConnected = false;
    _reconnectAttempts = 0;
    _eventController = null;
    
    print('🔄 [SSEService] Old connection cleaned up, establishing new connection...');
  }

  // Fast path for text streaming - optimized for message.part.updated events
  OpenCodeEvent? _tryFastTextExtraction(String rawData) {
    try {
      // Quick check if this is a text streaming event
      if (!rawData.contains('"type":"message.part.updated"') || 
          !rawData.contains('"text":')) {
        return null; // Not a text streaming event, use full parsing
      }
      
      // Extract key fields using regex for performance
      final typeMatch = RegExp(r'"type":"([^"]+)"').firstMatch(rawData);
      final sessionIdMatch = RegExp(r'"sessionId":"([^"]+)"').firstMatch(rawData);
      final messageIdMatch = RegExp(r'"messageId":"([^"]+)"').firstMatch(rawData);
      
      if (typeMatch == null || sessionIdMatch == null || messageIdMatch == null) {
        return null; // Missing required fields, use full parsing
      }
      
      final type = typeMatch.group(1)!;
      final sessionId = sessionIdMatch.group(1)!;
      final messageId = messageIdMatch.group(1)!;
      
      // Extract text content efficiently
      final textMatch = RegExp(r'"text":"([^"]*(?:\\.[^"]*)*)"').firstMatch(rawData);
      final partIdMatch = RegExp(r'"part":\s*\{[^}]*"id":"([^"]+)"').firstMatch(rawData);
      final partTypeMatch = RegExp(r'"part":\s*\{[^}]*"type":"([^"]+)"').firstMatch(rawData);
      
      if (textMatch != null && partIdMatch != null) {
        final text = textMatch.group(1)?.replaceAll('\\"', '"') ?? '';
        final partId = partIdMatch.group(1)!;
        final partType = partTypeMatch?.group(1) ?? 'text';
        
        // Fast path extraction successful - no logging needed for performance
        
        // Create optimized event data structure
        return OpenCodeEvent(
          type: type,
          sessionId: sessionId,
          messageId: messageId,
          timestamp: DateTime.now(),
          data: {
            'properties': {
              'part': {
                'id': partId,
                'type': partType,
                'text': text,
              }
            }
          },
        );
      }
      
      return null; // Couldn't extract text, use full parsing
    } catch (e) {
      // Fast path failed - silently fall back to full parsing
      return null;
    }
  }
  
  // Full JSON parsing fallback
  OpenCodeEvent? _parseFullEvent(String rawData) {
    try {
      final Map<String, dynamic> eventData = json.decode(rawData);
      return OpenCodeEvent.fromJson(eventData);
    } catch (e) {
      print('❌ [SSEService] Failed to parse event: $e');
      return null;
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _eventController?.close();
    _isConnected = false;
  }
}