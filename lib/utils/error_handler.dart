import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Comprehensive error handling utility for the MoonTalk app
class ErrorHandler {
  static final Logger _logger = Logger('ErrorHandler');

  /// Show error snackbar with appropriate styling
  static void showErrorSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: Colors.white,
                onPressed: onActionPressed ?? () {},
              )
            : null,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show warning snackbar
  static void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Show error dialog with detailed information
  static Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? details,
    List<Widget>? actions,
  }) async {
    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.error_outline,
            color: Colors.red.shade600,
            size: 32,
          ),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (details != null) ...[
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('Details'),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      details,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: actions ?? [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Handle and categorize different types of errors
  static String categorizeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Network connection error. Please check your internet connection and try again.';
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('denied')) {
      return 'Permission denied. Please check app permissions in your device settings.';
    }

    // API key errors
    if (errorString.contains('api key') ||
        errorString.contains('unauthorized') ||
        errorString.contains('401')) {
      return 'Invalid API key. Please check your Google AI Studio API key.';
    }

    // Audio errors
    if (errorString.contains('audio') ||
        errorString.contains('microphone') ||
        errorString.contains('recording')) {
      return 'Audio error. Please check microphone permissions and try again.';
    }

    // WebSocket errors
    if (errorString.contains('websocket') ||
        errorString.contains('ws://') ||
        errorString.contains('wss://')) {
      return 'WebSocket connection error. Please check your network and try reconnecting.';
    }

    // Rate limiting
    if (errorString.contains('rate limit') ||
        errorString.contains('quota') ||
        errorString.contains('429')) {
      return 'API rate limit exceeded. Please wait a moment and try again.';
    }

    // Generic error
    return 'An unexpected error occurred. Please try again.';
  }

  /// Log error with appropriate level
  static void logError(
    String message,
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final logMessage = context != null 
        ? '$message - Context: $context'
        : message;

    if (error != null) {
      _logger.severe(logMessage, error, stackTrace);
    } else {
      _logger.severe(logMessage);
    }
  }

  /// Handle API errors specifically
  static String handleApiError(dynamic error) {
    final errorString = error.toString();
    
    // Parse structured API errors
    if (errorString.contains('INVALID_ARGUMENT')) {
      return 'Invalid request format. Please try again.';
    }
    
    if (errorString.contains('UNAUTHENTICATED')) {
      return 'Authentication failed. Please check your API key.';
    }
    
    if (errorString.contains('PERMISSION_DENIED')) {
      return 'Access denied. Your API key may not have the required permissions.';
    }
    
    if (errorString.contains('RESOURCE_EXHAUSTED')) {
      return 'API quota exceeded. Please try again later.';
    }
    
    if (errorString.contains('UNAVAILABLE')) {
      return 'Service temporarily unavailable. Please try again later.';
    }
    
    return categorizeError(error);
  }

  /// Show retry dialog
  static Future<bool> showRetryDialog(
    BuildContext context, {
    required String title,
    required String message,
    String retryButtonText = 'Retry',
    String cancelButtonText = 'Cancel',
  }) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.refresh,
            color: Colors.orange.shade600,
            size: 32,
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelButtonText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(retryButtonText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  /// Show loading dialog
  static Future<T?> showLoadingDialog<T>(
    BuildContext context, {
    required String message,
    required Future<T> Function() operation,
  }) async {
    if (!context.mounted) return null;

    // Show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        );
      },
    );

    try {
      // Perform operation
      final result = await operation();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      return result;
    } catch (error, stackTrace) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Log error
      logError('Operation failed', error, stackTrace: stackTrace);
      
      // Show error
      if (context.mounted) {
        showErrorSnackBar(context, categorizeError(error));
      }
      
      return null;
    }
  }
}

/// Extension to safely execute async operations
extension SafeAsync on Future {
  Future<T?> safely<T>(BuildContext context, {String? errorMessage}) async {
    try {
      return await this as T;
    } catch (error, stackTrace) {
      ErrorHandler.logError(
        errorMessage ?? 'Async operation failed',
        error,
        stackTrace: stackTrace,
      );
      
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          errorMessage ?? ErrorHandler.categorizeError(error),
        );
      }
      
      return null;
    }
  }
}