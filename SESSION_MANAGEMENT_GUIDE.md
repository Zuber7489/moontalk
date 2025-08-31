# Session Management with Live API - Implementation Guide

## Overview

This implementation provides comprehensive session management for Google's Gemini Live API, addressing the key challenges mentioned in the documentation:

- **Session lifetime limitations** (15 minutes for audio-only, 2 minutes for audio+video)
- **Connection drops** (every ~10 minutes)
- **Context window management**
- **Security enhancement** with ephemeral tokens

## 🚀 **Key Features Implemented**

### 1. **Context Window Compression**
Enables unlimited session duration by automatically compressing the context when it approaches token limits.

```dart
// Enable compression to extend sessions indefinitely
final compressionConfig = ContextWindowCompressionConfig(
  enabled: true,
  triggerTokens: 25000, // Compress at 25k tokens
  useSlidingWindow: true,
);
```

### 2. **Session Resumption**
Handles connection drops gracefully by maintaining session state across multiple WebSocket connections.

```dart
// Automatic session resumption configuration
await liveApiService.connect(
  useEphemeralTokens: false,
  enableSessionManagement: true,
);
```

### 3. **Ephemeral Tokens**
Enhanced security for client-side deployments with short-lived authentication tokens.

```dart
// Create ephemeral token for secure client-side usage
final token = await tokenService.createClientToken(
  apiKey: 'your-api-key',
  model: 'gemini-2.5-flash-preview-native-audio-dialog',
  sessionDuration: Duration(minutes: 30),
);
```

### 4. **GoAway Message Handling**
Prepares for connection termination by listening for server warnings.

```dart
// Listen for connection termination warnings
sessionManager.goAwayStream.listen((goAway) {
  print('Connection will terminate in ${goAway.timeLeft.inSeconds}s');
});
```

### 5. **Generation Complete Detection**
Knows when the AI model finishes generating responses.

```dart
// Listen for generation completion
sessionManager.generationCompleteStream.listen((isComplete) {
  if (isComplete) {
    print('AI response generation completed');
  }
});
```

## 📁 **New Files Added**

1. **[`session_manager.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\services\session_manager.dart)** - Core session management
2. **[`ephemeral_token_service.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\services\ephemeral_token_service.dart)** - Token management
3. **[`session_management_screen.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\screens\session_management_screen.dart)** - UI for session control

## 🔧 **Updated Files**

1. **[`websocket_client.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\services\websocket_client.dart)** - Session integration
2. **[`live_api_service.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\services\live_api_service.dart)** - Service enhancement
3. **[`assistant_provider.dart`](file://c:\zuber%20projects\MoonTalk\moontalk_assistant\lib\providers\assistant_provider.dart)** - Provider updates

## 💡 **Usage Examples**

### Basic Session Management
```dart
// Initialize with session management
final provider = AssistantProvider();
await provider.initialize('your-api-key');

// Connect with session management enabled
await provider.connect(
  useEphemeralTokens: false,
  enableSessionManagement: true,
);

// Get session information
final sessionInfo = provider.getSessionInfo();
print('Session duration: ${sessionInfo['session_stats']['duration']} minutes');
```

### Ephemeral Token Usage
```dart
// Enable ephemeral tokens for security
provider.enableEphemeralTokens(true);

// Connect with ephemeral token
await provider.connect(
  useEphemeralTokens: true,
  enableSessionManagement: true,
);

// Check token status
final tokenStatus = provider.tokenService.getTokenStatus();
print('Token valid for: ${tokenStatus['newSessionTimeLeft']} minutes');
```

### Custom Session Configuration
```dart
// Configure context compression
final compressionConfig = ContextWindowCompressionConfig(
  enabled: true,
  triggerTokens: 30000,
  compressionRatio: 0.4, // Compress to 40% of original
  useSlidingWindow: true,
);

provider.sessionManager.updateCompressionConfig(compressionConfig);
```

### Session Event Monitoring
```dart
// Listen for session events
provider.sessionManager.goAwayStream.listen((goAway) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Connection Reset'),
      content: Text('Connection will reset in ${goAway.timeLeft.inSeconds} seconds'),
    ),
  );
});

