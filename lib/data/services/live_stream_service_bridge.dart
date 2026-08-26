import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class LiveStreamServiceBridge {
  static const MethodChannel _channel = MethodChannel('com.vibelive.app/live_service');

  // Callback to listen for PiP changes from native side
  static Function(bool)? _onPiPChangedCallback;

  static void initialize(Function(bool) onPiPChanged) {
    _onPiPChangedCallback = onPiPChanged;
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPiPChanged':
        final bool isInPiP = call.arguments['isInPiP'] ?? false;
        if (_onPiPChangedCallback != null) {
          _onPiPChangedCallback!(isInPiP);
        }
        break;
      default:
        debugPrint('Unknown method channel call: ${call.method}');
    }
  }

  /// Start Foreground Service (Android only)
  static Future<bool> startLiveService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bool result = await _channel.invokeMethod('startLiveService');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error starting foreground service: $e');
      return false;
    }
  }

  /// Stop Foreground Service (Android only)
  static Future<bool> stopLiveService() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bool result = await _channel.invokeMethod('stopLiveService');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error stopping foreground service: $e');
      return false;
    }
  }

  /// Request to enter PiP mode (Android only)
  static Future<bool> enterPiP() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bool result = await _channel.invokeMethod('enterPiP');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error entering PiP mode: $e');
      return false;
    }
  }

  /// Check if PiP is supported on the current device
  static Future<bool> isPiPSupported() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bool result = await _channel.invokeMethod('isPiPSupported');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error checking PiP support: $e');
      return false;
    }
  }
}
