import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import 'audio_service.dart';
import 'websocket_client.dart';
import 'tools_service.dart';
import 'session_manager.dart';
import 'ephemeral_token_service.dart';
import '../utils/live_api_config.dart';

/// Conversation message model
class ConversationMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;

  ConversationMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
    this.status = MessageStatus.complete,
  });

  ConversationMessage copyWith({
    String? id,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return ConversationMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }
}

enum MessageType {
  user,
  assistant,
  system,
}

enum MessageStatus {
  sending,
  complete,
  error,
}

/// Assistant state enum
enum AssistantState {
  idle,
  connecting,
  connected,
  listening,
  processing,
  speaking,
  error,
}

/// Main service for Google Live API integration
class LiveApiService {
  static final Logger _logger = Logger('LiveApiService');
  static final LiveApiService _instance = LiveApiService._internal();
  factory LiveApiService() => _instance;
  LiveApiService._internal();

  final AudioService _audioService = AudioService();
  final LiveApiWebSocketClient _webSocketClient = LiveApiWebSocketClient();
  final ToolsService _toolsService = ToolsService();

  // State management
  AssistantState _currentState = AssistantState.idle;
  final StreamController<AssistantState> _stateController = 
      StreamController<AssistantState>.broadcast();
  
  // Conversation management
  final List<ConversationMessage> _conversationHistory = [];
  final StreamController<List<ConversationMessage>> _conversationController = 
      StreamController<List<ConversationMessage>>.broadcast();

  // Error handling
  final StreamController<String> _errorController = 
      StreamController<String>.broadcast();

  // Configuration
  String? _apiKey;
  String _model = 'gemini-2.5-flash-preview-native-audio-dialog';
  Map<String, dynamic> _config = {
    'response_modalities': ['AUDIO'],
    'system_instruction': 'You are MoonTalk, a helpful virtual assistant. Respond in a friendly and conversational tone.',
  };
  bool _useEphemeralTokens = false;
  bool _enableSessionManagement = true;

  // Streams
  Stream<AssistantState> get stateStream => _stateController.stream;
  Stream<List<ConversationMessage>> get conversationStream => _conversationController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters
  AssistantState get currentState => _currentState;
  List<ConversationMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  bool get isConnected => _webSocketClient.isConnected;
  bool get useEphemeralTokens => _useEphemeralTokens;
  bool get enableSessionManagement => _enableSessionManagement;
  
  // Session management access
  SessionManager get sessionManager => _webSocketClient.sessionManager;
  EphemeralTokenService get tokenService => _webSocketClient.tokenService;

  /// Initialize the Live API service
  Future<bool> initialize({
    required String apiKey,
    String? model,
    Map<String, dynamic>? config,
  }) async {
    try {
      _logger.info('Initializing LiveApiService...');
      
      _apiKey = apiKey;
      if (model != null) _model = model;
      if (config != null) _config = {..._config, ...config};

      // Initialize tools service
      _toolsService.initialize();

      // Add tools to config if not already specified
      if (_config['tools'] == null) {
        _config['tools'] = _toolsService.getToolsConfig();
      }

      // Initialize audio service
      final audioInitialized = await _audioService.initialize();
      if (!audioInitialized) {
        _setError('Failed to initialize audio service');
        return false;
      }

      // Set up WebSocket listeners
      _setupWebSocketListeners();

      _setState(AssistantState.idle);
      _logger.info('LiveApiService initialized successfully');
      return true;
    } catch (e) {
      _logger.severe('Failed to initialize LiveApiService: $e');
      _setError('Initialization failed: $e');
      return false;
    }
  }

  /// Connect to the Live API
  Future<bool> connect({
    bool useEphemeralTokens = false,
    bool enableSessionManagement = true,
  }) async {
    if (_apiKey == null) {
      _setError('API key not provided');
      return false;
    }

    try {
      _setState(AssistantState.connecting);
      
      _useEphemeralTokens = useEphemeralTokens;
      _enableSessionManagement = enableSessionManagement;
      
      final connected = await _webSocketClient.connect(
        apiKey: _apiKey!,
        model: _model,
        config: _config,
        useEphemeralTokens: useEphemeralTokens,
        enableSessionManagement: enableSessionManagement,
      );

      if (connected) {
        _setState(AssistantState.connected);
        _logger.info('Successfully connected to Live API');
        
        if (enableSessionManagement) {
          _setupSessionListeners();
        }
        
        return true;
      } else {
        _setState(AssistantState.error);
        _setError('Failed to connect to Live API');
        return false;
      }
    } catch (e) {
      _logger.severe('Connection error: $e');
      _setState(AssistantState.error);
      _setError('Connection error: $e');
      return false;
    }
  }

