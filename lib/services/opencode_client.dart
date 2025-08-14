import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/opencode_config.dart';
import '../models/session.dart';
import '../models/opencode_message.dart';
import '../models/provider.dart';

class OpenCodeClient {
  final http.Client _client = http.Client();
  String? _providerID;
  String? _modelID;

  String? get providerID => _providerID;
  String? get modelID => _modelID;
  String get modelDisplayName {
    if (_modelID == null || _providerID == null) {
      return 'Unknown Model';
    }
    
    // Format provider name (e.g., "anthropic" -> "Anthropic")
    String formattedProvider = _providerID!.split('-').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
    
    // Format model name (e.g., "claude-3-5-sonnet-20241022" -> "Claude Sonnet 4")
    String formattedModel = _formatModelName(_modelID!);
    
    return '$formattedProvider $formattedModel';
  }
  
  String _formatModelName(String modelId) {
    // Remove date patterns (numbers with 8+ digits)
    String cleaned = modelId.replaceAll(RegExp(r'-?\d{8,}'), '');
    
    // Handle specific model patterns
    if (cleaned.contains('claude')) {
      // Extract version numbers and model type
      final parts = cleaned.split('-');
      String result = 'Claude';
      
      // Look for version numbers and model type
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        if (part == 'claude') continue;
        
        // Handle version numbers (3, 5, etc.)
        if (RegExp(r'^\d+$').hasMatch(part)) {
          // Skip adding version numbers for now, we'll handle them specially
          continue;
        }
        
        // Handle model types
        if (part == 'sonnet' || part == 'haiku' || part == 'opus') {
          result += ' ${part[0].toUpperCase()}${part.substring(1)}';
        }
      }
      
      // Add version number at the end (extract the highest single digit)
      final versionMatch = RegExp(r'-(\d+)-').firstMatch(modelId);
      if (versionMatch != null) {
        final version = versionMatch.group(1);
        if (version != null && version.length == 1) {
          result += ' $version';
        }
      }
      
      return result;
    }
    
