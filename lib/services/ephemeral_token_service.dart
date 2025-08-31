import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Configuration for ephemeral token creation
class EphemeralTokenConfig {
  final int uses;
  final Duration expireTime;
  final Duration newSessionExpireTime;
  final Map<String, dynamic>? liveConnectConstraints;

  EphemeralTokenConfig({
    this.uses = 1,
    this.expireTime = const Duration(minutes: 30),
    this.newSessionExpireTime = const Duration(minutes: 1),
    this.liveConnectConstraints,
  });

  Map<String, dynamic> toJson() {
    final now = DateTime.now().toUtc();
    final config = {
      'uses': uses,
      'expire_time': now.add(expireTime).toIso8601String(),
      'new_session_expire_time': now.add(newSessionExpireTime).toIso8601String(),
    };

    if (liveConnectConstraints != null) {
      config['live_connect_constraints'] = liveConnectConstraints!;
    }

    return config;
  }
}

/// Ephemeral token data
class EphemeralToken {
  final String name;
  final String token;
  final DateTime expireTime;
  final DateTime newSessionExpireTime;
  final int uses;

  EphemeralToken({
    required this.name,
    required this.token,
    required this.expireTime,
    required this.newSessionExpireTime,
    required this.uses,
  });

  factory EphemeralToken.fromJson(Map<String, dynamic> json) {
    return EphemeralToken(
      name: json['name'] as String,
      token: json['token'] as String,
      expireTime: DateTime.parse(json['expire_time'] as String),
      newSessionExpireTime: DateTime.parse(json['new_session_expire_time'] as String),
      uses: json['uses'] as int,
    );
  }

  /// Check if token is still valid for new sessions
  bool get canStartNewSession {
    return DateTime.now().isBefore(newSessionExpireTime) && uses > 0;
  }

  /// Check if token is still valid for existing sessions
  bool get isValid {
    return DateTime.now().isBefore(expireTime);
  }

  /// Time remaining for new session creation
  Duration get newSessionTimeLeft {
    final now = DateTime.now();
    return newSessionExpireTime.isAfter(now) 
        ? newSessionExpireTime.difference(now) 
        : Duration.zero;
  }

  /// Time remaining for token validity
  Duration get timeLeft {
    final now = DateTime.now();
    return expireTime.isAfter(now) 
        ? expireTime.difference(now) 
        : Duration.zero;
  }
}

/// Service for managing ephemeral tokens
class EphemeralTokenService {
  static final Logger _logger = Logger('EphemeralTokenService');
  static final EphemeralTokenService _instance = EphemeralTokenService._internal();
  factory EphemeralTokenService() => _instance;
  EphemeralTokenService._internal();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com';
  static const String _apiVersion = 'v1alpha';

  EphemeralToken? _currentToken;
  Timer? _tokenRefreshTimer;
  
  // Stream for token updates
  final StreamController<EphemeralToken?> _tokenController = 
      StreamController<EphemeralToken?>.broadcast();

  Stream<EphemeralToken?> get tokenStream => _tokenController.stream;
  EphemeralToken? get currentToken => _currentToken;
  bool get hasValidToken => _currentToken?.canStartNewSession ?? false;

