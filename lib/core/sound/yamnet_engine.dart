import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../services/monitoring_controller.dart';
import 'sound_categories.dart';

/// Listens to the microphone and classifies sounds ON THE PHONE with
/// YAMNet. Audio is kept in memory only — never saved or uploaded.
class YamnetSoundEngine implements SoundEngine {
  static const _modelPath = 'assets/models/yamnet.tflite';
  static const _labelsPath = 'assets/models/yamnet_class_map.csv';
  static const _sampleRate = 16000;
  static const _windowSize = 15600; // 0.975 s — what YAMNet expects
  static const _hopSize = 8000; // analyse every 0.5 s

  Interpreter? _interpreter;
  List<String> _labels = [];
  final Map<SoundCategory, List<int>> _classIndexes = {};

  final _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  final List<double> _buffer = [];
  int? _leftoverByte;

  final Map<SoundCategory, List<bool>> _history = {};
  final Map<SoundCategory, DateTime> _lastFired = {};
  int _silentFrames = 0;

  final _detections = StreamController<SoundDetection>.broadcast();

  @override
  Stream<SoundDetection> get detections => _detections.stream;

  @override
  void Function(String reason)? onUnexpectedStop;

  /// Top 3 sounds right now — for the live display only.
  final ValueNotifier<List<(String, double)>> topSounds = ValueNotifier([]);

  // ------------------------------------------------------------------
  // Model loading
  // ------------------------------------------------------------------
  Future<void> _load() async {
    if (_interpreter != null) return;

    try {
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        options: InterpreterOptions()..threads = 2,
      );
    } catch (e) {
      throw Exception('Sound model could not be loaded. '
          'Check that assets/models/yamnet.tflite exists.');
    }

    final csv = await rootBundle.loadString(_labelsPath);
    _labels = _parseLabels(csv);

    for (final category in SoundCategory.values) {
      final indexes = <int>[];
      for (final name in category.yamnetClasses) {
        final i = _labels.indexOf(name);
        if (i >= 0) {
          indexes.add(i);
        } else {
          debugPrint('HearAble: YAMNet class not found: "$name"');
        }
      }
      _classIndexes[category] = indexes;
    }

    debugPrint('HearAble: model loaded. '
        'Input ${_interpreter!.getInputTensor(0).shape}, '
        'output ${_interpreter!.getOutputTensor(0).shape}, '
        '${_labels.length} labels.');
  }

  /// CSV rows look like: 0,/m/09x0r,Speech
  /// or: 1,/m/0ytgt,"Child speech, kid speaking"
  static List<String> _parseLabels(String csv) {
    final labels = <String>[];
    for (final raw in csv.split('\n').skip(1)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final secondComma = line.indexOf(',', line.indexOf(',') + 1);
      var name = line.substring(secondComma + 1);
      if (name.startsWith('"') && name.endsWith('"')) {
        name = name.substring(1, name.length - 1);
      }
      labels.add(name);
    }
    return labels;
  }

  // ------------------------------------------------------------------
  // Start / stop
  // ------------------------------------------------------------------
  @override
  Future<void> start() async {
    await _load();
    if (!await _recorder.hasPermission()) {
      throw Exception('Microphone permission is not granted.');
    }

    _buffer.clear();
    _leftoverByte = null;
    _history.clear();
    _silentFrames = 0;

    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _sampleRate,
      numChannels: 1,
    ));

    _audioSub = stream.listen(
      _onAudio,
      onError: (e) => _fail('The microphone stopped working.'),
      onDone: () {
        if (_audioSub != null) _fail('The microphone stopped unexpectedly.');
      },
    );
  }

  @override
  Future<void> stop() async {
    final sub = _audioSub;
    _audioSub = null;
    await sub?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {}
    _buffer.clear();
    topSounds.value = [];
  }

  void _fail(String reason) {
    stop();
    onUnexpectedStop?.call(reason);
  }

  // ------------------------------------------------------------------
  // Audio → frames
  // ------------------------------------------------------------------
  void _onAudio(Uint8List bytes) {
    // Bytes may split a 16-bit sample — keep the odd byte for next time
    var data = bytes;
    final leftover = _leftoverByte;
    if (leftover != null) {
      data = Uint8List(bytes.length + 1)
        ..[0] = leftover
        ..setRange(1, bytes.length + 1, bytes);
      _leftoverByte = null;
    }
    final usable = data.length - data.length % 2;
    if (usable < data.length) _leftoverByte = data[data.length - 1];

    // PCM 16-bit little-endian → floats between -1 and 1
    final view = ByteData.sublistView(data, 0, usable);
    for (var i = 0; i < usable; i += 2) {
      _buffer.add(view.getInt16(i, Endian.little) / 32768.0);
    }

    while (_buffer.length >= _windowSize) {
      _analyse(Float32List.fromList(_buffer.sublist(0, _windowSize)));
      _buffer.removeRange(0, _hopSize);
    }
  }

  // ------------------------------------------------------------------
  // One frame → model → categories
  // ------------------------------------------------------------------
  void _analyse(Float32List window) {
    final interpreter = _interpreter;
    if (interpreter == null) return;

    // Safeguard: complete silence for ~5 s usually means the phone is
    // blocking the microphone. Report it instead of pretending.
    var peak = 0.0;
    for (final s in window) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
    if (peak == 0) {
      if (++_silentFrames >= 10) {
        _fail('The microphone is not receiving any sound. Another app may '
            'be using it, or the phone has blocked it.');
      }
      return;
    }
    _silentFrames = 0;

    // Run YAMNet
    final outShape = interpreter.getOutputTensor(0).shape;
    final classCount = outShape.last;
    final List<double> scores;
    if (outShape.length == 2) {
      final out = [List<double>.filled(classCount, 0)];
      interpreter.run(window.buffer, out);
      scores = out[0];
    } else {
      final out = List<double>.filled(classCount, 0);
      interpreter.run(window.buffer, out);
      scores = out;
    }

    // Live display: top 3 sounds
    final ranked = List<int>.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    topSounds.value = [
      for (final i in ranked.take(3))
        (i < _labels.length ? _labels[i] : 'Class $i', scores[i]),
    ];

    // Map to HearAble categories
    final now = DateTime.now();
    for (final category in DetectionSettings.enabled) {
      var score = 0.0;
      for (final i in _classIndexes[category] ?? const <int>[]) {
        if (i < scores.length) score = math.max(score, scores[i]);
      }
            final hit = score >=
          DetectionSettings.thresholds[category]! *
              DetectionSettings.sensitivityFactor;

      final history = _history.putIfAbsent(category, () => <bool>[]);
      history.add(hit);
      if (history.length > DetectionSettings.smokeWindowFrames) {
        history.removeAt(0);
      }

      final confirmed = category == SoundCategory.smokeAlarm
          ? history.where((h) => h).length >=
              DetectionSettings.smokeRequiredHits
          : hit;
      if (!confirmed) continue;

      // Duplicate prevention
      final last = _lastFired[category];
      if (last != null &&
          now.difference(last) < DetectionSettings.cooldownFor(category)) {
        continue;
      }
      _lastFired[category] = now;

      debugPrint('HearAble: DETECTED ${category.label} '
          '(score ${score.toStringAsFixed(2)})');
      _detections.add(SoundDetection(
        category: category,
        score: score,
        detectedAt: now,
      ));
    }
  }
}