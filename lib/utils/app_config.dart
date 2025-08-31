/// Configuration constants and utilities for MoonTalk Assistant
class AppConfig {
  // App Information
  static const String appName = 'MoonTalk Assistant';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Real-time Virtual Assistant with Google Live API';

  // API Configuration
  static const String liveApiBaseUrl = 'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent';
  
  // Default Models
  static const String defaultNativeAudioModel = 'gemini-2.5-flash-preview-native-audio-dialog';
  static const String defaultCascadeModel = 'gemini-live-2.5-flash-preview';
  
  // Audio Configuration
  static const int recordingSampleRate = 16000; // 16kHz for Live API
  static const int playbackSampleRate = 24000;  // 24kHz from Live API
  static const int audioChannels = 1;           // Mono
  static const int audioBitDepth = 16;          // 16-bit PCM
  
  // UI Configuration
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration microphonePulseDuration = Duration(seconds: 2);
  static const Duration volumeUpdateInterval = Duration(milliseconds: 100);
  
  // Connection Configuration
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 2);
  static const int maxReconnectAttempts = 3;
  
  // Message Configuration
  static const int maxMessageLength = 8192;
  static const Duration typingIndicatorDelay = Duration(milliseconds: 500);
  
  // Default System Instructions
  static const String defaultSystemInstruction = 
      'You are MoonTalk, a helpful and friendly virtual assistant. '
      'Respond in a conversational and engaging manner. '
      'Keep responses concise but informative. '
      'Be natural and personable in your interactions.';

  // Available Models with Descriptions
  static const Map<String, ModelInfo> availableModels = {
    'gemini-2.5-flash-preview-native-audio-dialog': ModelInfo(
      name: 'Gemini 2.5 Flash (Native Audio)',
      description: 'Natural speech with emotion-aware dialogue',
      supportsNativeAudio: true,
      supportsThinking: false,
    ),
    'gemini-2.5-flash-exp-native-audio-thinking-dialog': ModelInfo(
      name: 'Gemini 2.5 Flash Experimental (Thinking)',
      description: 'Advanced reasoning with thinking process',
      supportsNativeAudio: true,
      supportsThinking: true,
    ),
    'gemini-live-2.5-flash-preview': ModelInfo(
      name: 'Gemini Live 2.5 Flash',
      description: 'Half-cascade audio with better reliability',
      supportsNativeAudio: false,
      supportsThinking: false,
    ),
    'gemini-2.0-flash-live-001': ModelInfo(
      name: 'Gemini 2.0 Flash Live',
      description: 'Standard live conversation model',
      supportsNativeAudio: false,
      supportsThinking: false,
    ),
  };

  // Audio Format MIME Types
  static const String inputAudioMimeType = 'audio/pcm;rate=16000';
  static const String outputAudioMimeType = 'audio/pcm;rate=24000';
  
  // File Extensions
  static const String audioFileExtension = '.wav';
  static const String tempFilePrefix = 'moontalk_';
}

/// Model information class
class ModelInfo {
  final String name;
  final String description;
  final bool supportsNativeAudio;
  final bool supportsThinking;

  const ModelInfo({
    required this.name,
    required this.description,
    required this.supportsNativeAudio,
    required this.supportsThinking,
  });
}

/// Response modalities for Live API
enum ResponseModality {
  audio('AUDIO'),
  text('TEXT');

  const ResponseModality(this.value);
  final String value;
}

/// Audio generation architecture types
enum AudioArchitecture {
  nativeAudio,
  halfCascade,
}

/// Connection states
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// App theme preferences
enum ThemePreference {
  light,
  dark,
  system,
}