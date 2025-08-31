# MoonTalk Assistant - Google Gemini Live API Integration

This document provides examples and usage instructions for integrating Google's Gemini Live API into your Flutter application.

## Overview

MoonTalk Assistant is a Flutter application that demonstrates real-time voice and text interactions with Google's Gemini Live API. It supports:

- **Real-time Audio Conversations**: Native audio input/output with 16kHz input and 24kHz output
- **Text-based Chat**: Send and receive text messages
- **Function Calling**: Execute custom functions and tools
- **Voice Activity Detection**: Automatic speech detection and interruption handling
- **Multiple Model Support**: Native audio and half-cascade models
- **Audio Transcription**: Real-time transcription of both input and output audio

## Key Features

### 1. Native Audio Support
```dart
// Use native audio models for the most natural speech
final model = 'gemini-2.5-flash-preview-native-audio-dialog';

// With thinking capabilities
final thinkingModel = 'gemini-2.5-flash-exp-native-audio-thinking-dialog';
```

### 2. Function Calling
The app includes several built-in functions:
- `get_weather(location, units)` - Get weather information
- `get_current_time(timezone)` - Get current time
- `calculate(expression)` - Perform calculations
- `turn_on_lights(room, brightness)` - Smart home control
- `turn_off_lights(room)` - Smart home control

### 3. Google Search Integration
Automatic web search capabilities for real-time information.

### 4. Code Execution
The assistant can generate and execute Python code for complex calculations.

## Usage Examples

### Basic Voice Conversation
```dart
final provider = Provider.of<AssistantProvider>(context, listen: false);

// Initialize with your API key
await provider.initialize('YOUR_API_KEY');

// Connect to Live API
await provider.connect();

// Start voice input
await provider.startVoiceInput();

// Stop and send voice input
await provider.stopVoiceInput();
```

### Send Text Message
```dart
await provider.sendTextMessage('Hello, how are you?');
```

### Handle Tool Calls
```dart
// Tool calls are handled automatically by the ToolsService
// Custom functions can be registered:

toolsService.registerFunction(
  name: 'my_custom_function',
  description: 'Description of what this function does',
  parameters: {
    'type': 'object',
    'properties': {
      'param1': {'type': 'string', 'description': 'Parameter description'},
    },
    'required': ['param1'],
  },
  handler: (args) async {
    // Your custom function logic here
    return 'Function result';
  },
);
```

## Configuration Options

### Model Selection
```dart
// Native audio models (best quality, most features)
'gemini-2.5-flash-preview-native-audio-dialog'
'gemini-2.5-flash-exp-native-audio-thinking-dialog'

// Half-cascade models (better tool support)
'gemini-live-2.5-flash-preview'
'gemini-2.0-flash-live-001'
```

### Audio Configuration
```dart
final config = {
  'response_modalities': ['AUDIO'], // or ['TEXT'] for text-only
  'system_instruction': 'Your custom system prompt',
  'output_audio_transcription': {}, // Enable output transcription
  'input_audio_transcription': {}, // Enable input transcription
  'tools': toolsService.getToolsConfig(), // Enable function calling
};
```

## API Key Setup

1. Go to [Google AI Studio](https://aistudio.google.com)
2. Create a new API key
3. Add it to your app initialization:

```dart
await provider.initialize('YOUR_API_KEY_HERE');
```

## Error Handling

The app includes comprehensive error handling:

```dart
// Listen for errors
provider.errorStream.listen((error) {
  print('Error: $error');
});

// Check connection status
if (provider.isConnected) {
  // Perform operations
}
```

## Best Practices

1. **Always check permissions** before starting audio recording
2. **Handle interruptions** gracefully using Voice Activity Detection
3. **Use appropriate models** for your use case (native vs half-cascade)
4. **Implement proper error handling** for network issues
5. **Dispose resources** properly when done

## Limitations

- Audio-only sessions: 15 minutes max
- Audio + video sessions: 2 minutes max  
- Context window: 128k tokens (native) / 32k tokens (others)
- One response modality per session (AUDIO or TEXT, not both)

## Getting Started

1. Clone the repository
2. Run `flutter pub get`
3. Add your API key to the app
4. Run the application
5. Start chatting with your AI assistant!

For more detailed implementation examples, see the source code in the `lib/` directory.