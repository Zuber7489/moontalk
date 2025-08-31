import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import '../services/live_api_service.dart';
import '../services/audio_service.dart';
import '../services/session_manager.dart';
import '../services/ephemeral_token_service.dart';

/// Provider for managing virtual assistant state
class AssistantProvider extends ChangeNotifier {
  static final Logger _logger = Logger('AssistantProvider');
  
  final LiveApiService _liveApiService = LiveApiService();
  final AudioService _audioService = AudioService();

  // State variables
  AssistantState _currentState = AssistantState.idle;
  List<ConversationMessage> _conversationHistory = [];
  String? _currentError;
  bool _isRecording = false;
  double _volumeLevel = 0.0;
  String _statusMessage = '';

  // Configuration
  String? _apiKey;
  String _selectedModel = 'gemini-2.5-flash-preview-native-audio-dialog';
  bool _useNativeAudio = true;

  // Getters
  AssistantState get currentState => _currentState;
  List<ConversationMessage> get conversationHistory => List.unmodifiable(_conversationHistory);
  String? get currentError => _currentError;
  bool get isRecording => _isRecording;
  double get volumeLevel => _volumeLevel;
  String get statusMessage => _statusMessage;
  bool get isConnected => _liveApiService.isConnected;
  bool get isInitialized => _apiKey != null;
  String get selectedModel => _selectedModel;
  bool get useNativeAudio => _useNativeAudio;
  String? get apiKey => _apiKey;
  
  // Session management access
  SessionManager get sessionManager => _liveApiService.sessionManager;
  EphemeralTokenService get tokenService => _liveApiService.tokenService;

  // Available models
  static const List<String> availableModels = [
    'gemini-2.5-flash-preview-native-audio-dialog',
    'gemini-2.5-flash-exp-native-audio-thinking-dialog',
    'gemini-live-2.5-flash-preview',
    'gemini-2.0-flash-live-001',
  ];

  AssistantProvider() {
    _initializeProvider();
    // Auto-initialize with default API key for easier testing
    _autoInitializeWithDefaultKey();
  }

