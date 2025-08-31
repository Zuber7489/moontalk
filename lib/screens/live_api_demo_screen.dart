import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';
import '../services/live_api_service.dart';

/// Demo screen showing advanced Live API features
class LiveApiDemoScreen extends StatefulWidget {
  const LiveApiDemoScreen({Key? key}) : super(key: key);

  @override
  State<LiveApiDemoScreen> createState() => _LiveApiDemoScreenState();
}

class _LiveApiDemoScreenState extends State<LiveApiDemoScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live API Features Demo'),
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Connection Status
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connection Status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              provider.isConnected ? Icons.wifi : Icons.wifi_off,
                              color: provider.isConnected ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              provider.isConnected ? 'Connected' : 'Disconnected',
                            ),
                          ],
                        ),
                        Text('Model: ${provider.selectedModel}'),
                        Text('State: ${provider.currentState.name}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Demo Functions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Demo Functions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "What's the weather like in New York?")
                                  : null,
                              child: const Text('Weather'),
                            ),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "What time is it in Tokyo?")
                                  : null,
                              child: const Text('Time'),
                            ),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "Calculate 15 * 23 + 7")
                                  : null,
                              child: const Text('Calculator'),
                            ),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "Turn on the lights in the living room")
                                  : null,
                              child: const Text('Smart Home'),
                            ),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "Search for recent news about AI")
                                  : null,
                              child: const Text('Web Search'),
                            ),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendDemoMessage(provider, "Write Python code to find the largest prime number under 100")
                                  : null,
                              child: const Text('Code Execution'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Model Selector
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Model Configuration',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<String>(
                          value: provider.selectedModel,
                          isExpanded: true,
                          onChanged: provider.isConnected ? null : (String? newValue) {
                            if (newValue != null) {
                              provider.changeModel(newValue);
                            }
                          },
                          items: AssistantProvider.availableModels
                              .map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          provider.isConnected 
                              ? 'Disconnect to change model'
                              : 'Select a model and connect',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Custom Message Input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Send Custom Message',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your message...',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: provider.isConnected,
                                onSubmitted: (text) => _sendCustomMessage(provider, text),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: provider.isConnected
                                  ? () => _sendCustomMessage(provider, _messageController.text)
                                  : null,
                              child: const Text('Send'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Connection Controls
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.isConnected ? null : () {
                          if (provider.isInitialized) {
                            provider.connect();
                          } else {
                            _showApiKeyDialog();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          provider.isInitialized ? 'Connect' : 'Set API Key',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.isConnected ? provider.disconnect : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _sendDemoMessage(AssistantProvider provider, String message) {
    provider.sendTextMessage(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent: $message'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _sendCustomMessage(AssistantProvider provider, String message) {
    if (message.trim().isNotEmpty) {
      provider.sendTextMessage(message);
      _messageController.clear();
    }
  }

  void _showApiKeyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Key Required'),
        content: const Text(
          'Please set your Google AI Studio API key to use the Live API features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}