import 'dart:async';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

/// Vibration and flashlight alerts. Every call fails safely on phones
/// without a vibrator or flashlight (e.g. the emulator).
class AlertEffects {
  AlertEffects._();
  static final instance = AlertEffects._();
    /// Set from Settings.
  static bool vibrationEnabled = true;
  static bool flashlightEnabled = true;

  Timer? _flashTimer;
  bool _torchOn = false;

  Future<void> vibrate({bool urgent = false}) async {
    if (!vibrationEnabled) return;
    try {
      if (await Vibration.hasVibrator() != true) return;
      await Vibration.vibrate(
        pattern: urgent
            ? [0, 800, 300, 800, 300, 800, 300, 800]
            : [0, 500, 250, 500, 250, 500],
      );
    } catch (_) {}
  }

  /// Flashes the flashlight on/off for [duration].
  Future<void> startFlashing({
    Duration duration = const Duration(seconds: 10),
  }) async {
    stopFlashing();
        if (!flashlightEnabled) return;
    try {
      if (!await TorchLight.isTorchAvailable()) return;
    } catch (_) {
      return; // no flashlight on this device
    }

    final end = DateTime.now().add(duration);
    _flashTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (DateTime.now().isAfter(end)) {
        stopFlashing();
        return;
      }
      try {
        if (_torchOn) {
          await TorchLight.disableTorch();
        } else {
          await TorchLight.enableTorch();
        }
        _torchOn = !_torchOn;
      } catch (_) {
        stopFlashing();
      }
    });
  }

  void stopFlashing() {
    _flashTimer?.cancel();
    _flashTimer = null;
    if (_torchOn) {
      _torchOn = false;
      TorchLight.disableTorch().ignore();
    }
  }

  Future<void> stopAll() async {
    stopFlashing();
    try {
      await Vibration.cancel();
    } catch (_) {}
  }
}