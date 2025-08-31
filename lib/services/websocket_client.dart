import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:logging/logging.dart';
import 'tools_service.dart';
import 'session_manager.dart';
import 'ephemeral_token_service.dart';
import '../utils/live_api_config.dart';

/// Message types for Live API WebSocket communication
enum LiveApiMessageType {
  setupMessage,
  realtimeInput,
  serverContent,
  toolCallCancellation,
  interrupt,
}

/// WebSocket client for Google Live API communication
class LiveApiWebSocketClient {
  static final Logger _logger = Logger('LiveApiWebSocketClient');
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = LiveApiConfig.maxReconnectAttempts;
  
  final SessionManager _sessionManager = SessionManager();
  final EphemeralTokenService _tokenService = EphemeralTokenService();
  
  // Configuration for reconnection
  String? _lastApiKey;
  String? _lastModel;
  Map<String, dynamic>? _lastConfig;
  bool _useEphemeralTokens = false;
  
  // Stream controllers for different message types
  final StreamController<Map<String, dynamic>> _serverContentController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioDataController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _connectionStatusController = 
      StreamController<String>.broadcast();
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();
  final StreamController<List<ToolCall>> _toolCallController = 
      StreamController<List<ToolCall>>.broadcast();

  // Public streams
  Stream<Map<String, dynamic>> get serverContentStream => _serverContentController.stream;
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<List<ToolCall>> get toolCallStream => _toolCallController.stream;
  
  // Session management access
  SessionManager get sessionManager => _sessionManager;
  EphemeralTokenService get tokenService => _tokenService;
  
  bool get isConnected => _isConnected;

