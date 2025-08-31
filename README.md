# MoonTalk Assistant 🌙

A real-time virtual assistant app built with Flutter, powered by Google's Live API for natural voice conversations.

## Features ✨

- **Real-time Voice Conversations**: Natural, low-latency voice interactions
- **Multiple AI Models**: Support for various Gemini models including native audio
- **Text and Voice Input**: Seamlessly switch between voice and text communication
- **Beautiful UI**: Modern, responsive design with smooth animations
- **Cross-platform**: Runs on Android, iOS, Web, and Desktop
- **Smart Error Handling**: Comprehensive error management and user feedback
- **Conversation History**: Keep track of your chat sessions

## Screenshots 📱

The app features:
- Interactive microphone button with voice level indicators
- Conversation display with message bubbles
- Status indicators showing connection and processing states
- Settings screen for model configuration
- Error handling with helpful user feedback

## Getting Started 🚀

### Prerequisites

- Flutter SDK (3.35.2 or higher)
- Google AI Studio API key
- Microphone access for voice input

### Installation

1. **Clone or download the project**
   ```bash
   git clone <repository-url>
   cd moontalk_assistant
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Get your Google AI Studio API key**
   - Go to [Google AI Studio](https://aistudio.google.com)
   - Create a new API key
   - Keep it secure for later use

4. **Run the app**
   ```bash
   flutter run
   ```

### Platform-specific Setup

#### Android
- Minimum SDK version: 21
- Microphone permission is automatically requested

#### iOS
- Minimum iOS version: 12.0
- Microphone permission configured in Info.plist

#### Web
- Works in modern browsers with WebRTC support
- Chrome recommended for best performance

## Usage 💬

1. **First Launch**
   - Enter your Google AI Studio API key when prompted
   - The app will initialize and connect to the Live API

2. **Voice Conversations**
   - Tap the microphone button to start speaking
   - Tap again to stop and send your voice message
   - Listen to the AI's response

3. **Text Messages**
   - Type in the text input field at the bottom
   - Tap send to submit your message

4. **Settings**
   - Tap the settings icon to configure AI models
   - Choose between native audio and cascade models
   - View connection status and manage conversations

## Configuration 🔧

### Available AI Models

1. **Gemini 2.5 Flash (Native Audio)** - Default
   - Natural speech with emotion-aware dialogue
   - Best for conversational interactions

2. **Gemini 2.5 Flash Experimental (Thinking)**
   - Advanced reasoning with thinking process
   - Includes internal thought processes

3. **Gemini Live 2.5 Flash**
   - Half-cascade audio with better reliability
   - Good for production environments

4. **Gemini 2.0 Flash Live**
   - Standard live conversation model
   - Reliable general-purpose option

### Audio Configuration

- **Input**: 16-bit PCM, 16kHz, mono (Live API requirement)
- **Output**: 24kHz audio from Live API
- **Real-time processing** with minimal latency

## Architecture 🏗️

The app follows a clean architecture pattern:

```
lib/
├── main.dart                 # App entry point
├── providers/               # State management
│   └── assistant_provider.dart
├── screens/                 # UI screens
│   ├── assistant_screen.dart
│   └── settings_screen.dart
├── widgets/                 # Reusable UI components
│   ├── microphone_button.dart
│   ├── conversation_display.dart
│   └── text_input_widget.dart
├── services/                # Core services
│   ├── live_api_service.dart
│   ├── websocket_client.dart
│   └── audio_service.dart
└── utils/                   # Utilities
    ├── error_handler.dart
    └── app_config.dart
```

### Key Components

- **LiveApiService**: Main service orchestrating Live API communication
- **AudioService**: Handles recording and playback with format conversion
- **WebSocketClient**: Manages WebSocket connection and message handling
- **AssistantProvider**: State management using Provider pattern
- **ErrorHandler**: Comprehensive error handling and user feedback

## Technical Details 🔬

### Live API Integration

The app implements Google's Live API WebSocket protocol:

1. **Connection**: Secure WebSocket to Live API endpoint
2. **Audio Streaming**: Real-time PCM audio data exchange
3. **Message Protocol**: JSON-based message handling
4. **Session Management**: Persistent conversation sessions

### Audio Processing

- **Recording**: Uses Flutter's `record` package for cross-platform audio capture
- **Format Conversion**: WAV to PCM conversion for Live API compatibility
- **Playback**: Audio response playback with proper format handling
- **Volume Monitoring**: Real-time audio level feedback

### State Management

- **Provider Pattern**: Reactive state management
- **Stream-based**: Real-time updates using Dart streams
- **Error Recovery**: Automatic error handling and recovery mechanisms

## Security 🔒

- **API Key Protection**: Secure API key storage (implement secure storage for production)
- **Permission Handling**: Proper microphone permission management
- **Error Sanitization**: Safe error message handling
- **Network Security**: HTTPS/WSS encrypted connections

## Contributing 🤝

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Troubleshooting 🔧

### Common Issues

1. **"Microphone permission denied"**
   - Check app permissions in device settings
   - Restart the app after granting permissions

2. **"Invalid API key"**
   - Verify your Google AI Studio API key
   - Ensure the key has Live API access

3. **"Connection failed"**
   - Check internet connection
   - Verify firewall settings allow WebSocket connections

4. **"Audio playback issues"**
   - Check device audio settings
   - Ensure speakers/headphones are working

### Debug Mode

Enable debug logging by setting log level to `FINE` in main.dart:
```dart
Logger.root.level = Level.FINE;
```

## License 📄

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments 🙏

- Google AI Team for the Live API
- Flutter team for the amazing framework
- Open source contributors for the packages used

## Support 💬

For issues and questions:
- Check the troubleshooting section
- Review Google Live API documentation
- Create an issue in the repository

---

**MoonTalk Assistant** - Bringing AI conversations to life! 🌙✨