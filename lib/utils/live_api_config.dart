/// Configuration and utilities for Live API connections
class LiveApiConfig {
  // Connection settings
  static const int maxReconnectAttempts = 3;
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration heartbeatInterval = Duration(seconds: 60);
  static const Duration audioCompletionCheckInterval = Duration(milliseconds: 500);
  
  // Retry settings with exponential backoff
  static const List<int> reconnectDelays = [2, 5, 10]; // seconds
  
  // Audio settings
  static const int inputSampleRate = 16000;  // 16kHz for input
  static const int outputSampleRate = 24000; // 24kHz for output
  static const int bitsPerSample = 16;
  static const int channels = 1; // Mono
  
  // WebSocket endpoint
  static const String websocketEndpoint = 
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent';
  
  /// Get recommended configuration for native audio models
  static Map<String, dynamic> getNativeAudioConfig({
    String? systemInstruction,
    bool enableTranscription = true,
    bool enableTools = true,
  }) {
    final config = <String, dynamic>{
      'response_modalities': ['AUDIO'],
      'speech_config': {
        'voice_config': {
          'prebuilt_voice_config': {
            'voice_name': 'Aoede' // Better voice for native audio
          }
        }
      },
    };
    
    if (systemInstruction != null) {
      config['system_instruction'] = systemInstruction;
    }
    
    if (enableTranscription) {
      config['output_audio_transcription'] = {};
      config['input_audio_transcription'] = {};
    }
    
    return config;
  }
  
  /// Get recommended configuration for half-cascade models
  static Map<String, dynamic> getHalfCascadeConfig({
    String? systemInstruction,
    bool enableTranscription = true,
    bool enableTools = true,
  }) {
    final config = <String, dynamic>{
      'response_modalities': ['AUDIO'],
      'speech_config': {
        'voice_config': {
          'prebuilt_voice_config': {
            'voice_name': 'Puck' // Good voice for half-cascade
          }
        }
      },
    };
    
    if (systemInstruction != null) {
      config['system_instruction'] = systemInstruction;
    }
    
    if (enableTranscription) {
      config['output_audio_transcription'] = {};
      config['input_audio_transcription'] = {};
    }
    
    return config;
  }
  
  /// Check if a model is a native audio model
  static bool isNativeAudioModel(String model) {
    return model.contains('native-audio');
  }
  
  /// Get optimized configuration for a specific model
  static Map<String, dynamic> getOptimizedConfig(String model, {
    String? systemInstruction,
    bool enableTranscription = true,
    bool enableTools = true,
  }) {
    if (isNativeAudioModel(model)) {
      return getNativeAudioConfig(
        systemInstruction: systemInstruction,
        enableTranscription: enableTranscription,
        enableTools: enableTools,
      );
    } else {
      return getHalfCascadeConfig(
        systemInstruction: systemInstruction,
        enableTranscription: enableTranscription,
        enableTools: enableTools,
      );
    }
  }
  
  /// Get connection retry delay for attempt number
  static Duration getRetryDelay(int attempt) {
    if (attempt <= 0 || attempt > reconnectDelays.length) {
      return Duration(seconds: reconnectDelays.last);
    }
    return Duration(seconds: reconnectDelays[attempt - 1]);
  }
}

/// Connection state management utilities
class ConnectionStateManager {
  static const List<String> stableStates = ['connected', 'idle'];
  static const List<String> transientStates = ['connecting', 'disconnected'];
  static const List<String> errorStates = ['error', 'failed'];
  
  static bool isStableState(String state) => stableStates.contains(state);
  static bool isTransientState(String state) => transientStates.contains(state);
  static bool isErrorState(String state) => errorStates.contains(state);
  
  static bool shouldAttemptReconnection(String state, int attempts) {
    return (state == 'disconnected' || state == 'error') && 
           attempts < LiveApiConfig.maxReconnectAttempts;
  }
}