  /// Start voice conversation (start recording)
  Future<bool> startVoiceInput() async {
    if (!_webSocketClient.isConnected) {
      _setError('Not connected to Live API');
      return false;
    }

    if (_currentState == AssistantState.listening) {
      _logger.warning('Already listening');
      return true;
    }

    try {
      _setState(AssistantState.listening);
      
      final recordingStarted = await _audioService.startRecording();
      if (!recordingStarted) {
        _setState(AssistantState.connected);
        _setError('Failed to start recording');
        return false;
      }

      _logger.info('Voice input started');
      return true;
    } catch (e) {
      _logger.severe('Error starting voice input: $e');
      _setState(AssistantState.connected);
      _setError('Failed to start voice input: $e');
      return false;
    }
  }

  /// Stop voice conversation (stop recording and send audio)
  Future<bool> stopVoiceInput() async {
    if (_currentState != AssistantState.listening) {
      _logger.warning('Not currently listening');
      return false;
    }

    try {
      _setState(AssistantState.processing);
      
      final audioData = await _audioService.stopRecording();
      if (audioData == null) {
        _setState(AssistantState.connected);
        _setError('Failed to get recorded audio');
        return false;
      }

      // Add user message to conversation (placeholder for transcription)
      _addMessage(ConversationMessage(
        id: _generateMessageId(),
        content: '[Voice Input]',
        type: MessageType.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      ));

      // Send audio to Live API
      await _webSocketClient.sendAudio(audioData);
      
      _logger.info('Voice input sent to Live API');
      return true;
    } catch (e) {
      _logger.severe('Error stopping voice input: $e');
      _setState(AssistantState.connected);
      _setError('Failed to process voice input: $e');
      return false;
    }
  }

  /// Send text message
  Future<bool> sendTextMessage(String text) async {
    if (!_webSocketClient.isConnected) {
      _setError('Not connected to Live API');
      return false;
    }

    if (text.trim().isEmpty) {
      _setError('Message cannot be empty');
      return false;
    }

    try {
      _setState(AssistantState.processing);

      // Add user message to conversation
      _addMessage(ConversationMessage(
        id: _generateMessageId(),
        content: text,
        type: MessageType.user,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      ));

      // Send text to Live API
      await _webSocketClient.sendText(text);
      
      _logger.info('Text message sent: $text');
      return true;
    } catch (e) {
      _logger.severe('Error sending text message: $e');
      _setState(AssistantState.connected);
      _setError('Failed to send message: $e');
      return false;
    }
  }

  /// Stop current assistant response
  Future<void> stopResponse() async {
    try {
      if (_audioService.isPlaying) {
        await _audioService.stopPlayback();
      }
      
      if (_webSocketClient.isConnected) {
        await _webSocketClient.sendInterrupt();
      }
      
      _setState(AssistantState.connected);
      _logger.info('Assistant response stopped');
    } catch (e) {
      _logger.severe('Error stopping response: $e');
      _setError('Failed to stop response: $e');
    }
  }

  /// Set up WebSocket event listeners
  void _setupWebSocketListeners() {
    // Listen for server content (text responses, etc.)
    _webSocketClient.serverContentStream.listen(
      (content) => _handleServerContent(content),
      onError: (error) => _setError('Server content error: $error'),
    );

    // Listen for audio data
    _webSocketClient.audioDataStream.listen(
      (audioData) => _handleAudioResponse(audioData),
      onError: (error) => _setError('Audio data error: $error'),
    );

    // Listen for tool calls
    _webSocketClient.toolCallStream.listen(
      (toolCalls) => _handleToolCalls(toolCalls),
      onError: (error) => _setError('Tool call error: $error'),
    );

    // Listen for connection status changes
    _webSocketClient.connectionStatusStream.listen(
      (status) => _handleConnectionStatusChange(status),
      onError: (error) => _setError('Connection status error: $error'),
    );

    // Listen for WebSocket errors
    _webSocketClient.errorStream.listen(
      (error) => _setError('WebSocket error: $error'),
    );
  }