    // Default formatting for other models
    return cleaned
        .split('-')
        .where((part) => part.isNotEmpty && !RegExp(r'^\d+$').hasMatch(part))
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  Future<void> getProviders() async {
    print('🔍 [Connection] Connecting to ${OpenCodeConfig.baseUrl}...');

    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/config');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? modelString = data['model'];
        if (modelString != null && modelString.contains('/')) {
          final parts = modelString.split('/');
          _providerID = parts[0];
          _modelID = parts[1];
          print('✅ [Connection] Connected to ${OpenCodeConfig.baseUrl} - Provider: $_providerID');
        } else {
          throw Exception('Invalid model format in config: $modelString');
        }
      } else {
        print('❌ [Connection] Failed to connect to ${OpenCodeConfig.baseUrl} - Status: ${response.statusCode}');
        throw Exception('Failed to get providers: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [Connection] Failed to connect to ${OpenCodeConfig.baseUrl} - Error: $e');
      
      if (e.toString().contains('No route to host') || e.toString().contains('Connection failed')) {
        throw Exception('Cannot connect to OpenCode server at ${OpenCodeConfig.baseUrl}. Please check:\n'
            '1. Tailscale is running and connected\n'
            '2. OpenCode server is running at ${OpenCodeConfig.baseUrl}\n'
            '3. Network connectivity is available');
      }
      
      throw Exception('Failed to get providers: $e');
    }
  }

  Future<bool> ping() async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/config');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ [Connection] Ping failed: $e');
      return false;
    }
  }

  Future<List<Session>> getSessions() async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final sessions = data.map((json) => Session.fromJson(json)).toList();
        print('✅ [OpenCodeClient] Loaded ${sessions.length} sessions');
        return sessions;
      } else {
        print('❌ [OpenCodeClient] Failed to load sessions: ${response.statusCode}');
        throw Exception('Failed to load sessions: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Get sessions failed with error: $e');
      rethrow;
    }
  }

  Future<Session> createSession() async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session');
      final requestBody = json.encode({});

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final sessionData = json.decode(response.body);
        final session = Session.fromJson(sessionData);
        print('✅ [OpenCodeClient] Created session: ${session.id}');
        return session;
      } else {
        print('❌ [OpenCodeClient] Failed to create session: ${response.statusCode}');
        throw Exception('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Create session failed with error: $e');
      rethrow;
    }
  }

  Future<OpenCodeMessage> sendMessage(String sessionId, String message) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/message');
      final requestBody = json.encode({
        'providerID': _providerID,
        'modelID': _modelID,
        'parts': [
          {'type': 'text', 'text': message}
        ]
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final messageData = json.decode(response.body);

        if (messageData.containsKey('name') && messageData.containsKey('data')) {
          final errorName = messageData['name'];
          final errorMessage = messageData['data']['message'];
          print('❌ [OpenCodeClient] Server returned error in 200 response: $errorName');
          throw Exception('Failed to send message: $errorName - $errorMessage');
        }

        final openCodeMessage = OpenCodeMessage.fromApiResponse(messageData);
        // Only log if there's actual content to show
        if (openCodeMessage.content.isNotEmpty) {
          print('✅ [OpenCodeClient] Received response: ${openCodeMessage.content.substring(0, openCodeMessage.content.length > 100 ? 100 : openCodeMessage.content.length)}${openCodeMessage.content.length > 100 ? "..." : ""}');
        }
        return openCodeMessage;
      } else {
        print('❌ [OpenCodeClient] Failed to send message: ${response.statusCode}');
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Send message failed with error: $e');
      rethrow;
    }
  }

  Future<void> abortSession(String sessionId) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/abort');
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        print('✅ [OpenCodeClient] Aborted session $sessionId');
      } else {
        print('❌ [OpenCodeClient] Failed to abort session: ${response.statusCode}');
        throw Exception('Failed to abort session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Abort session failed with error: $e');
      rethrow;
    }
  }


  Future<void> deleteSession(String sessionId) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId');
      final response = await _client.delete(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ [OpenCodeClient] Deleted session $sessionId');
      } else {
        print('❌ [OpenCodeClient] Failed to delete session: ${response.statusCode}');
        throw Exception('Failed to delete session: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Delete session failed with error: $e');
      rethrow;
    }
  }

  Future<String> generateSessionSummary(String sessionId) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/summarize');

      final requestBody = json.encode({
        'providerID': _providerID,
        'modelID': _modelID,
      });

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          
          // The server returns 'true' to indicate summary was initiated via SSE
          // Since we can't easily capture the SSE stream here, use a fallback
          if (responseData == true || 
              (responseData is Map && responseData.containsKey('success'))) {
            return 'Session ${sessionId.substring(0, 8)}...';
          }
          
          // Try different possible response formats
          String summary;
          if (responseData is String) {
            summary = responseData;
          } else if (responseData is Map) {
            summary = responseData['summary'] ?? 
                     responseData['description'] ?? 
                     responseData['text'] ?? 
                     responseData['content'] ?? 
                     responseData['message'] ?? 
                     'No summary available';
          } else {
            // Don't convert boolean true to string "true"
            summary = 'Session ${sessionId.substring(0, 8)}...';
          }
          
          return summary;
        } catch (e) {
          print('❌ [OpenCodeClient] Failed to parse summary response: $e');
          return 'Session ${sessionId.substring(0, 8)}...';
        }
      } else {
        // Only log errors, not the common cases
        if (response.statusCode == 404) {
          return 'Session ${sessionId.substring(0, 8)}...';
        } else if (response.statusCode == 405) {
          return await _tryGetSummary(sessionId);
        } else if (response.statusCode == 400) {
          return await _tryAlternativeSummaryFormats(sessionId);
        }
        
        print('❌ [OpenCodeClient] Failed to generate summary: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to generate summary: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Generate summary failed with error: $e');
      rethrow;
    }
  }

  Future<String> _tryGetSummary(String sessionId) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/summary');
      final response = await _client.get(uri, headers: {'Accept': 'application/json'});
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['summary'] ?? responseData.toString();
      }
    } catch (e) {
      // Silent failure, fallback to default
    }
    
    return 'Session ${sessionId.substring(0, 8)}...';
  }

  Future<String> _tryAlternativeSummaryFormats(String sessionId) async {
    // Try different request body formats
    final alternatives = [
      {
        'providerID': _providerID,
        'modelID': _modelID,
        'sessionId': sessionId,
      },
      {
        'providerID': _providerID,
        'modelID': _modelID,
        'session_id': sessionId,
      },
      {
        'providerID': _providerID,
        'modelID': _modelID,
      },
    ];

    for (final body in alternatives) {
      try {
        final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/summarize');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          return responseData['summary'] ?? responseData.toString();
        }
      } catch (e) {
        // Silent failure, try next alternative
        continue;
      }
    }
    
    return 'Session ${sessionId.substring(0, 8)}...';
  }

  Future<List<OpenCodeMessage>> getSessionMessages(String sessionId, {int limit = 100}) async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/session/$sessionId/message?limit=$limit');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final messages = data.map((json) => OpenCodeMessage.fromApiResponse(json)).toList();
        print('✅ [OpenCodeClient] Loaded ${messages.length} messages');
        return messages;
      } else {
        print('❌ [OpenCodeClient] Failed to load messages: ${response.statusCode}');
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Get messages failed with error: $e');
      rethrow;
    }
  }

  Future<ProvidersResponse> getAvailableProviders() async {
    try {
      final uri = Uri.parse('${OpenCodeConfig.baseUrl}/config/providers');
      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final providersResponse = ProvidersResponse.fromJson(data);
        print('✅ [OpenCodeClient] Loaded ${providersResponse.providers.length} providers');
        return providersResponse;
      } else {
        print('❌ [OpenCodeClient] Failed to get providers: ${response.statusCode}');
        throw Exception('Failed to get providers: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [OpenCodeClient] Get providers failed with error: $e');
      rethrow;
    }
  }

  void setProvider(String providerID, String modelID) {
    _providerID = providerID;
    _modelID = modelID;
    print('✅ [OpenCodeClient] Provider updated: $providerID/$modelID');
  }

  void dispose() {
    _client.close();
  }
}

