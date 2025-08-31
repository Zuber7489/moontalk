import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../providers/assistant_provider.dart';
import '../services/session_manager.dart';
import '../services/ephemeral_token_service.dart';

/// Screen for managing Live API sessions
class SessionManagementScreen extends StatefulWidget {
  const SessionManagementScreen({Key? key}) : super(key: key);

  @override
  State<SessionManagementScreen> createState() => _SessionManagementScreenState();
}

class _SessionManagementScreenState extends State<SessionManagementScreen> {
  Map<String, dynamic>? _sessionInfo;
  bool _useEphemeralTokens = false;
  bool _enableSessionManagement = true;
  bool _enableContextCompression = true;

  @override
  void initState() {
    super.initState();
    _refreshSessionInfo();
  }

  void _refreshSessionInfo() {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    setState(() {
      _sessionInfo = provider.getSessionInfo();
      _useEphemeralTokens = _sessionInfo?['connection_config']?['use_ephemeral_tokens'] ?? false;
      _enableSessionManagement = _sessionInfo?['connection_config']?['session_management_enabled'] ?? true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshSessionInfo,
          ),
        ],
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Session Status Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Status',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow('Connection', provider.isConnected ? 'Connected' : 'Disconnected'),
                        _buildStatusRow('State', provider.currentState.name),
                        _buildStatusRow('Model', provider.selectedModel),
                        if (_sessionInfo?['session_stats'] != null) ...[
                          const Divider(),
                          _buildStatusRow('Session Active', _sessionInfo!['session_stats']['active'].toString()),
                          if (_sessionInfo!['session_stats']['duration'] != null)
                            _buildStatusRow('Duration', '${_sessionInfo!['session_stats']['duration']} minutes'),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Token Management Card
                if (_useEphemeralTokens) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ephemeral Token Status',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          if (_sessionInfo?['token_status'] != null) ...[
                            _buildStatusRow('Has Token', _sessionInfo!['token_status']['hasToken'].toString()),
                            _buildStatusRow('Can Start Session', _sessionInfo!['token_status']['canStartNewSession'].toString()),
                            _buildStatusRow('Valid', _sessionInfo!['token_status']['isValid'].toString()),
                            _buildStatusRow('New Session Time Left', '${_sessionInfo!['token_status']['newSessionTimeLeft']} min'),
                            _buildStatusRow('Total Time Left', '${_sessionInfo!['token_status']['totalTimeLeft']} min'),
                            _buildStatusRow('Uses Remaining', _sessionInfo!['token_status']['uses'].toString()),
                          ] else
                            const Text('No token information available'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Configuration Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Configuration',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Use Ephemeral Tokens'),
                          subtitle: const Text('Enhanced security for client-side deployments'),
                          value: _useEphemeralTokens,
                          onChanged: provider.isConnected ? null : (value) {
                            setState(() {
                              _useEphemeralTokens = value;
                            });
                            provider.enableEphemeralTokens(value);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Session Management'),
                          subtitle: const Text('Enable session resumption and compression'),
                          value: _enableSessionManagement,
                          onChanged: provider.isConnected ? null : (value) {
                            setState(() {
                              _enableSessionManagement = value;
                            });
                            provider.enableSessionManagement(value);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Context Compression'),
                          subtitle: const Text('Enable unlimited session duration'),
                          value: _enableContextCompression,
                          onChanged: provider.isConnected ? null : (value) {
                            setState(() {
                              _enableContextCompression = value;
                            });
                            // Update compression config
                            _updateCompressionConfig(value);
                          },
                        ),
                        if (provider.isConnected)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              'Disconnect to change configuration',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Session Actions Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Session Actions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: provider.isConnected ? null : () => _connectWithCurrentSettings(provider),
                              icon: const Icon(Icons.connect_without_contact),
                              label: const Text('Connect'),
                            ),
                            ElevatedButton.icon(
                              onPressed: provider.isConnected ? provider.disconnect : null,
                              icon: const Icon(Icons.disconnect),
                              label: const Text('Disconnect'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _refreshSessionInfo,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Refresh'),
                            ),
                            if (_useEphemeralTokens)
                              ElevatedButton.icon(
                                onPressed: () => _createNewToken(provider),
                                icon: const Icon(Icons.token),
                                label: const Text('New Token'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Session Data Card
                if (_sessionInfo != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Session Data (JSON)',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () => _copySessionData(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              const JsonEncoder.withIndent('  ').convert(_sessionInfo),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _connectWithCurrentSettings(AssistantProvider provider) async {
    try {
      final success = await provider.connect(
        useEphemeralTokens: _useEphemeralTokens,
        enableSessionManagement: _enableSessionManagement,
      );
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected successfully with session management'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshSessionInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _createNewToken(AssistantProvider provider) async {
    try {
      final tokenService = provider.tokenService;
      final newToken = await tokenService.createClientToken(
        apiKey: provider.apiKey ?? '',
        model: provider.selectedModel,
      );
      
      if (newToken != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New token created, valid for ${newToken.newSessionTimeLeft.inMinutes} minutes'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshSessionInfo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create token: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateCompressionConfig(bool enabled) {
    final provider = Provider.of<AssistantProvider>(context, listen: false);
    final compressionConfig = ContextWindowCompressionConfig(
      enabled: enabled,
      triggerTokens: 25000,
      useSlidingWindow: true,
    );
    
    provider.sessionManager.updateCompressionConfig(compressionConfig);
  }

  void _copySessionData() {
    if (_sessionInfo != null) {
      // In a real app, you'd use a clipboard plugin
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session data would be copied to clipboard'),
        ),
      );
    }
  }
}