/// How HearAble reacts to a sound category.
enum SoundTier {
  /// Tier 2 — automatic emergency escalation (smoke alarm, glass)
  emergency,

  /// Loud bang — 60-second "Are you safe?" check-in
  checkIn,

  /// Tier 1 — visual + vibration alert only, never contacts anyone
  alertOnly,
}

/// HearAble categories and the YAMNet (AudioSet) class names that
/// belong to each. Names must match yamnet_class_map.csv exactly.
enum SoundCategory {
  smokeAlarm('Smoke or fire alarm', SoundTier.emergency,
      ['Smoke detector, smoke alarm', 'Fire alarm']),
  glassBreaking('Glass breaking', SoundTier.emergency,
      ['Shatter', 'Glass', 'Breaking']),
  loudBang('Loud bang', SoundTier.checkIn, [
    'Bang', 'Slam', 'Thump, thud', 'Smash, crash', 'Boom', 'Clatter',
  ]),
  vehicleHorn('Vehicle horn', SoundTier.alertOnly, [
    'Vehicle horn, car horn, honking', 'Air horn, truck horn', 'Toot',
  ]),
  siren('Emergency siren', SoundTier.alertOnly, [
    'Siren', 'Emergency vehicle', 'Police car (siren)',
    'Ambulance (siren)', 'Fire engine, fire truck (siren)',
    'Civil defense siren',
  ]),
  doorbell('Doorbell', SoundTier.alertOnly, ['Doorbell', 'Ding-dong']),
  knocking('Knocking', SoundTier.alertOnly, ['Knock']),
  babyCrying('Baby crying', SoundTier.alertOnly, ['Baby cry, infant cry']),
  screaming('Screaming', SoundTier.alertOnly, ['Screaming']),
  carAlarm('Car alarm', SoundTier.alertOnly, ['Car alarm']);

  const SoundCategory(this.label, this.tier, this.yamnetClasses);

  final String label;
  final SoundTier tier;
  final List<String> yamnetClasses;
}

/// One confirmed detection.
class SoundDetection {
  const SoundDetection({
    required this.category,
    required this.score,
    required this.detectedAt,
    this.simulated = false,
  });

  final SoundCategory category;

  /// Model score (0–1). NOT a guaranteed probability.
  final double score;
  final DateTime detectedAt;

  /// True for demo/test alerts — always shown as SIMULATED.
  final bool simulated;
}

/// Detection rules. These thresholds are STARTING VALUES and must be
/// tuned with real recordings (Phase 7 testing). They will become
/// user-adjustable in Settings.
class DetectionSettings {
    /// Set by Settings → Sensitivity (lower = more sensitive).
  static double sensitivityFactor = 1.0;
  static final Map<SoundCategory, double> thresholds = {
    SoundCategory.smokeAlarm: 0.25,
    SoundCategory.glassBreaking: 0.40,
    SoundCategory.loudBang: 0.35,
    SoundCategory.vehicleHorn: 0.30,
    SoundCategory.siren: 0.30,
    SoundCategory.doorbell: 0.30,
    SoundCategory.knocking: 0.35,
    SoundCategory.babyCrying: 0.35,
    SoundCategory.screaming: 0.40,
    SoundCategory.carAlarm: 0.30,
  };

  /// Enabled by default. Tier 1 starts with horns and doorbells
  /// (plus sirens); the others can be switched on in Settings later.
  static final Set<SoundCategory> enabled = {
    SoundCategory.smokeAlarm,
    SoundCategory.glassBreaking,
    SoundCategory.loudBang,
    SoundCategory.vehicleHorn,
    SoundCategory.doorbell,
    SoundCategory.siren,
  };

  /// Smoke/fire alarm: 3 hits in the last 4 frames (~2 seconds).
  static const smokeWindowFrames = 4;
  static const smokeRequiredHits = 3;

  /// Minimum time between two detections of the same category.
  static Duration cooldownFor(SoundCategory c) =>
      c.tier == SoundTier.alertOnly
          ? const Duration(seconds: 10)
          : const Duration(seconds: 30);
}