  /// Handle server content responses
  void _handleServerContent(Map<String, dynamic> content) {
    try {
      final serverContent = content['serverContent'] as Map<String, dynamic>?;
      if (serverContent == null) return;

      // Handle interrupted generation
      if (serverContent['interrupted'] == true) {
        _logger.info('Generation was interrupted');
        _setState(AssistantState.connected);
        return;
      }

      // Handle input transcription
      if (serverContent['inputTranscription'] != null) {
        final inputTranscription = serverContent['inputTranscription'] as Map<String, dynamic>;
        final transcribedText = inputTranscription['text'] as String?;
        if (transcribedText != null) {
          // Update the last user message with the transcription
          if (_conversationHistory.isNotEmpty && 
              _conversationHistory.last.type == MessageType.user &&
              _conversationHistory.last.content == '[Voice Input]') {
            final updatedMessage = _conversationHistory.last.copyWith(
              content: transcribedText,
              status: MessageStatus.complete,
            );
            _updateMessage(_conversationHistory.last.id, updatedMessage);
          }
        }
      }

      // Handle output transcription
      if (serverContent['outputTranscription'] != null) {
        final outputTranscription = serverContent['outputTranscription'] as Map<String, dynamic>;
        final transcribedText = outputTranscription['text'] as String?;
        if (transcribedText != null) {
          _addMessage(ConversationMessage(
            id: _generateMessageId(),
            content: transcribedText,
            type: MessageType.assistant,
            timestamp: DateTime.now(),
          ));
        }
      }

      final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
      if (modelTurn == null) return;

      final parts = modelTurn['parts'] as List<dynamic>?;
      if (parts == null) return;

      String? textResponse;
      bool hasAudio = false;

      for (final part in parts) {
        if (part is Map<String, dynamic>) {
          // Check for text content
          if (part.containsKey('text')) {
            textResponse = part['text'] as String?;
          }
          
          // Check for audio content
          if (part.containsKey('inlineData')) {
            final inlineData = part['inlineData'] as Map<String, dynamic>?;
            if (inlineData?['mimeType']?.toString().contains('audio') == true) {
              hasAudio = true;
            }
          }
        }
      }

      // Add assistant response to conversation (only if not already added via transcription)
      if (textResponse != null && textResponse.isNotEmpty && 
          !_config['response_modalities'].contains('AUDIO')) {
        _addMessage(ConversationMessage(
          id: _generateMessageId(),
          content: textResponse,
          type: MessageType.assistant,
          timestamp: DateTime.now(),
        ));
      }

      // Update state based on response type
      if (hasAudio) {
        _setState(AssistantState.speaking);
      } else {
        _setState(AssistantState.connected);
      }

      _logger.info('Server content processed');
    } catch (e) {
      _logger.severe('Error handling server content: $e');
      _setError('Failed to process server response: $e');
    }
  }

  /// Handle audio response from the assistant
  void _handleAudioResponse(Uint8List audioData) {
    try {
      _setState(AssistantState.speaking);
      
      // Play the audio response
      _audioService.playAudio(audioData).then((success) {
        if (success) {
          _logger.info('Playing assistant audio response');
          // Set up a completion handler to reset state when audio finishes
          _waitForAudioCompletion();
        } else {
          _setError('Failed to play audio response');
          _setState(AssistantState.connected);
        }
      }).catchError((error) {
        _logger.severe('Audio playback error: $error');
        _setError('Audio playback failed: $error');
        _setState(AssistantState.connected);
      });

    } catch (e) {
      _logger.severe('Error handling audio response: $e');
      _setError('Failed to handle audio response: $e');
      _setState(AssistantState.connected);
    }
  }

  /// Wait for audio completion and reset state
  void _waitForAudioCompletion() {
    // Monitor audio service state to detect when playbook finishes
    Timer.periodic(LiveApiConfig.audioCompletionCheckInterval, (timer) {
      if (!_audioService.isPlaying) {
        timer.cancel();
        if (_currentState == AssistantState.speaking) {
          _setState(AssistantState.connected);
        }
      }
    });
  }

  /// Set up session management listeners
  void _setupSessionListeners() {
    // Listen for GoAway messages
    sessionManager.goAwayStream.listen(
      (goAway) {
        _logger.warning('Connection will terminate in ${goAway.timeLeft.inSeconds}s');
        _addMessage(ConversationMessage(
          id: _generateMessageId(),
          content: 'Connection will be reset in ${goAway.timeLeft.inSeconds} seconds',
          type: MessageType.system,
          timestamp: DateTime.now(),
        ));
      },
      onError: (error) => _logger.warning('GoAway stream error: $error'),
    );

    // Listen for generation complete events
    sessionManager.generationCompleteStream.listen(
      (isComplete) {
        if (isComplete && _currentState == AssistantState.speaking) {
          _setState(AssistantState.connected);
        }
      },
      onError: (error) => _logger.warning('Generation complete stream error: $error'),
    );

    // Listen for session resumption updates
    sessionManager.sessionUpdateStream.listen(
      (sessionData) {
        _logger.info('Session resumption data updated');
        // Could save session data here for persistence
      },
      onError: (error) => _logger.warning('Session update stream error: $error'),
    );

    // Listen for token updates if using ephemeral tokens
    if (_useEphemeralTokens) {
      tokenService.tokenStream.listen(
        (token) {
          if (token != null) {
            _logger.info('Ephemeral token updated, valid for ${token.newSessionTimeLeft.inMinutes} minutes');
          }
        },
        onError: (error) => _logger.warning('Token stream error: $error'),
      );
    }
  }