// Listen for generation completion
provider.sessionManager.generationCompleteStream.listen((complete) {
  if (complete) {
    // Update UI to show response is complete
    setState(() {
      isGenerating = false;
    });
  }
});
```

## 🎯 **Benefits Achieved**

### 1. **Unlimited Session Duration**
- ✅ Context window compression prevents 15-minute limit
- ✅ Automatic compression at configurable token thresholds
- ✅ Sliding window maintains conversation context

### 2. **Connection Resilience**
- ✅ Automatic session resumption across connection drops
- ✅ GoAway message handling for graceful transitions
- ✅ Exponential backoff for reconnection attempts

### 3. **Enhanced Security**
- ✅ Ephemeral tokens for client-side deployments
- ✅ Short-lived authentication (1 minute for new sessions)
- ✅ Constrained tokens with model-specific permissions

### 4. **Better User Experience**
- ✅ Real-time session status monitoring
- ✅ Smooth handling of connection transitions
- ✅ Clear feedback on session state changes

## 📊 **Session Management UI**

The new Session Management screen provides:

- **Real-time session status** - Connection state, duration, model info
- **Token management** - Ephemeral token status and renewal
- **Configuration controls** - Enable/disable session features
- **Session actions** - Connect, disconnect, refresh, create tokens
- **Debug information** - Complete session data in JSON format

Access it from your app's navigation or settings menu.

## ⚙️ **Configuration Options**

### Context Window Compression
```dart
ContextWindowCompressionConfig(
  enabled: true,              // Enable compression
  triggerTokens: 25000,        // Start compression at 25k tokens
  compressionRatio: 0.5,       // Compress to 50% of original
  useSlidingWindow: true,      // Use sliding window approach
)
```

### Ephemeral Token Settings
```dart
EphemeralTokenConfig(
  uses: 1,                     // Single-use token
  expireTime: Duration(minutes: 30),        // Token lifetime
  newSessionExpireTime: Duration(minutes: 1), // Quick start window
  liveConnectConstraints: {...}, // Model constraints
)
```

## 🔍 **Monitoring and Debugging**

### Session Statistics
```dart
final stats = provider.sessionManager.getSessionStats();
/*
{
  'active': true,
  'hasValidResumptionData': true,
  'duration': 45,              // minutes
  'compressionEnabled': true,
  'resumptionEnabled': true,
  'startTime': '2025-08-31T12:00:00Z'
}
*/
```

### Token Status
```dart
final tokenStatus = provider.tokenService.getTokenStatus();
/*
{
  'hasToken': true,
  'canStartNewSession': true,
  'isValid': true,
  'newSessionTimeLeft': 1,     // minutes
  'totalTimeLeft': 30,         // minutes
  'uses': 1,
  'name': 'token_abc123...'
}
*/
```

## 🚨 **Best Practices**

1. **Always enable session management** for production deployments
2. **Use ephemeral tokens** for client-side applications
3. **Monitor session duration** to understand usage patterns
4. **Handle GoAway messages** gracefully in your UI
5. **Enable context compression** for longer conversations
6. **Test connection resilience** under poor network conditions

## 🔄 **Migration from Basic Implementation**

If you're upgrading from a basic Live API implementation:

1. **Update connection calls** to include session parameters
2. **Add session event listeners** for better UX
3. **Enable ephemeral tokens** if deploying client-side
4. **Add session management UI** for user control
5. **Test extended sessions** to verify compression works

## 📈 **Performance Impact**

- **Memory usage**: Minimal increase due to session state management
- **Network usage**: Slight increase due to session management messages
- **Latency**: No impact on audio/text response times
- **Battery**: Minor increase due to additional background processing

## 🎉 **Result**

Your MoonTalk Assistant now has enterprise-grade session management that:
- Supports unlimited conversation duration
- Handles connection drops gracefully
- Provides enhanced security options
- Offers comprehensive monitoring and control

The implementation follows all the session management best practices from the Live API documentation while providing a smooth user experience.

## Next Steps

1. **Test the session management UI** by navigating to the new screen
2. **Try ephemeral tokens** in a client-side deployment
3. **Monitor session statistics** during longer conversations
4. **Customize compression settings** based on your use case
5. **Implement session persistence** if needed for your app