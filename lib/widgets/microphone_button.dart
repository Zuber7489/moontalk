import 'package:flutter/material.dart';
import '../services/live_api_service.dart';

/// Animated microphone button for voice input
class MicrophoneButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final AssistantState currentState;
  final bool isRecording;
  final double? volumeLevel;

  const MicrophoneButton({
    Key? key,
    this.onPressed,
    required this.currentState,
    this.isRecording = false,
    this.volumeLevel,
  }) : super(key: key);

  @override
  State<MicrophoneButton> createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends State<MicrophoneButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(MicrophoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getButtonColor() {
    switch (widget.currentState) {
      case AssistantState.idle:
        return Colors.blue.shade300;
      case AssistantState.connecting:
        return Colors.orange;
      case AssistantState.connected:
        return Colors.green;
      case AssistantState.listening:
        return Colors.red;
      case AssistantState.processing:
        return Colors.amber;
      case AssistantState.speaking:
        return Colors.purple;
      case AssistantState.error:
        return Colors.red.shade800;
    }
  }

  IconData _getButtonIcon() {
    switch (widget.currentState) {
      case AssistantState.idle:
        return Icons.mic_off;
      case AssistantState.connecting:
        return Icons.sync;
      case AssistantState.connected:
        return Icons.mic;
      case AssistantState.listening:
        return Icons.mic;
      case AssistantState.processing:
        return Icons.hourglass_empty;
      case AssistantState.speaking:
        return Icons.volume_up;
      case AssistantState.error:
        return Icons.error;
    }
  }

  bool _isButtonEnabled() {
    return widget.currentState == AssistantState.connected ||
           widget.currentState == AssistantState.listening ||
           (widget.currentState == AssistantState.idle && widget.onPressed != null);
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _isButtonEnabled() ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _scaleAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: widget.isRecording
                    ? [
                        BoxShadow(
                          color: _getButtonColor().withOpacity(0.3),
                          blurRadius: 20 * _pulseAnimation.value,
                          spreadRadius: 5 * _pulseAnimation.value,
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Material(
                shape: const CircleBorder(),
                color: _getButtonColor(),
                elevation: _isButtonEnabled() ? 8 : 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _isButtonEnabled() ? widget.onPressed : null,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getButtonIcon(),
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Status indicator widget
class StatusIndicator extends StatelessWidget {
  final AssistantState state;
  final String? message;

  const StatusIndicator({
    Key? key,
    required this.state,
    this.message,
  }) : super(key: key);

  String _getStatusText() {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    
    switch (state) {
      case AssistantState.idle:
        return 'Tap to connect';
      case AssistantState.connecting:
        return 'Connecting...';
      case AssistantState.connected:
        return 'Ready to chat';
      case AssistantState.listening:
        return 'Listening...';
      case AssistantState.processing:
        return 'Processing...';
      case AssistantState.speaking:
        return 'Assistant speaking...';
      case AssistantState.error:
        return 'Error occurred';
    }
  }

  Color _getStatusColor() {
    switch (state) {
      case AssistantState.idle:
        return Colors.grey;
      case AssistantState.connecting:
        return Colors.orange;
      case AssistantState.connected:
        return Colors.green;
      case AssistantState.listening:
        return Colors.blue;
      case AssistantState.processing:
        return Colors.amber;
      case AssistantState.speaking:
        return Colors.purple;
      case AssistantState.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: TextStyle(
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Volume level indicator for voice input
class VolumeIndicator extends StatelessWidget {
  final double level;
  final bool isActive;

  const VolumeIndicator({
    Key? key,
    required this.level,
    this.isActive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 200,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}