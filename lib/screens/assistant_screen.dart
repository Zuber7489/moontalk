import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../widgets/microphone_button.dart';
import '../widgets/conversation_display.dart';
import '../widgets/text_input_widget.dart';
import '../services/live_api_service.dart';
import 'settings_screen.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({Key? key}) : super(key: key);

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiKeyAndPrompt();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkApiKeyAndPrompt() {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    if (!provider.isInitialized) {
      _showApiKeyDialog();
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ApiKeyDialog(),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleMicrophonePress() async {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    
    if (!provider.isInitialized) {
      _showApiKeyDialog();
      return;
    }
    
    if (!provider.isConnected && provider.currentState == AssistantState.idle) {
      // Show loading indicator while connecting
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Connecting to Live API...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
      
      final connected = await provider.connect();
      if (!connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          _showErrorSnackBar('Failed to connect. Please check your internet connection.');
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      return;
    }

    if (provider.isRecording) {
      provider.stopVoiceInput();
    } else if (provider.currentState == AssistantState.connected) {
      provider.startVoiceInput();
    }
  }

  void _handleTextMessage(String message) {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    provider.sendTextMessage(message).then((_) {
      // Scroll to bottom after sending message
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    });
  }

  void _showErrorSnackBar(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MoonTalk Assistant',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, child) {
          // Show error messages
          if (provider.currentError != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showErrorSnackBar(provider.currentError!);
              provider.clearError();
            });
          }

          // Auto-scroll when new messages arrive
          if (provider.conversationHistory.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }

          return Column(
            children: [
              // Status bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: StatusIndicator(
                    state: provider.currentState,
                    message: provider.statusMessage,
                  ),
                ),
              ),

              // Conversation area
              Expanded(
                child: Stack(
                  children: [
                    ConversationDisplay(
                      messages: provider.conversationHistory,
                      scrollController: _scrollController,
                    ),
                    
                    // Typing indicator
                    if (provider.currentState == AssistantState.processing ||
                        provider.currentState == AssistantState.speaking)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: TypingIndicator(
                          isVisible: provider.currentState == AssistantState.processing,
                        ),
                      ),
                  ],
                ),
              ),

              // Volume indicator (when recording)
              if (provider.isRecording)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: VolumeIndicator(
                    level: provider.volumeLevel,
                    isActive: provider.isRecording,
                  ),
                ),

              // Quick actions
              QuickActionButtons(
                canClear: provider.conversationHistory.isNotEmpty,
                canStop: provider.currentState == AssistantState.speaking,
                onClearConversation: () => _showClearConfirmation(provider),
                onStopSpeaking: provider.stopResponse,
              ),

              // Main controls
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Microphone button
                    MicrophoneButton(
                      currentState: provider.currentState,
                      isRecording: provider.isRecording,
                      volumeLevel: provider.volumeLevel,
                      onPressed: _handleMicrophonePress,
                    ),
                  ],
                ),
              ),

              // Text input
              TextInputWidget(
                onSendMessage: _handleTextMessage,
                isEnabled: provider.isConnected && 
                          provider.currentState != AssistantState.processing,
                hintText: provider.isConnected 
                    ? 'Type your message...'
                    : 'Connect to start chatting...',
              ),
            ],
          );
        },
      ),
    );
  }

  void _showClearConfirmation(AssistantProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Conversation'),
        content: const Text(
          'Are you sure you want to clear the entire conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.clearConversation();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for entering API key
class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({Key? key}) : super(key: key);

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your API key'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AssistantProvider>(context, listen: false);
      final success = await provider.initialize(apiKey);
      
      if (success && mounted) {
        Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid API key or initialization failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter your Google AI Studio API key to start using MoonTalk:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'AIza...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            enabled: !_isLoading,
            onSubmitted: (_) => _handleSubmit(),
          ),
          const SizedBox(height: 12),
          Text(
            'Get your API key from Google AI Studio (aistudio.google.com)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Initialize'),
        ),
      ],
    );
  }
}