import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../features/alerts/alert_coordinator.dart';
import '../sound/sound_categories.dart';
import 'alarm_player.dart';
import 'alert_effects.dart';

enum Sensitivity { low, normal, high }

/// User settings, saved in users/{uid}.settings and applied to the
/// detection engine and alert system immediately.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final instance = SettingsService._();

  /// Safety: these can never be switched off.
  static const alwaysOn = {
    SoundCategory.smokeAlarm,
    SoundCategory.glassBreaking,
  };

  static const _defaultEnabled = {
    SoundCategory.smokeAlarm,
    SoundCategory.glassBreaking,
    SoundCategory.loudBang,
    SoundCategory.vehicleHorn,
    SoundCategory.doorbell,
    SoundCategory.siren,
  };

  // Safe countdown limits
  static const emergencyMin = 15, emergencyMax = 60;
  static const checkInMin = 30, checkInMax = 120;

  String? _uid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  Set<SoundCategory> _enabled = {..._defaultEnabled};
  bool _vibration = true;
  bool _flashlight = true;
  bool _localAlarm = true;
  Sensitivity _sensitivity = Sensitivity.normal;
  int _emergencyCountdown = 30;
  int _checkInCountdown = 60;

  bool isEnabled(SoundCategory c) =>
      alwaysOn.contains(c) || _enabled.contains(c);
  bool get vibration => _vibration;
  bool get flashlight => _flashlight;
  bool get localAlarm => _localAlarm;
  Sensitivity get sensitivity => _sensitivity;
  int get emergencyCountdown => _emergencyCountdown;
  int get checkInCountdown => _checkInCountdown;

  /// Start following this user's saved settings.
  void attach(String uid) {
    if (_uid == uid) return;
    _sub?.cancel();
    _uid = uid;
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final saved = snap.data()?['settings'];
      if (saved is Map) _readFrom(Map<String, dynamic>.from(saved));
      _apply();
      notifyListeners();
    }, onError: (_) {});
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
  }

  // ---------------- Changes from the Settings screen ----------------
  void setCategory(SoundCategory c, bool on) {
    if (alwaysOn.contains(c)) return;
    on ? _enabled.add(c) : _enabled.remove(c);
    _save();
  }

  void setVibration(bool v) {
    _vibration = v;
    _save();
  }

  void setFlashlight(bool v) {
    _flashlight = v;
    _save();
  }

  void setLocalAlarm(bool v) {
    _localAlarm = v;
    _save();
  }

  void setSensitivity(Sensitivity v) {
    _sensitivity = v;
    _save();
  }

  void setEmergencyCountdown(int seconds) {
    _emergencyCountdown = seconds.clamp(emergencyMin, emergencyMax);
    _save();
  }

  void setCheckInCountdown(int seconds) {
    _checkInCountdown = seconds.clamp(checkInMin, checkInMax);
    _save();
  }

  // ---------------- Internals ----------------
  void _readFrom(Map<String, dynamic> s) {
    final cats = s['enabledCategories'];
    if (cats is List) {
      _enabled = {
        for (final name in cats)
          ...SoundCategory.values.where((c) => c.name == name),
      };
    }
    _vibration = s['vibration'] as bool? ?? true;
    _flashlight = s['flashlight'] as bool? ?? true;
    _localAlarm = s['localAlarm'] as bool? ?? true;
    _sensitivity = Sensitivity.values.firstWhere(
      (v) => v.name == s['sensitivity'],
      orElse: () => Sensitivity.normal,
    );
    _emergencyCountdown = ((s['emergencyCountdown'] as num?)?.toInt() ?? 30)
        .clamp(emergencyMin, emergencyMax);
    _checkInCountdown = ((s['checkInCountdown'] as num?)?.toInt() ?? 60)
        .clamp(checkInMin, checkInMax);
  }

  /// Push the settings into the engine and alert system.
  void _apply() {
    DetectionSettings.enabled
      ..clear()
      ..addAll({..._enabled, ...alwaysOn});
    // Lower factor = lower thresholds = more sensitive
    DetectionSettings.sensitivityFactor = switch (_sensitivity) {
      Sensitivity.low => 1.25,
      Sensitivity.normal => 1.0,
      Sensitivity.high => 0.8,
    };
    AlertEffects.vibrationEnabled = _vibration;
    AlertEffects.flashlightEnabled = _flashlight;
    AlarmPlayer.enabled = _localAlarm;
    AlertCoordinator.emergencyCountdownSeconds = _emergencyCountdown;
    AlertCoordinator.checkInCountdownSeconds = _checkInCountdown;
  }

  void _save() {
    _apply();
    notifyListeners();
    final uid = _uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'settings': {
        'enabledCategories': [for (final c in _enabled) c.name],
        'vibration': _vibration,
        'flashlight': _flashlight,
        'localAlarm': _localAlarm,
        'sensitivity': _sensitivity.name,
        'emergencyCountdown': _emergencyCountdown,
        'checkInCountdown': _checkInCountdown,
      },
    }, SetOptions(merge: true)).ignore();
  }
}