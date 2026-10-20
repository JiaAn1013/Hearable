import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Plays a loud two-tone alarm on the phone (looping).
/// Note: the phone's media volume still applies.
class AlarmPlayer {
  AlarmPlayer._();
  static final instance = AlarmPlayer._();
    /// Set from Settings.
  static bool enabled = true;

  final _player = AudioPlayer();
  String? _path;
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> start() async {
        if (_playing || !enabled) return;
    try {
      final path = await _alarmFile();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(DeviceFileSource(path));
      _playing = true;
    } catch (e) {
      debugPrint('HearAble: alarm could not play: $e');
    }
  }

  Future<void> stop() async {
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  Future<String> _alarmFile() async {
    final existing = _path;
    if (existing != null) return existing;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/hearable_alarm.wav');
    await file.writeAsBytes(_buildWav());
    _path = file.path;
    return file.path;
  }

  /// 2-second siren: 880 Hz then 660 Hz square wave, 16-bit mono WAV.
  static Uint8List _buildWav() {
    const rate = 22050;
    const samples = rate * 2;
    final data = ByteData(44 + samples * 2);

    void text(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    // WAV header
    text(0, 'RIFF');
    data.setUint32(4, 36 + samples * 2, Endian.little);
    text(8, 'WAVE');
    text(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    text(36, 'data');
    data.setUint32(40, samples * 2, Endian.little);

    // Siren samples
    for (var i = 0; i < samples; i++) {
      final t = i / rate;
      final freq = (t % 1.0) < 0.5 ? 880.0 : 660.0;
      final value = math.sin(2 * math.pi * freq * t) >= 0 ? 0.9 : -0.9;
      data.setInt16(44 + i * 2, (value * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}