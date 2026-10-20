import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Talks to the Android foreground service and alert notifications.
/// On iPhone these calls do nothing (see the iOS phase).
class BackgroundService {
  BackgroundService._();
  static final instance = BackgroundService._();

  static const _channel = MethodChannel('hearable/background');

  bool get supported => Platform.isAndroid;

  /// Returns true if background monitoring is running.
  Future<bool> start() async {
    if (!supported) return false;
    try {
      return await _channel.invokeMethod<bool>('startService') ?? false;
    } catch (e) {
      debugPrint('HearAble: background service could not start: $e');
      return false;
    }
  }

  Future<void> stop() => _call('stopService');

  /// Heads-up / full-screen notification when the app is not visible.
  Future<void> showAlert(String title, String body) =>
      _call('showAlert', {'title': title, 'body': body});

  Future<void> alertFinished() => _call('alertFinished');

  /// e.g. "Monitoring stopped" when the user can't see the app.
  Future<void> showStatus(String title, String body) =>
      _call('showStatus', {'title': title, 'body': body});

  Future<bool> canUseFullScreenAlerts() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openFullScreenSettings() =>
      _call('openFullScreenIntentSettings');

  Future<void> _call(String method, [Map<String, dynamic>? args]) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod(method, args);
    } catch (e) {
      debugPrint('HearAble: $method failed: $e');
    }
  }
}