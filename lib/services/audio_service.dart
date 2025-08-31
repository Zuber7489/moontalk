import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';

class AudioService {
  static final Logger _logger = Logger('AudioService');
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  
  StreamController<Uint8List>? _audioStreamController;
  StreamController<double>? _volumeLevelController;
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;

  // Stream for real-time audio data (PCM format for Live API)
  Stream<Uint8List>? get audioStream => _audioStreamController?.stream;
  
  // Stream for volume level monitoring
  Stream<double>? get volumeLevelStream => _volumeLevelController?.stream;
  
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  /// Check if microphone permission is granted
  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status == PermissionStatus.granted;
  }

  /// Request microphone permission explicitly
  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (status == PermissionStatus.granted) {
        _logger.info('Microphone permission granted');
        return true;
      } else {
        _logger.warning('Microphone permission denied: $status');
        return false;
      }
    } catch (e) {
      _logger.severe('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Initialize the audio service and request permissions
  Future<bool> initialize() async {
    try {
      _logger.info('Initializing AudioService...');
      
      // Request microphone permission first
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus != PermissionStatus.granted) {
        _logger.warning('Microphone permission not granted: $microphoneStatus');
        
        // Check if permission is permanently denied
        if (microphoneStatus == PermissionStatus.permanentlyDenied) {
          _logger.severe('Microphone permission permanently denied');
          return false;
        }
        
        // Try to request again if denied
        final retryStatus = await Permission.microphone.request();
        if (retryStatus != PermissionStatus.granted) {
          _logger.severe('Microphone permission denied after retry: $retryStatus');
          return false;
        }
      }
      
      _logger.info('Microphone permission granted');

      // Initialize flutter_sound
      _audioRecorder = FlutterSoundRecorder();
      _audioPlayer = FlutterSoundPlayer();
      
      await _audioRecorder!.openRecorder();
      await _audioPlayer!.openPlayer();
      
      // Set up audio session
      try {
        // Audio session configuration is handled by flutter_sound internally
        _logger.info('Audio session will be configured by flutter_sound');
      } catch (e) {
        _logger.warning('Audio session setup info: $e');
        // Continue anyway, audio might still work
      }

      // Initialize stream controllers
      _audioStreamController = StreamController<Uint8List>.broadcast();
      _volumeLevelController = StreamController<double>.broadcast();

      _logger.info('AudioService initialized successfully');
      return true;
    } catch (e) {
      _logger.severe('Failed to initialize AudioService: $e');
      return false;
    }
  }

  /// Start recording audio with Live API compatible format
  /// Format: 16-bit PCM, 16kHz, mono
  Future<bool> startRecording() async {
    if (_isRecording) {
      _logger.warning('Already recording');
      return false;
    }

    // Check microphone permission first
    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) {
      _logger.warning('Microphone permission not granted');
      final granted = await requestMicrophonePermission();
      if (!granted) {
        return false;
      }
    }

    try {
      _logger.info('Starting audio recording...');

      // Check if the recorder is available
      if (_audioRecorder == null) {
        _logger.warning('Recorder not initialized');
        return false;
      }
      
      // Always try to open the recorder
      try {
        await _audioRecorder!.openRecorder();
        _logger.info('Recorder opened successfully');
      } catch (e) {
        _logger.warning('Recorder already open or error opening: $e');
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      // Start recording with Live API compatible settings
      await _audioRecorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000, // Live API requires 16kHz
        numChannels: 1, // Mono
      );
      
      _isRecording = true;

      // Start monitoring volume levels (optional for UI feedback)
      _startVolumeMonitoring();

      _logger.info('Recording started successfully');
      return true;
    } catch (e) {
      _logger.severe('Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the audio data
  Future<Uint8List?> stopRecording() async {
    if (!_isRecording) {
      _logger.warning('Not currently recording');
      return null;
    }

    try {
      _logger.info('Stopping audio recording...');

      // Stop recording
      final path = await _audioRecorder!.stopRecorder();
      _isRecording = false;

      if (path == null || path.isEmpty) {
        _logger.warning('Recording path is null or empty');
        return null;
      }

      // Read the recorded file
      final file = File(path);
      if (!await file.exists()) {
        _logger.warning('Recorded file does not exist');
        return null;
      }

      final audioBytes = await file.readAsBytes();
      
      // Convert WAV to PCM format for Live API
      final pcmData = await _convertToPCM(audioBytes);
      
      // Clean up the temporary file
      await file.delete();

      _logger.info('Recording stopped successfully, got ${pcmData.length} bytes');
      return pcmData;
    } catch (e) {
      _logger.severe('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Convert WAV audio to PCM format for Live API
  Future<Uint8List> _convertToPCM(Uint8List wavData) async {
    try {
      // Validate WAV header and extract format information
      if (wavData.length <= 44) {
        _logger.warning('WAV file too small, returning as-is');
        return wavData;
      }

      // Check WAV header signature
      final riffHeader = String.fromCharCodes(wavData.sublist(0, 4));
      final waveHeader = String.fromCharCodes(wavData.sublist(8, 12));
      
      if (riffHeader != 'RIFF' || waveHeader != 'WAVE') {
        _logger.warning('Invalid WAV format, returning as-is');
        return wavData;
      }

      // Extract audio format information from WAV header
      final audioFormat = _readUint16(wavData, 20);
      final channels = _readUint16(wavData, 22);
      final sampleRate = _readUint32(wavData, 24);
      final bitsPerSample = _readUint16(wavData, 34);
      
      _logger.info('WAV format: ${audioFormat}, channels: ${channels}, sampleRate: ${sampleRate}, bits: ${bitsPerSample}');
      
      // Validate format requirements for Live API
      if (audioFormat != 1) { // PCM format
        _logger.warning('Non-PCM audio format detected: $audioFormat');
      }
      
      if (channels != 1) {
        _logger.warning('Multi-channel audio detected, Live API expects mono');
      }
      
      if (sampleRate != 16000) {
        _logger.warning('Sample rate $sampleRate detected, Live API expects 16kHz');
      }
      
      if (bitsPerSample != 16) {
        _logger.warning('Bit depth $bitsPerSample detected, Live API expects 16-bit');
      }

      // Extract PCM data (skip WAV header, typically 44 bytes)
      final pcmData = wavData.sublist(44);
      _logger.info('Extracted ${pcmData.length} bytes of PCM data');
      
      return pcmData;
    } catch (e) {
      _logger.warning('Failed to convert to PCM, returning original data: $e');
      return wavData;
    }
  }
  
  /// Read 16-bit unsigned integer from byte array (little-endian)
  int _readUint16(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }
  
  /// Read 32-bit unsigned integer from byte array (little-endian)
  int _readUint32(Uint8List data, int offset) {
    return data[offset] | 
           (data[offset + 1] << 8) | 
           (data[offset + 2] << 16) | 
           (data[offset + 3] << 24);
  }

  /// Play audio data received from Live API (24kHz format)
  Future<bool> playAudio(Uint8List audioData) async {
    // Stop any current playback first
    if (_isPlaying) {
      await stopPlayback();
      // Small delay to ensure previous playback is fully stopped
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      _logger.info('Playing audio data (${audioData.length} bytes)...');

      // Create a temporary file for playback
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/playback_${DateTime.now().millisecondsSinceEpoch}.wav');
      
      // Convert PCM to WAV format for playback
      final wavData = _createWavFile(audioData, 24000); // Live API outputs 24kHz
      await tempFile.writeAsBytes(wavData);

      _isPlaying = true;
      
      // Use flutter_sound for playback with completion callback
      await _audioPlayer!.startPlayer(
        fromURI: tempFile.path,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          _isPlaying = false;
          _logger.info('Audio playback completed');
          // Clean up temporary file
          tempFile.delete().catchError((e) => _logger.warning('Failed to delete temp file: $e'));
        },
      );

      _logger.info('Audio playbook started successfully');
      return true;
    } catch (e) {
      _logger.severe('Failed to play audio: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Create WAV file from PCM data
  Uint8List _createWavFile(Uint8List pcmData, int sampleRate) {
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;
    
    final header = <int>[
      // "RIFF"
      0x52, 0x49, 0x46, 0x46,
      // File size - 8
      (fileSize) & 0xFF, (fileSize >> 8) & 0xFF, (fileSize >> 16) & 0xFF, (fileSize >> 24) & 0xFF,
      // "WAVE"
      0x57, 0x41, 0x56, 0x45,
      // "fmt "
      0x66, 0x6D, 0x74, 0x20,
      // Chunk size (16)
      0x10, 0x00, 0x00, 0x00,
      // Audio format (PCM = 1)
      0x01, 0x00,
      // Number of channels (1 = mono)
      0x01, 0x00,
      // Sample rate
      (sampleRate) & 0xFF, (sampleRate >> 8) & 0xFF, (sampleRate >> 16) & 0xFF, (sampleRate >> 24) & 0xFF,
      // Byte rate (sampleRate * numChannels * bitsPerSample / 8)
      (sampleRate * 2) & 0xFF, (sampleRate * 2 >> 8) & 0xFF, (sampleRate * 2 >> 16) & 0xFF, (sampleRate * 2 >> 24) & 0xFF,
      // Block align (numChannels * bitsPerSample / 8)
      0x02, 0x00,
      // Bits per sample (16)
      0x10, 0x00,
      // "data"
      0x64, 0x61, 0x74, 0x61,
      // Data size
      (dataSize) & 0xFF, (dataSize >> 8) & 0xFF, (dataSize >> 16) & 0xFF, (dataSize >> 24) & 0xFF,
    ];

    return Uint8List.fromList(header + pcmData);
  }

  /// Stop audio playback
  Future<void> stopPlayback() async {
    if (_isPlaying && _audioPlayer != null) {
      try {
        await _audioPlayer!.stopPlayer();
        _isPlaying = false;
        _logger.info('Audio playback stopped');
      } catch (e) {
        _logger.warning('Error stopping playback: $e');
        // Force reset the playing state even if stop failed
        _isPlaying = false;
      }
    }
  }

  /// Start monitoring volume levels for UI feedback
  void _startVolumeMonitoring() {
    // Note: Real volume monitoring would require platform-specific implementation
    // This is a simplified version for demonstration
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Simulate volume level (in real implementation, you'd get actual audio levels)
      final volume = 0.5 + (DateTime.now().millisecond % 100) / 200.0;
      _volumeLevelController?.add(volume);
    });
  }

  /// Dispose of resources
  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      if (_isPlaying) {
        await stopPlayback();
      }
      
      try {
        if (_audioRecorder != null) {
          await _audioRecorder!.closeRecorder();
        }
        if (_audioPlayer != null) {
          await _audioPlayer!.closePlayer();
        }
      } catch (e) {
        _logger.warning('Error closing audio components: $e');
      }
      
      await _audioStreamController?.close();
      await _volumeLevelController?.close();
      
      _logger.info('AudioService disposed');
    } catch (e) {
      _logger.severe('Error disposing AudioService: $e');
    }
  }
}