  /// Create an ephemeral token
  Future<EphemeralToken?> createToken({
    required String apiKey,
    EphemeralTokenConfig? config,
  }) async {
    try {
      _logger.info('Creating ephemeral token...');
      
      final tokenConfig = config ?? EphemeralTokenConfig();
      final url = Uri.parse('$_baseUrl/$_apiVersion/auth_tokens');
      
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = jsonEncode(tokenConfig.toJson());
      
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = EphemeralToken.fromJson(data);
        
        _currentToken = token;
        _tokenController.add(_currentToken);
        
        // Schedule token refresh before it expires
        _scheduleTokenRefresh(apiKey, config);
        
        _logger.info('Ephemeral token created: ${token.name}');
        _logger.info('Token valid for new sessions: ${token.newSessionTimeLeft.inMinutes} minutes');
        _logger.info('Token valid for existing sessions: ${token.timeLeft.inMinutes} minutes');
        
        return token;
      } else {
        _logger.severe('Failed to create ephemeral token: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      _logger.severe('Error creating ephemeral token: $e');
      return null;
    }
  }

  /// Create a token with Live API constraints for enhanced security
  Future<EphemeralToken?> createConstrainedToken({
    required String apiKey,
    required String model,
    Map<String, dynamic>? liveConfig,
    EphemeralTokenConfig? baseConfig,
  }) async {
    final constraints = {
      'model': model,
      'config': liveConfig ?? {},
    };

    final config = EphemeralTokenConfig(
      uses: baseConfig?.uses ?? 1,
      expireTime: baseConfig?.expireTime ?? const Duration(minutes: 30),
      newSessionExpireTime: baseConfig?.newSessionExpireTime ?? const Duration(minutes: 1),
      liveConnectConstraints: constraints,
    );

    _logger.info('Creating constrained token for model: $model');
    return await createToken(apiKey: apiKey, config: config);
  }

  /// Refresh token before it expires
  void _scheduleTokenRefresh(String apiKey, EphemeralTokenConfig? config) {
    _tokenRefreshTimer?.cancel();
    
    if (_currentToken != null) {
      // Refresh 30 seconds before new session expiry
      final refreshTime = _currentToken!.newSessionTimeLeft - const Duration(seconds: 30);
      
      if (refreshTime.inSeconds > 0) {
        _tokenRefreshTimer = Timer(refreshTime, () {
          _logger.info('Auto-refreshing ephemeral token...');
          createToken(apiKey: apiKey, config: config);
        });
        
        _logger.info('Token refresh scheduled in ${refreshTime.inSeconds} seconds');
      }
    }
  }

  /// Check if current token needs refresh
  bool shouldRefreshToken() {
    if (_currentToken == null) return true;
    
    // Refresh if less than 30 seconds left for new sessions
    return _currentToken!.newSessionTimeLeft.inSeconds < 30;
  }

  /// Get token for WebSocket connection
  String? getTokenForConnection() {
    if (_currentToken?.canStartNewSession == true) {
      return _currentToken!.name; // Use token name as the auth token
    }
    return null;
  }

  /// Format token for WebSocket query parameter
  String? getTokenQueryParam() {
    final token = getTokenForConnection();
    return token != null ? 'access_token=$token' : null;
  }

  /// Format token for Authorization header
  String? getAuthorizationHeader() {
    final token = getTokenForConnection();
    return token != null ? 'Token $token' : null;
  }

  /// Get token status information
  Map<String, dynamic> getTokenStatus() {
    if (_currentToken == null) {
      return {
        'hasToken': false,
        'canStartNewSession': false,
        'isValid': false,
      };
    }

    return {
      'hasToken': true,
      'canStartNewSession': _currentToken!.canStartNewSession,
      'isValid': _currentToken!.isValid,
      'newSessionTimeLeft': _currentToken!.newSessionTimeLeft.inMinutes,
      'totalTimeLeft': _currentToken!.timeLeft.inMinutes,
      'uses': _currentToken!.uses,
      'name': _currentToken!.name,
    };
  }

  /// Clear current token
  void clearToken() {
    _tokenRefreshTimer?.cancel();
    _currentToken = null;
    _tokenController.add(null);
    _logger.info('Ephemeral token cleared');
  }

  /// Create token with recommended settings for client-side deployment
  Future<EphemeralToken?> createClientToken({
    required String apiKey,
    required String model,
    Duration? sessionDuration,
  }) async {
    final config = EphemeralTokenConfig(
      uses: 1, // Single use for security
      expireTime: sessionDuration ?? const Duration(minutes: 30),
      newSessionExpireTime: const Duration(minutes: 1), // Quick start window
      liveConnectConstraints: {
        'model': model,
        'config': {
          'session_resumption': {}, // Enable resumption for reconnections
          'response_modalities': ['AUDIO'],
          'context_window_compression': {
            'sliding_window': {},
          },
        },
      },
    );

    return await createToken(apiKey: apiKey, config: config);
  }

  /// Create token for server-side usage (less restricted)
  Future<EphemeralToken?> createServerToken({
    required String apiKey,
    int uses = 5,
    Duration? expireTime,
  }) async {
    final config = EphemeralTokenConfig(
      uses: uses,
      expireTime: expireTime ?? const Duration(hours: 1),
      newSessionExpireTime: const Duration(minutes: 5),
    );

    return await createToken(apiKey: apiKey, config: config);
  }

  /// Validate current token and refresh if needed
  Future<bool> ensureValidToken(String apiKey, {EphemeralTokenConfig? config}) async {
    if (shouldRefreshToken()) {
      final newToken = await createToken(apiKey: apiKey, config: config);
      return newToken != null;
    }
    return hasValidToken;
  }

  /// Get remaining time until token refresh is needed
  Duration? getTimeUntilRefresh() {
    if (_currentToken == null) return null;
    
    final refreshTime = _currentToken!.newSessionTimeLeft - const Duration(seconds: 30);
    return refreshTime.isNegative ? Duration.zero : refreshTime;
  }

  /// Dispose of resources
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _tokenController.close();
    _currentToken = null;
    _logger.info('EphemeralTokenService disposed');
  }
}