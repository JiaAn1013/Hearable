import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hearable/core/sound/sound_categories.dart';

void main() {
  late List<String> labels;

  setUpAll(() {
    final csv = File('assets/models/yamnet_class_map.csv').readAsLinesSync();
    labels = [
      for (final line in csv.skip(1))
        if (line.trim().isNotEmpty)
          () {
            final second = line.indexOf(',', line.indexOf(',') + 1);
            var name = line.substring(second + 1).trim();
            if (name.startsWith('"') && name.endsWith('"')) {
              name = name.substring(1, name.length - 1);
            }
            return name;
          }(),
    ];
  });

  test('label file has 521 YAMNet classes', () {
    expect(labels.length, 521);
  });

  test('every HearAble category maps to real YAMNet classes', () {
    for (final category in SoundCategory.values) {
      for (final name in category.yamnetClasses) {
        expect(labels, contains(name),
            reason: '"$name" (${category.label}) is not a YAMNet class');
      }
    }
  });

  test('every category has a threshold between 0 and 1', () {
    for (final c in SoundCategory.values) {
      final t = DetectionSettings.thresholds[c];
      expect(t, isNotNull, reason: '${c.label} has no threshold');
      expect(t! > 0 && t < 1, isTrue);
    }
  });

  test('smoke alarm needs 3 of the last 4 frames', () {
    expect(DetectionSettings.smokeWindowFrames, 4);
    expect(DetectionSettings.smokeRequiredHits, 3);
  });

  test('tier rules: smoke and glass escalate, horn and doorbell never do', () {
    expect(SoundCategory.smokeAlarm.tier, SoundTier.emergency);
    expect(SoundCategory.glassBreaking.tier, SoundTier.emergency);
    expect(SoundCategory.loudBang.tier, SoundTier.checkIn);
    expect(SoundCategory.vehicleHorn.tier, SoundTier.alertOnly);
    expect(SoundCategory.doorbell.tier, SoundTier.alertOnly);
  });
}