  /// Connect to Google Live API WebSocket
  Future<bool> connect({
    required String apiKey,
    required String model,
    Map<String, dynamic>? config,
    bool useEphemeralTokens = false,
    bool enableSessionManagement = true,
  }) async {
    try {
      // Store connection parameters for reconnection
      _lastApiKey = apiKey;
      _lastModel = model;
      _lastConfig = config;
      _useEphemeralTokens = useEphemeralTokens;
      
      _logger.info('Connecting to Live API WebSocket...');
      
      // Initialize session management if enabled
      if (enableSessionManagement) {
        _sessionManager.initialize(
          enableSessionResumption: true,
          compressionConfig: ContextWindowCompressionConfig(
            enabled: true,
            triggerTokens: 25000,
          ),
        );
      }
      
      String authToken = apiKey;
      
      // Use ephemeral token if requested
      if (_useEphemeralTokens) {
        final ephemeralToken = await _tokenService.createClientToken(
          apiKey: apiKey,
          model: model,
          sessionDuration: const Duration(minutes: 30),
        );
        
        if (ephemeralToken != null) {
          authToken = ephemeralToken.name;
          _logger.info('Using ephemeral token for connection');
        } else {
          _logger.warning('Failed to create ephemeral token, falling back to API key');
        }
      }
      
      // Construct WebSocket URL for Live API
      final uri = Uri.parse(LiveApiConfig.websocketEndpoint)
          .replace(queryParameters: {
        _useEphemeralTokens ? 'access_token' : 'key': authToken,
      });

      _logger.info('Connecting to: ${uri.toString().replaceAll(authToken, '***')}');
      
      // Create WebSocket connection with custom headers and timeout
      _channel = WebSocketChannel.connect(
        uri,
        protocols: ['genai-live'],
      );
      
      // Wait for connection with extended timeout for better stability
      await _channel!.ready.timeout(
        LiveApiConfig.connectionTimeout,
        onTimeout: () {
          throw TimeoutException('Connection timeout after ${LiveApiConfig.connectionTimeout.inSeconds} seconds', LiveApiConfig.connectionTimeout);
        },
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStatusController.add('connected');
      
      _logger.info('WebSocket connected successfully');

      // Set up message listener
      _setupMessageListener();
      
      // Send initial setup message with session management
      await _sendSetupMessage(model: model, config: config, enableSessionManagement: enableSessionManagement);
      
      // Start session if management is enabled
      if (enableSessionManagement) {
        _sessionManager.startSession();
      }
      
      // Start heartbeat to keep connection alive (reduced frequency for stability)
      _startHeartbeat();
      
      return true;
    } catch (e) {
      _logger.severe('Failed to connect to WebSocket: $e');
      _isConnected = false;
      _connectionStatusController.add('disconnected');
      _errorController.add('Connection failed: $e');
      return false;
    }
  }

  /// Set up message listener for incoming WebSocket messages
  void _setupMessageListener() {
    _channel?.stream.listen(
      (message) {
        try {
          _handleIncomingMessage(message);
        } catch (e) {
          _logger.severe('Error handling incoming message: $e');
          _errorController.add('Message handling error: $e');
        }
      },
      onError: (error) {
        _logger.severe('WebSocket stream error: $error');
        _isConnected = false;
        _stopHeartbeat();
        _connectionStatusController.add('error');
        _errorController.add('WebSocket error: $error');
        
        // Wait a bit before attempting reconnection to avoid rapid retry loops
        Future.delayed(const Duration(seconds: 1), () {
          _attemptReconnection();
        });
      },
      onDone: () {
        _logger.info('WebSocket connection closed');
        _isConnected = false;
        _stopHeartbeat();
        _connectionStatusController.add('disconnected');
        
        // Only attempt reconnection if we haven't hit the max attempts
        // and the disconnection wasn't intentional
        if (_reconnectAttempts < maxReconnectAttempts) {
          Future.delayed(const Duration(seconds: 2), () {
            _attemptReconnection();
          });
        } else {
          _connectionStatusController.add('failed');
        }
      },
    );
  }

  /// Handle incoming WebSocket messages
  void _handleIncomingMessage(dynamic message) {
    try {
      if (message is String) {
        // Text message (JSON)
        final data = jsonDecode(message) as Map<String, dynamic>;
        _handleJsonMessage(data);
      } else if (message is List<int>) {
        // Binary message (audio data)
        final audioData = Uint8List.fromList(message);
        _audioDataController.add(audioData);
        _logger.fine('Received audio data: ${audioData.length} bytes');
      } else {
        _logger.warning('Unknown message type received: ${message.runtimeType}');
      }
    } catch (e) {
      _logger.severe('Error parsing incoming message: $e');
      _errorController.add('Message parsing error: $e');
    }
  }

  /// Handle JSON messages from the server
  void _handleJsonMessage(Map<String, dynamic> data) {
    _logger.fine('Received JSON message: ${data.keys}');
    
    // Process session management messages first
    _sessionManager.processServerMessage(data);
    
    // Check for server content
    if (data.containsKey('serverContent')) {
      _serverContentController.add(data);
      
      // Extract audio data if present
      final serverContent = data['serverContent'] as Map<String, dynamic>?;
      if (serverContent != null) {
        _extractAudioFromServerContent(serverContent);
      }
    }
    
    // Check for tool calls
    if (data.containsKey('toolCall')) {
      _handleToolCall(data);
    }
    
    // Handle other message types as needed
    if (data.containsKey('error')) {
      final error = data['error'];
      _logger.warning('Server error: $error');
      _errorController.add('Server error: $error');
    }
  }

  /// Extract audio data from server content
  void _extractAudioFromServerContent(Map<String, dynamic> serverContent) {
    try {
      final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
      if (modelTurn == null) return;

      final parts = modelTurn['parts'] as List<dynamic>?;
      if (parts == null) return;

      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          final inlineData = part['inlineData'] as Map<String, dynamic>?;
          if (inlineData != null) {
            final mimeType = inlineData['mimeType'] as String?;
            final data = inlineData['data'] as String?;
            
            if (mimeType?.contains('audio') == true && data != null) {
              // Decode base64 audio data
              final audioBytes = base64Decode(data);
              _audioDataController.add(audioBytes);
              _logger.info('Extracted audio data: ${audioBytes.length} bytes');
            }
          }
        }
      }
    } catch (e) {
      _logger.warning('Error extracting audio from server content: $e');
    }
  }

  /// Handle tool calls from the server
  void _handleToolCall(Map<String, dynamic> data) {
    try {
      final toolCall = data['toolCall'] as Map<String, dynamic>?;
      if (toolCall == null) return;

      final functionCalls = toolCall['functionCalls'] as List<dynamic>?;
      if (functionCalls == null) return;

      final toolCalls = functionCalls
          .cast<Map<String, dynamic>>()
          .map((fc) => ToolCall(
                id: fc['id'] as String,
                name: fc['name'] as String,
                args: fc['args'] as Map<String, dynamic>? ?? {},
              ))
          .toList();

      _toolCallController.add(toolCalls);
      _logger.info('Tool calls received: ${toolCalls.map((tc) => tc.name).join(', ')}');
    } catch (e) {
      _logger.severe('Error handling tool call: $e');
      _errorController.add('Tool call error: $e');
    }
  }

  /// Send setup message to initialize the session
  Future<void> _sendSetupMessage({
    required String model,
    Map<String, dynamic>? config,
    bool enableSessionManagement = true,
  }) async {
    final setupMessage = {
      'setup': {
        'model': 'models/$model',
        'generationConfig': {
          'responseModalities': config?['response_modalities'] ?? ['AUDIO'],
          if (config?['response_modalities']?.contains('AUDIO') == true)
            'speechConfig': {
              'voiceConfig': {
                'prebuiltVoiceConfig': {
                  'voiceName': model.contains('native-audio') ? 'Aoede' : 'Puck'
                }
              }
            },
        },
        if (config?['system_instruction'] != null)
          'systemInstruction': {
            'parts': [{
              'text': config!['system_instruction']
            }]
          },
        // Add tools if specified in config
        if (config?['tools'] != null)
          'tools': config!['tools'],
      },
    };
    
    // Add session management configuration
    if (enableSessionManagement) {
      final sessionConfig = _sessionManager.getSessionConfig();
      setupMessage['setup']!.addAll(sessionConfig);
    }

    await _sendMessage(setupMessage);
    _logger.info('Setup message sent with model: models/$model');
    
    if (enableSessionManagement) {
      final sessionConfigKeys = _sessionManager.getSessionConfig().keys;
      _logger.info('Session management enabled with config: $sessionConfigKeys');
    }
  }

  /// Send audio data to the Live API
  Future<void> sendAudio(Uint8List audioData) async {
    if (!_isConnected) {
      _logger.warning('Cannot send audio: not connected');
      return;
    }

    try {
      // Convert audio data to base64
      final base64Audio = base64Encode(audioData);
      
      final message = {
        'realtimeInput': {
          'audio': {
            'data': base64Audio,
            'mimeType': 'audio/pcm;rate=16000'
          }
        }
      };

      await _sendMessage(message);
      _logger.info('Audio data sent: ${audioData.length} bytes');
    } catch (e) {
      _logger.severe('Error sending audio data: $e');
      _errorController.add('Failed to send audio: $e');
    }
  }

  /// Send text input to the Live API
  Future<void> sendText(String text) async {
    if (!_isConnected) {
      _logger.warning('Cannot send text: not connected');
      return;
    }

    try {
      final message = {
        'clientContent': {
          'turns': [{
            'role': 'user',
            'parts': [{
              'text': text
            }]
          }],
          'turnComplete': true
        }
      };

      await _sendMessage(message);
      _logger.info('Text message sent: $text');
    } catch (e) {
      _logger.severe('Error sending text: $e');
      _errorController.add('Failed to send text: $e');
    }
  }

  /// Send interrupt signal to stop current generation
  Future<void> sendInterrupt() async {
    if (!_isConnected) {
      _logger.warning('Cannot send interrupt: not connected');
      return;
    }

    try {
      final message = {
        'interrupt': {
          'action': 'STOP_GENERATION'
        }
      };
      await _sendMessage(message);
      _logger.info('Interrupt signal sent');
    } catch (e) {
      _logger.severe('Error sending interrupt: $e');
      _errorController.add('Failed to send interrupt: $e');
    }
  }

  /// Send tool response back to the Live API
  Future<void> sendToolResponse(List<FunctionResponse> functionResponses) async {
    if (!_isConnected) {
      _logger.warning('Cannot send tool response: not connected');
      return;
    }

    try {
      final message = {
        'toolResponse': {
          'functionResponses': functionResponses.map((fr) => fr.toJson()).toList(),
        }
      };

      await _sendMessage(message);
      _logger.info('Tool response sent for ${functionResponses.length} function(s)');
    } catch (e) {
      _logger.severe('Error sending tool response: $e');
      _errorController.add('Failed to send tool response: $e');
    }
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _stopHeartbeat();
    // Use configured heartbeat interval for better stability
    _heartbeatTimer = Timer.periodic(LiveApiConfig.heartbeatInterval, (timer) {
      if (_isConnected && _channel != null) {
        try {
          // Send a lightweight keepalive message
          final keepAlive = {'keepAlive': DateTime.now().millisecondsSinceEpoch};
          _channel!.sink.add(jsonEncode(keepAlive));
          _logger.fine('Keepalive sent');
        } catch (e) {
          _logger.warning('Failed to send keepalive: $e');
          timer.cancel();
          // Don't immediately reconnect on heartbeat failure
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop heartbeat timer
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Attempt to reconnect if connection is lost
  Future<void> _attemptReconnection() async {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      _logger.warning('Maximum reconnection attempts reached');
      _connectionStatusController.add('failed');
      return;
    }

    _reconnectAttempts++;
    
    // Use configured retry delay with exponential backoff
    final delay = LiveApiConfig.getRetryDelay(_reconnectAttempts);
    _logger.info('Attempting reconnection ($_reconnectAttempts/$maxReconnectAttempts) in ${delay.inSeconds}s...');
    
    // Wait before reconnecting with configured backoff
    await Future.delayed(delay);
    
    // Only attempt reconnection if we're not already connected
    if (!_isConnected && _lastApiKey != null && _lastModel != null) {
      try {
        final success = await connect(
          apiKey: _lastApiKey!,
          model: _lastModel!,
          config: _lastConfig,
        );
        
        if (success) {
          _logger.info('Reconnection successful');
        } else {
          _logger.warning('Reconnection failed, will retry if attempts remain');
          // Only retry if we haven't reached max attempts
          if (_reconnectAttempts < maxReconnectAttempts) {
            _attemptReconnection();
          }
        }
      } catch (e) {
        _logger.severe('Reconnection error: $e');
        if (_reconnectAttempts < maxReconnectAttempts) {
          _attemptReconnection();
        }
      }
    }
  }

  /// Send a JSON message through the WebSocket
  Future<void> _sendMessage(Map<String, dynamic> message) async {
    if (!_isConnected || _channel == null) {
      throw Exception('WebSocket not connected');
    }

    final jsonMessage = jsonEncode(message);
    _channel!.sink.add(jsonMessage);
    _logger.fine('Message sent: ${message.keys}');
  }

  /// Update session configuration
  Future<void> updateConfig(Map<String, dynamic> config) async {
    if (!_isConnected) {
      _logger.warning('Cannot update config: not connected');
      return;
    }

    try {
      final message = {
        'setup': config,
      };

      await _sendMessage(message);
      _logger.info('Configuration updated');
    } catch (e) {
      _logger.severe('Error updating config: $e');
      _errorController.add('Failed to update config: $e');
    }
  }

  /// Disconnect from the WebSocket
  Future<void> disconnect() async {
    try {
      _reconnectAttempts = maxReconnectAttempts; // Prevent reconnection
      _stopHeartbeat();
      
      // End session if active
      if (_sessionManager.isSessionActive) {
        _sessionManager.endSession();
      }
      
      if (_isConnected && _channel != null) {
        await _channel!.sink.close(status.goingAway);
        _logger.info('WebSocket disconnected');
      }
      
      _isConnected = false;
      _connectionStatusController.add('disconnected');
    } catch (e) {
      _logger.severe('Error disconnecting WebSocket: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await disconnect();
    _stopHeartbeat();
    
    // Clean up session management
    _sessionManager.dispose();
    _tokenService.dispose();
    
    await _serverContentController.close();
    await _audioDataController.close();
    await _connectionStatusController.close();
    await _errorController.close();
    await _toolCallController.close();
    
    _logger.info('LiveApiWebSocketClient disposed');
  }
}