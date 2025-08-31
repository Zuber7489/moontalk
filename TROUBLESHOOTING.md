# Troubleshooting Guide - MoonTalk Assistant

## Common Issues and Solutions

### 1. Frequent WebSocket Disconnections

**Symptoms:**
- Connection drops every few seconds
- Constant reconnection attempts
- "WebSocket connection closed" messages

**Solutions:**
- **Check API Key**: Ensure your Google AI Studio API key is valid and has Live API access
- **Network Stability**: Test on a stable internet connection
- **Firewall/Proxy**: Ensure WebSocket connections are allowed through firewall
- **Rate Limiting**: Avoid sending too many requests in quick succession

**Code Fix Applied:**
- Extended connection timeout to 15 seconds
- Reduced heartbeat frequency to 60 seconds
- Implemented exponential backoff for reconnections (2s, 5s, 10s)
- Added connection state management

### 2. Audio Playback Issues

**Symptoms:**
- Multiple start/stop cycles in audio logs
- Audio cutting out or repeating
- "Failed to play audio" errors

**Solutions:**
- **Stop Previous Playback**: Ensure previous audio is stopped before starting new
- **File Cleanup**: Clean up temporary audio files properly
- **Audio Permissions**: Check microphone and audio permissions
- **Audio Format**: Ensure proper PCM format conversion

**Code Fix Applied:**
- Added proper audio stop before starting new playback
- Improved error handling in audio service
- Added completion callbacks for audio playback
- Better temporary file management

### 3. Microphone Permission Issues

**Symptoms:**
- "Microphone permission not granted" errors
- Recording fails to start
- Permission dialog not appearing

**Solutions:**
```bash
# For Android - Add to android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

# For iOS - Add to ios/Runner/Info.plist
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice conversations</string>
```

### 4. API Key Issues

**Symptoms:**
- "Invalid API key" errors
- 401 authentication errors
- Connection fails immediately

**Solutions:**
1. Get API key from [Google AI Studio](https://aistudio.google.com)
2. Ensure the key has Live API access enabled
3. Check for extra spaces or characters in the key
4. Verify quota and billing settings

### 5. Model Selection Issues

**Symptoms:**
- Connection succeeds but no responses
- Feature limitations
- Unsupported operations

**Solutions:**
- **Native Audio Models** (recommended for voice):
  - `gemini-2.5-flash-preview-native-audio-dialog`
  - `gemini-2.5-flash-exp-native-audio-thinking-dialog`
- **Half-Cascade Models** (better for tools):
  - `gemini-live-2.5-flash-preview`
  - `gemini-2.0-flash-live-001`

### 6. Function Calling Not Working

**Symptoms:**
- Tool calls not executed
- No function responses
- Missing tool capabilities

**Solutions:**
- Ensure model supports function calling (half-cascade models preferred)
- Check tool configuration in setup message
- Verify function declarations are properly formatted
- Use models that support the specific tools you need

### 7. Performance Issues

**Symptoms:**
- Slow response times
- High memory usage
- App crashes

**Solutions:**
- **Audio Buffer Management**: Clear audio buffers regularly
- **Connection Pooling**: Reuse connections instead of creating new ones
- **Memory Management**: Dispose services properly
- **Background Processing**: Handle audio processing off main thread

### 8. Platform-Specific Issues

#### Android
```bash
# Add to android/app/build.gradle
android {
    compileSdkVersion 33
    minSdkVersion 21
    
    defaultConfig {
        targetSdkVersion 33
    }
}
```

#### iOS
```bash
# Update ios/Podfile
platform :ios, '11.0'

# Run after changes
cd ios && pod install
```

#### Web
- WebSocket connections may be blocked by CORS
- Audio recording may not work in some browsers
- Use HTTPS for microphone access

## Debugging Commands

### Enable Debug Logging
```dart
// Add to main.dart
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((record) {
  print('${record.level.name}: ${record.time}: ${record.message}');
});
```

### Test Connection
```bash
# Test basic connectivity
flutter run --debug

# Check WebSocket connection
# Look for "WebSocket connected successfully" in logs
```

### Monitor Audio
```dart
// Add to audio service for debugging
_logger.info('Audio state: recording=$_isRecording, playing=$_isPlaying');
```

## Best Practices

1. **Connection Management**
   - Don't create multiple connections simultaneously
   - Implement proper connection lifecycle management
   - Handle reconnections gracefully

2. **Audio Handling**
   - Always stop previous audio before starting new
   - Clean up temporary files
   - Monitor audio state properly

3. **Error Recovery**
   - Implement exponential backoff for retries
   - Provide user feedback for errors
   - Log errors for debugging

4. **Resource Management**
   - Dispose services when not needed
   - Clear conversation history periodically
   - Monitor memory usage

## Getting Help

If issues persist:
1. Check the logs for specific error messages
2. Test with different models
3. Verify network connectivity
4. Check Google AI Studio quotas
5. Review the [Live API Documentation](https://ai.google.dev/docs/live_api)

## Performance Monitoring

Monitor these metrics:
- Connection uptime
- Audio latency
- Memory usage
- Battery consumption
- Network usage

## Version Compatibility

Ensure you're using compatible versions:
- Flutter SDK: 3.35.2+
- Google AI Studio API: Latest
- Target platforms: Android 21+, iOS 11+, Web (modern browsers)