  /// Handle tool calls from the model
  Future<void> _handleToolCalls(List<ToolCall> toolCalls) async {
    try {
      _logger.info('Handling ${toolCalls.length} tool call(s)');
      
      // Add a system message about tool usage
      _addMessage(ConversationMessage(
        id: _generateMessageId(),
        content: 'Using tools: ${toolCalls.map((tc) => tc.name).join(', ')}',
        type: MessageType.system,
        timestamp: DateTime.now(),
      ));

      // Handle the tool calls
      final responses = await _toolsService.handleToolCalls(toolCalls);
      
      // Send responses back to the model
      await _webSocketClient.sendToolResponse(responses);
      
      _logger.info('Tool responses sent successfully');
    } catch (e) {
      _logger.severe('Error handling tool calls: $e');
      _setError('Tool execution failed: $e');
    }
  }

  /// Handle connection status changes
  void _handleConnectionStatusChange(String status) {
    switch (status) {
      case 'connected':
        if (_currentState == AssistantState.connecting) {
          _setState(AssistantState.connected);
        }
        break;
      case 'disconnected':
        if (_currentState != AssistantState.idle) {
          _setState(AssistantState.idle);
        }
        break;
      case 'error':
        _setState(AssistantState.error);
        _setError('Connection error occurred');
        break;
      case 'failed':
        _setState(AssistantState.error);
        _setError('Connection failed after multiple attempts');
        break;
    }
    _logger.info('Connection status changed: $status');
  }

  /// Add message to conversation history
  void _addMessage(ConversationMessage message) {
    _conversationHistory.add(message);
    _conversationController.add(List.from(_conversationHistory));
  }

  /// Update message in conversation history
  void _updateMessage(String messageId, ConversationMessage updatedMessage) {
    final index = _conversationHistory.indexWhere((msg) => msg.id == messageId);
    if (index != -1) {
      _conversationHistory[index] = updatedMessage;
      _conversationController.add(List.from(_conversationHistory));
    }
  }

  /// Set current state
  void _setState(AssistantState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(_currentState);
      _logger.info('State changed to: $newState');
    }
  }

  /// Set error state and message
  void _setError(String errorMessage) {
    _logger.severe(errorMessage);
    _errorController.add(errorMessage);
    if (_currentState != AssistantState.error) {
      _setState(AssistantState.error);
    }
  }

  /// Generate unique message ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_conversationHistory.length}';
  }

  /// Clear conversation history
  void clearConversation() {
    _conversationHistory.clear();
    _conversationController.add([]);
    _logger.info('Conversation history cleared');
  }

  /// Get session information
  Map<String, dynamic> getSessionInfo() {
    return {
      'session_stats': sessionManager.getSessionStats(),
      'token_status': _useEphemeralTokens ? tokenService.getTokenStatus() : null,
      'connection_config': {
        'use_ephemeral_tokens': _useEphemeralTokens,
        'session_management_enabled': _enableSessionManagement,
        'model': _model,
      },
    };
  }

  /// Enable ephemeral tokens for next connection
  void enableEphemeralTokens(bool enable) {
    _useEphemeralTokens = enable;
    _logger.info('Ephemeral tokens ${enable ? 'enabled' : 'disabled'}');
  }

  /// Enable session management for next connection
  void setSessionManagementEnabled(bool enable) {
    _enableSessionManagement = enable;
    _logger.info('Session management ${enable ? 'enabled' : 'disabled'}');
  }

  /// Disconnect from Live API
  Future<void> disconnect() async {
    try {
      await _audioService.stopPlayback();
      if (_audioService.isRecording) {
        await _audioService.stopRecording();
      }
      
      await _webSocketClient.disconnect();
      _setState(AssistantState.idle);
      
      _logger.info('Disconnected from Live API');
    } catch (e) {
      _logger.severe('Error disconnecting: $e');
    }
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    try {
      await disconnect();
      await _audioService.dispose();
      await _webSocketClient.dispose();
      _toolsService.dispose();
      
      await _stateController.close();
      await _conversationController.close();
      await _errorController.close();
      
      _logger.info('LiveApiService disposed');
    } catch (e) {
      _logger.severe('Error disposing LiveApiService: $e');
    }
  }
}