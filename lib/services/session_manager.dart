import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

/// Session resumption data
class SessionResumptionData {
  final String handle;
  final DateTime lastUpdated;
  final bool resumable;

  SessionResumptionData({
    required this.handle,
    required this.lastUpdated,
    required this.resumable,
  });

  factory SessionResumptionData.fromJson(Map<String, dynamic> json) {
    return SessionResumptionData(
      handle: json['handle'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      resumable: json['resumable'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'handle': handle,
      'lastUpdated': lastUpdated.toIso8601String(),
      'resumable': resumable,
    };
  }

  /// Check if the resumption data is still valid (within 2 hours)
  bool get isValid {
    final now = DateTime.now();
    final validUntil = lastUpdated.add(const Duration(hours: 2));
    return now.isBefore(validUntil) && resumable;
  }
}

/// GoAway message data
class GoAwayMessage {
  final Duration timeLeft;
  final String? reason;

  GoAwayMessage({
    required this.timeLeft,
    this.reason,
  });

  factory GoAwayMessage.fromJson(Map<String, dynamic> json) {
    final timeLeftMs = json['timeLeft'] as int? ?? 0;
    return GoAwayMessage(
      timeLeft: Duration(milliseconds: timeLeftMs),
      reason: json['reason'] as String?,
    );
  }
}

/// Context window compression configuration
class ContextWindowCompressionConfig {
  final bool enabled;
  final int triggerTokens;
  final double compressionRatio;
  final bool useSlidingWindow;

  ContextWindowCompressionConfig({
    this.enabled = true,
    this.triggerTokens = 25000, // Trigger compression at 25k tokens
    this.compressionRatio = 0.5, // Compress to 50% of original size
    this.useSlidingWindow = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'sliding_window': useSlidingWindow ? {} : null,
      'trigger_tokens': triggerTokens,
      'compression_ratio': compressionRatio,
    };
  }
}

/// Session management service for Live API
class SessionManager {
  static final Logger _logger = Logger('SessionManager');
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Session state
  SessionResumptionData? _currentSessionData;
  bool _sessionActive = false;
  Timer? _sessionTimer;
  Duration? _sessionDuration;
  DateTime? _sessionStartTime;

  // Configuration
  ContextWindowCompressionConfig _compressionConfig = ContextWindowCompressionConfig();
  bool _enableSessionResumption = true;

  // Stream controllers
  final StreamController<GoAwayMessage> _goAwayController = 
      StreamController<GoAwayMessage>.broadcast();
  final StreamController<bool> _generationCompleteController = 
      StreamController<bool>.broadcast();
  final StreamController<SessionResumptionData> _sessionUpdateController = 
      StreamController<SessionResumptionData>.broadcast();

  // Public streams
  Stream<GoAwayMessage> get goAwayStream => _goAwayController.stream;
  Stream<bool> get generationCompleteStream => _generationCompleteController.stream;
  Stream<SessionResumptionData> get sessionUpdateStream => _sessionUpdateController.stream;

  // Getters
  bool get hasValidSession => _currentSessionData?.isValid ?? false;
  bool get isSessionActive => _sessionActive;
  SessionResumptionData? get currentSessionData => _currentSessionData;
  Duration? get sessionDuration => _sessionDuration;
  ContextWindowCompressionConfig get compressionConfig => _compressionConfig;

  /// Initialize session manager with configuration
  void initialize({
    ContextWindowCompressionConfig? compressionConfig,
    bool enableSessionResumption = true,
  }) {
    if (compressionConfig != null) {
      _compressionConfig = compressionConfig;
    }
    _enableSessionResumption = enableSessionResumption;
    
    _logger.info('SessionManager initialized with compression: ${_compressionConfig.enabled}, resumption: $_enableSessionResumption');
  }

  /// Get session configuration for Live API setup
  Map<String, dynamic> getSessionConfig() {
    final config = <String, dynamic>{};

    // Add context window compression if enabled
    if (_compressionConfig.enabled) {
      config['context_window_compression'] = _compressionConfig.toJson();
      _logger.info('Context window compression enabled');
    }

    // Add session resumption if enabled
    if (_enableSessionResumption) {
      final resumptionConfig = <String, dynamic>{};
      
      // Include previous session handle if available
      if (_currentSessionData?.isValid == true) {
        resumptionConfig['handle'] = _currentSessionData!.handle;
        _logger.info('Resuming session with handle: ${_currentSessionData!.handle}');
      }
      
      config['session_resumption'] = resumptionConfig;
    }

    return config;
  }

  /// Start a new session
  void startSession() {
    _sessionActive = true;
    _sessionStartTime = DateTime.now();
    _startSessionTimer();
    
    _logger.info('Session started at ${_sessionStartTime}');
  }

  /// End the current session
  void endSession() {
    _sessionActive = false;
    _stopSessionTimer();
    
    if (_sessionStartTime != null) {
      _sessionDuration = DateTime.now().difference(_sessionStartTime!);
      _logger.info('Session ended after ${_sessionDuration?.inMinutes} minutes');
    }
  }

  /// Handle session resumption update from server
  void handleSessionResumptionUpdate(Map<String, dynamic> update) {
    try {
      final resumable = update['resumable'] as bool? ?? false;
      final newHandle = update['newHandle'] as String?;

      if (resumable && newHandle != null) {
        _currentSessionData = SessionResumptionData(
          handle: newHandle,
          lastUpdated: DateTime.now(),
          resumable: resumable,
        );

        _sessionUpdateController.add(_currentSessionData!);
        _logger.info('Session resumption data updated: $newHandle');
      }
    } catch (e) {
      _logger.severe('Error handling session resumption update: $e');
    }
  }

  /// Handle GoAway message from server
  void handleGoAwayMessage(Map<String, dynamic> goAwayData) {
    try {
      final goAway = GoAwayMessage.fromJson(goAwayData);
      _goAwayController.add(goAway);
      
      _logger.warning('GoAway message received: ${goAway.timeLeft.inSeconds}s remaining');
      
      // Prepare for connection termination
      _prepareForDisconnection(goAway.timeLeft);
    } catch (e) {
      _logger.severe('Error handling GoAway message: $e');
    }
  }

  /// Handle generation complete message
  void handleGenerationComplete(bool isComplete) {
    if (isComplete) {
      _generationCompleteController.add(true);
      _logger.info('Generation completed');
    }
  }

  /// Process server message for session management
  void processServerMessage(Map<String, dynamic> message) {
    // Handle session resumption updates
    if (message.containsKey('sessionResumptionUpdate')) {
      handleSessionResumptionUpdate(message['sessionResumptionUpdate']);
    }

    // Handle GoAway messages
    if (message.containsKey('goAway')) {
      handleGoAwayMessage(message['goAway']);
    }

    // Handle server content for generation complete
    if (message.containsKey('serverContent')) {
      final serverContent = message['serverContent'] as Map<String, dynamic>;
      if (serverContent.containsKey('generationComplete')) {
        handleGenerationComplete(serverContent['generationComplete'] as bool);
      }
    }
  }

  /// Start session timer to track duration
  void _startSessionTimer() {
    _stopSessionTimer();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_sessionStartTime != null) {
        final duration = DateTime.now().difference(_sessionStartTime!);
        _sessionDuration = duration;
        
        // Log session duration milestones
        if (duration.inMinutes % 5 == 0) {
          _logger.info('Session running for ${duration.inMinutes} minutes');
        }
        
        // Warn about approaching limits (without compression)
        if (!_compressionConfig.enabled) {
          if (duration.inMinutes >= 13) { // 2 minutes before 15-minute limit
            _logger.warning('Session approaching 15-minute limit without compression');
          }
        }
      }
    });
  }

  /// Stop session timer
  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  /// Prepare for connection disconnection
  void _prepareForDisconnection(Duration timeLeft) {
    _logger.info('Preparing for disconnection in ${timeLeft.inSeconds}s');
    
    // Schedule actions before disconnection
    Timer(timeLeft - const Duration(seconds: 5), () {
      _logger.info('Connection will be terminated in 5 seconds');
      // Could trigger UI notifications here
    });
  }

  /// Save session data for resumption
  String? saveSessionForResumption() {
    if (_currentSessionData?.isValid == true) {
      try {
        final data = jsonEncode(_currentSessionData!.toJson());
        _logger.info('Session data saved for resumption');
        return data;
      } catch (e) {
        _logger.severe('Error saving session data: $e');
      }
    }
    return null;
  }

  /// Load session data from storage
  bool loadSessionFromData(String sessionData) {
    try {
      final data = jsonDecode(sessionData) as Map<String, dynamic>;
      final resumptionData = SessionResumptionData.fromJson(data);
      
      if (resumptionData.isValid) {
        _currentSessionData = resumptionData;
        _logger.info('Session data loaded: ${resumptionData.handle}');
        return true;
      } else {
        _logger.warning('Loaded session data is expired');
      }
    } catch (e) {
      _logger.severe('Error loading session data: $e');
    }
    return false;
  }

  /// Clear session data
  void clearSession() {
    _currentSessionData = null;
    endSession();
    _logger.info('Session data cleared');
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'active': _sessionActive,
      'hasValidResumptionData': hasValidSession,
      'duration': _sessionDuration?.inMinutes,
      'compressionEnabled': _compressionConfig.enabled,
      'resumptionEnabled': _enableSessionResumption,
      'startTime': _sessionStartTime?.toIso8601String(),
    };
  }

  /// Update compression configuration
  void updateCompressionConfig(ContextWindowCompressionConfig config) {
    _compressionConfig = config;
    _logger.info('Compression config updated: enabled=${config.enabled}');
  }

  /// Dispose of resources
  void dispose() {
    _stopSessionTimer();
    _goAwayController.close();
    _generationCompleteController.close();
    _sessionUpdateController.close();
    _logger.info('SessionManager disposed');
  }
}