import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/assistant_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Model Selection
              _buildSection(
                title: 'Model Configuration',
                children: [
                  _buildModelSelector(provider),
                  const SizedBox(height: 12),
                  _buildAudioModeToggle(provider),
                ],
              ),

              const SizedBox(height: 24),

              // Connection Status
              _buildSection(
                title: 'Connection',
                children: [
                  _buildConnectionStatus(provider),
                  const SizedBox(height: 12),
                  _buildConnectionActions(context, provider),
                ],
              ),

              const SizedBox(height: 24),

              // About
              _buildSection(
                title: 'About',
                children: [
                  _buildAboutInfo(),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildModelSelector(AssistantProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Model',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: provider.selectedModel,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: AssistantProvider.availableModels.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Tooltip(
                message: _getModelDescription(model),
                child: Text(
                  _getModelDisplayName(model),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
          onChanged: provider.isConnected ? null : (model) {
            if (model != null) {
              provider.changeModel(model);
            }
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getModelDescription(provider.selectedModel),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (provider.isConnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Disconnect to change model',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioModeToggle(AssistantProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Native Audio Mode',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Use native audio generation for more natural speech',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: provider.useNativeAudio,
          onChanged: provider.isConnected ? null : (value) {
            provider.toggleAudioMode();
          },
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(AssistantProvider provider) {
    final isConnected = provider.isConnected;
    final statusColor = isConnected ? Colors.green : Colors.grey;
    
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: statusColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                isConnected 
                    ? 'Ready to receive voice and text input'
                    : 'Tap connect to start chatting',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionActions(BuildContext context, AssistantProvider provider) {
    return Row(
      children: [
        if (!provider.isConnected)
          Expanded(
            child: ElevatedButton(
              onPressed: provider.isInitialized ? () async {
                final success = await provider.connect();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connected successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } : null,
              child: const Text('Connect'),
            ),
          ),
        if (provider.isConnected) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                await provider.disconnect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Disconnected'),
                    ),
                  );
                }
              },
              child: const Text('Disconnect'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => provider.clearConversation(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade700,
              ),
              child: const Text('Clear Chat'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('MoonTalk Assistant'),
          subtitle: Text('Version 1.0.0'),
        ),
        const SizedBox(height: 8),
        Text(
          'A real-time virtual assistant powered by Google\'s Live API. '
          'Experience natural voice conversations with advanced AI.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 16),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.code),
          title: Text('Built with Flutter'),
          subtitle: Text('Using Google Generative AI Live API'),
        ),
        const SizedBox(height: 8),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.security),
          title: Text('Privacy'),
          subtitle: Text('Your conversations are processed securely'),
        ),
      ],
    );
  }

  String _getModelDisplayName(String model) {
    switch (model) {
      case 'gemini-2.5-flash-preview-native-audio-dialog':
        return 'Gemini 2.5 Flash (Native Audio)';
      case 'gemini-2.5-flash-exp-native-audio-thinking-dialog':
        return 'Gemini 2.5 Flash Experimental (Thinking)';
      case 'gemini-live-2.5-flash-preview':
        return 'Gemini Live 2.5 Flash';
      case 'gemini-2.0-flash-live-001':
        return 'Gemini 2.0 Flash Live';
      default:
        return model;
    }
  }

  String _getModelDescription(String model) {
    if (model.contains('native-audio')) {
      return 'Natural speech with emotion-aware dialogue';
    } else if (model.contains('thinking')) {
      return 'Advanced reasoning with thinking process';
    } else if (model.contains('live')) {
      return 'Half-cascade audio with better reliability';
    } else {
      return 'Standard live conversation model';
    }
  }
}