  /// Auto-initialize with default API key from memory
  void _autoInitializeWithDefaultKey() {
    const defaultApiKey = 'AIzaSyCIBNokHApxmCCRbbVpsBxOsRt64MuW5PY';
    if (defaultApiKey.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!isInitialized) {
          initialize(defaultApiKey);
        }
      });
    }
  }

  /// Initialize the provider and set up listeners
  void _initializeProvider() {
    _setupServiceListeners();
    _logger.info('AssistantProvider initialized');
  }

  /// Set up listeners for service streams
  void _setupServiceListeners() {
    // Listen for state changes
    _liveApiService.stateStream.listen(
      (state) {
        _currentState = state;
        _updateStatusMessage();
        notifyListeners();
      },
      onError: (error) {
        _setError('State stream error: $error');
      },
    );

    // Listen for conversation updates
    _liveApiService.conversationStream.listen(
      (conversation) {
        _conversationHistory = conversation;
        notifyListeners();
      },
      onError: (error) {
        _setError('Conversation stream error: $error');
      },
    );

    // Listen for errors
    _liveApiService.errorStream.listen(
      (error) {
        _setError(error);
      },
    );

    // Listen for volume levels
    _audioService.volumeLevelStream?.listen(
      (level) {
        _volumeLevel = level;
        notifyListeners();
      },
      onError: (error) {
        _logger.warning('Volume level stream error: $error');
      },
    );
  }

  /// Initialize the assistant with API key
  Future<bool> initialize(String apiKey) async {
    try {
      _logger.info('Initializing assistant...');
      _apiKey = apiKey;
      _clearError();

      final config = {
        'response_modalities': _useNativeAudio ? ['AUDIO'] : ['AUDIO'],
        'system_instruction': 'You are MoonTalk, a helpful and friendly virtual assistant. '
            'Respond in a conversational and engaging manner. '
            'Keep responses concise but informative. When responding with audio, '
            'speak naturally and expressively.',
        // Enable transcriptions for better UX
        'output_audio_transcription': {},
        'input_audio_transcription': {},
      };

      final success = await _liveApiService.initialize(
        apiKey: apiKey,
        model: _selectedModel,
        config: config,
      );

      if (success) {
        _logger.info('Assistant initialized successfully');
        _updateStatusMessage();
        notifyListeners();
        return true;
      } else {
        _setError('Failed to initialize assistant');
        return false;
      }
    } catch (e) {
      _logger.severe('Initialization error: $e');
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
      _setError('API key not set');
      return false;
    }

    try {
      _logger.info('Connecting to Live API...');
      _clearError();
      
      final success = await _liveApiService.connect(
        useEphemeralTokens: useEphemeralTokens,
        enableSessionManagement: enableSessionManagement,
      );
      
      if (success) {
        _logger.info('Connected to Live API successfully');
        _updateStatusMessage();
        notifyListeners();
        return true;
      } else {
        _setError('Failed to connect to Live API');
        return false;
      }
    } catch (e) {
      _logger.severe('Connection error: $e');
      _setError('Connection failed: $e');
      return false;
    }
  }

  /// Start voice input
  Future<bool> startVoiceInput() async {
    if (!isConnected) {
      _setError('Not connected to Live API');
      return false;
    }

    try {
      _logger.info('Starting voice input...');
      _clearError();
      
      final success = await _liveApiService.startVoiceInput();
      if (success) {
        _isRecording = true;
        _updateStatusMessage();
        notifyListeners();
        return true;
      } else {
        _setError('Failed to start voice input');
        return false;
      }
    } catch (e) {
      _logger.severe('Voice input error: $e');
      _setError('Voice input failed: $e');
      return false;
    }
  }

  /// Stop voice input
  Future<bool> stopVoiceInput() async {
    if (!_isRecording) {
      _logger.warning('Not currently recording');
      return false;
    }

    try {
      _logger.info('Stopping voice input...');
      
      final success = await _liveApiService.stopVoiceInput();
      if (success) {
        _isRecording = false;
        _volumeLevel = 0.0;
        _updateStatusMessage();
        notifyListeners();
        return true;
      } else {
        _setError('Failed to stop voice input');
        return false;
      }
    } catch (e) {
      _logger.severe('Stop voice input error: $e');
      _setError('Failed to stop voice input: $e');
      return false;
    }
  }

  /// Send text message
  Future<bool> sendTextMessage(String message) async {
    if (!isConnected) {
      _setError('Not connected to Live API');
      return false;
    }

    if (message.trim().isEmpty) {
      _setError('Message cannot be empty');
      return false;
    }

    try {
      _logger.info('Sending text message: $message');
      _clearError();
      
      final success = await _liveApiService.sendTextMessage(message);
      if (success) {
        _updateStatusMessage();
        notifyListeners();
        return true;
      } else {
        _setError('Failed to send message');
        return false;
      }
    } catch (e) {
      _logger.severe('Send message error: $e');
      _setError('Failed to send message: $e');
      return false;
    }
  }

  /// Stop current assistant response
  Future<void> stopResponse() async {
    try {
      _logger.info('Stopping assistant response...');
      await _liveApiService.stopResponse();
      _updateStatusMessage();
      notifyListeners();
    } catch (e) {
      _logger.severe('Stop response error: $e');
      _setError('Failed to stop response: $e');
    }
  }

  /// Clear conversation history
  void clearConversation() {
    try {
      _logger.info('Clearing conversation...');
      _liveApiService.clearConversation();
      _conversationHistory = [];
      _clearError();
      notifyListeners();
    } catch (e) {
      _logger.severe('Clear conversation error: $e');
      _setError('Failed to clear conversation: $e');
    }
  }

  /// Change model
  Future<bool> changeModel(String model) async {
    if (model == _selectedModel) {
      return true;
    }

    try {
      _logger.info('Changing model to: $model');
      _selectedModel = model;
      
      // Update audio mode based on model
      _useNativeAudio = model.contains('native-audio');
      
      // If connected, reconnect with new model
      if (isConnected) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
        return await connect();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Model change error: $e');
      _setError('Failed to change model: $e');
      return false;
    }
  }

  /// Toggle audio mode
  Future<bool> toggleAudioMode() async {
    try {
      _useNativeAudio = !_useNativeAudio;
      
      // Update model if necessary
      if (_useNativeAudio && !_selectedModel.contains('native-audio')) {
        return await changeModel('gemini-2.5-flash-preview-native-audio-dialog');
      } else if (!_useNativeAudio && _selectedModel.contains('native-audio')) {
        return await changeModel('gemini-live-2.5-flash-preview');
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _logger.severe('Toggle audio mode error: $e');
      _setError('Failed to toggle audio mode: $e');
      return false;
    }
  }

  /// Disconnect from Live API
  Future<void> disconnect() async {
    try {
      _logger.info('Disconnecting from Live API...');
      await _liveApiService.disconnect();
      _isRecording = false;
      _volumeLevel = 0.0;
      _updateStatusMessage();
      notifyListeners();
    } catch (e) {
      _logger.severe('Disconnect error: $e');
      _setError('Disconnect failed: $e');
    }
  }

  /// Update status message based on current state
  void _updateStatusMessage() {
    switch (_currentState) {
      case AssistantState.idle:
        _statusMessage = isInitialized ? 'Ready to connect' : 'Add API key to start';
        break;
      case AssistantState.connecting:
        _statusMessage = 'Connecting to Live API...';
        break;
      case AssistantState.connected:
        _statusMessage = 'Connected • Ready to chat';
        break;
      case AssistantState.listening:
        _statusMessage = 'Listening...';
        break;
      case AssistantState.processing:
        _statusMessage = 'Processing your request...';
        break;
      case AssistantState.speaking:
        _statusMessage = 'Assistant is responding...';
        break;
      case AssistantState.error:
        _statusMessage = _currentError ?? 'An error occurred';
        break;
    }
  }

  /// Set error state
  void _setError(String error) {
    _currentError = error;
    _updateStatusMessage();
    notifyListeners();
    _logger.severe(error);
  }

  /// Clear error state
  void _clearError() {
    _currentError = null;
    _updateStatusMessage();
  }

  /// Clear current error
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Get session information
  Map<String, dynamic> getSessionInfo() {
    return _liveApiService.getSessionInfo();
  }

  /// Enable ephemeral tokens for next connection
  void enableEphemeralTokens(bool enable) {
    _liveApiService.enableEphemeralTokens(enable);
    notifyListeners();
  }

  /// Enable session management for next connection
  void enableSessionManagement(bool enable) {
    _liveApiService.setSessionManagementEnabled(enable);
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.info('Disposing AssistantProvider...');
    _liveApiService.dispose();
    super.dispose();
  }
}