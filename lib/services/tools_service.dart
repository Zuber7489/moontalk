import 'dart:async';
import 'dart:convert';
import 'package:logging/logging.dart';

/// Tool types supported by Live API
enum ToolType {
  functionCalling,
  codeExecution,
  googleSearch,
}

/// Function response for tool calling
class FunctionResponse {
  final String id;
  final String name;
  final Map<String, dynamic> response;

  FunctionResponse({
    required this.id,
    required this.name,
    required this.response,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'response': response,
    };
  }
}

/// Tool call from the model
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> args;

  ToolCall({
    required this.id,
    required this.name,
    required this.args,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      id: json['id'] as String,
      name: json['name'] as String,
      args: json['args'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// Service for handling Live API tools
class ToolsService {
  static final Logger _logger = Logger('ToolsService');
  static final ToolsService _instance = ToolsService._internal();
  factory ToolsService() => _instance;
  ToolsService._internal();

  // Available function declarations
  final Map<String, Map<String, dynamic>> _functionDeclarations = {};
  
  // Function handlers
  final Map<String, Function> _functionHandlers = {};

  // Stream for tool calls
  final StreamController<List<ToolCall>> _toolCallController = 
      StreamController<List<ToolCall>>.broadcast();

  Stream<List<ToolCall>> get toolCallStream => _toolCallController.stream;

  /// Initialize the tools service with default functions
  void initialize() {
    _registerDefaultFunctions();
    _logger.info('ToolsService initialized');
  }

  /// Register default functions that the assistant can use
  void _registerDefaultFunctions() {
    // Weather function
    registerFunction(
      name: 'get_weather',
      description: 'Get current weather information for a location',
      parameters: {
        'type': 'object',
        'properties': {
          'location': {
            'type': 'string',
            'description': 'The city and state/country for weather lookup',
          },
          'units': {
            'type': 'string',
            'enum': ['celsius', 'fahrenheit'],
            'description': 'Temperature units to use',
            'default': 'celsius',
          },
        },
        'required': ['location'],
      },
      handler: _handleGetWeather,
    );

    // Time function
    registerFunction(
      name: 'get_current_time',
      description: 'Get the current time in a specific timezone',
      parameters: {
        'type': 'object',
        'properties': {
          'timezone': {
            'type': 'string',
            'description': 'Timezone identifier (e.g., America/New_York, Europe/London)',
            'default': 'UTC',
          },
        },
      },
      handler: _handleGetCurrentTime,
    );

    // Calculator function
    registerFunction(
      name: 'calculate',
      description: 'Perform mathematical calculations',
      parameters: {
        'type': 'object',
        'properties': {
          'expression': {
            'type': 'string',
            'description': 'Mathematical expression to evaluate (e.g., "2 + 3 * 4")',
          },
        },
        'required': ['expression'],
      },
      handler: _handleCalculate,
    );

    // Light control functions
    registerFunction(
      name: 'turn_on_lights',
      description: 'Turn on the lights in a room or area',
      parameters: {
        'type': 'object',
        'properties': {
          'room': {
            'type': 'string',
            'description': 'Room or area name (e.g., living room, bedroom)',
            'default': 'main room',
          },
          'brightness': {
            'type': 'number',
            'description': 'Brightness level from 0 to 100',
            'default': 100,
          },
        },
      },
      handler: _handleTurnOnLights,
    );

    registerFunction(
      name: 'turn_off_lights',
      description: 'Turn off the lights in a room or area',
      parameters: {
        'type': 'object',
        'properties': {
          'room': {
            'type': 'string',
            'description': 'Room or area name (e.g., living room, bedroom)',
            'default': 'main room',
          },
        },
      },
      handler: _handleTurnOffLights,
    );
  }

  /// Register a new function that the assistant can call
  void registerFunction({
    required String name,
    required String description,
    required Map<String, dynamic> parameters,
    required Function handler,
    String? behavior, // NON_BLOCKING for async execution
  }) {
    final functionDeclaration = {
      'name': name,
      'description': description,
      'parameters': parameters,
    };

    if (behavior != null) {
      functionDeclaration['behavior'] = behavior;
    }

    _functionDeclarations[name] = functionDeclaration;
    _functionHandlers[name] = handler;
    
    _logger.info('Registered function: $name');
  }

  /// Get tools configuration for Live API setup
  List<Map<String, dynamic>> getToolsConfig() {
    final tools = <Map<String, dynamic>>[];

    // Add function calling if we have any functions
    if (_functionDeclarations.isNotEmpty) {
      tools.add({
        'function_declarations': _functionDeclarations.values.toList(),
      });
    }

    // Add Google Search
    tools.add({'google_search': {}});

    // Add Code Execution
    tools.add({'code_execution': {}});

    return tools;
  }

  /// Handle tool calls from the model
  Future<List<FunctionResponse>> handleToolCalls(List<ToolCall> toolCalls) async {
    final responses = <FunctionResponse>[];

    for (final toolCall in toolCalls) {
      try {
        final handler = _functionHandlers[toolCall.name];
        if (handler != null) {
          final result = await handler(toolCall.args);
          responses.add(FunctionResponse(
            id: toolCall.id,
            name: toolCall.name,
            response: {'result': result},
          ));
        } else {
          _logger.warning('No handler found for function: ${toolCall.name}');
          responses.add(FunctionResponse(
            id: toolCall.id,
            name: toolCall.name,
            response: {'error': 'Function not implemented'},
          ));
        }
      } catch (e) {
        _logger.severe('Error executing function ${toolCall.name}: $e');
        responses.add(FunctionResponse(
          id: toolCall.id,
          name: toolCall.name,
          response: {'error': 'Execution failed: $e'},
        ));
      }
    }

    return responses;
  }

  /// Process tool call message from Live API
  void processToolCallMessage(Map<String, dynamic> message) {
    try {
      final toolCall = message['toolCall'] as Map<String, dynamic>?;
      if (toolCall == null) return;

      final functionCalls = toolCall['functionCalls'] as List<dynamic>?;
      if (functionCalls == null) return;

      final toolCalls = functionCalls
          .cast<Map<String, dynamic>>()
          .map((fc) => ToolCall.fromJson(fc))
          .toList();

      _toolCallController.add(toolCalls);
    } catch (e) {
      _logger.severe('Error processing tool call message: $e');
    }
  }

  // Default function handlers

  Future<String> _handleGetWeather(Map<String, dynamic> args) async {
    final location = args['location'] as String;
    final units = args['units'] as String? ?? 'celsius';
    
    // Simulate weather API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    final temp = units == 'celsius' ? '22°C' : '72°F';
    return 'The weather in $location is sunny with a temperature of $temp.';
  }

  Future<String> _handleGetCurrentTime(Map<String, dynamic> args) async {
    final timezone = args['timezone'] as String? ?? 'UTC';
    final now = DateTime.now();
    return 'Current time in $timezone: ${now.toString()}';
  }

  Future<String> _handleCalculate(Map<String, dynamic> args) async {
    final expression = args['expression'] as String;
    
    try {
      // Simple calculator - in real app, use a proper math parser
      final result = _evaluateSimpleExpression(expression);
      return 'The result of $expression is $result';
    } catch (e) {
      return 'Error calculating $expression: $e';
    }
  }

  Future<String> _handleTurnOnLights(Map<String, dynamic> args) async {
    final room = args['room'] as String? ?? 'main room';
    final brightness = args['brightness'] as num? ?? 100;
    
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Turned on lights in $room at ${brightness.round()}% brightness.';
  }

  Future<String> _handleTurnOffLights(Map<String, dynamic> args) async {
    final room = args['room'] as String? ?? 'main room';
    
    await Future.delayed(const Duration(milliseconds: 300));
    return 'Turned off lights in $room.';
  }

  /// Simple expression evaluator (replace with proper math parser in production)
  double _evaluateSimpleExpression(String expression) {
    // Remove spaces
    expression = expression.replaceAll(' ', '');
    
    // Simple regex-based calculator for demo purposes
    // In production, use a proper math expression parser
    final addPattern = RegExp(r'^(\d+(?:\.\d+)?)\+(\d+(?:\.\d+)?)$');
    final subtractPattern = RegExp(r'^(\d+(?:\.\d+)?)-(\d+(?:\.\d+)?)$');
    final multiplyPattern = RegExp(r'^(\d+(?:\.\d+)?)\*(\d+(?:\.\d+)?)$');
    final dividePattern = RegExp(r'^(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)$');
    
    if (addPattern.hasMatch(expression)) {
      final match = addPattern.firstMatch(expression)!;
      return double.parse(match.group(1)!) + double.parse(match.group(2)!);
    } else if (subtractPattern.hasMatch(expression)) {
      final match = subtractPattern.firstMatch(expression)!;
      return double.parse(match.group(1)!) - double.parse(match.group(2)!);
    } else if (multiplyPattern.hasMatch(expression)) {
      final match = multiplyPattern.firstMatch(expression)!;
      return double.parse(match.group(1)!) * double.parse(match.group(2)!);
    } else if (dividePattern.hasMatch(expression)) {
      final match = dividePattern.firstMatch(expression)!;
      final divisor = double.parse(match.group(2)!);
      if (divisor == 0) throw Exception('Division by zero');
      return double.parse(match.group(1)!) / divisor;
    } else {
      // Try to parse as a simple number
      return double.parse(expression);
    }
  }

  /// Dispose of resources
  void dispose() {
    _toolCallController.close();
    _functionDeclarations.clear();
    _functionHandlers.clear();
    _logger.info('ToolsService disposed');
  }
}