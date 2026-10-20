import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import '../sound/sound_categories.dart';
import 'background_service.dart';
import 'permission_service.dart';

enum MonitoringStatus { paused, starting, active, permissionRequired, unavailable }

enum AlertState { none, pending, notificationSent }

/// Implemented by the real sound detection engine.
abstract class SoundEngine {
  Future<void> start();
  Future<void> stop();
  Stream<SoundDetection> get detections;
  abstract void Function(String reason)? onUnexpectedStop;
}

/// Keeps track of whether monitoring is REALLY running.
class MonitoringController extends ChangeNotifier with WidgetsBindingObserver {
  MonitoringController._();
  static final instance = MonitoringController._();

  final _permissions = PermissionService();
  final _background = BackgroundService.instance;

  SoundEngine? _engine;
  StreamSubscription<SoundDetection>? _detectionSub;
  final _detections = StreamController<SoundDetection>.broadcast();

  MonitoringStatus _status = MonitoringStatus.paused;
  AlertState _alertState = AlertState.none;
  String? _message;
  SoundDetection? _lastDetection;
  bool _inForeground = true;
  bool _runsInBackground = false;

  MonitoringStatus get status => _status;
  AlertState get alertState => _alertState;
  String? get message => _message;
  bool get isActive => _status == MonitoringStatus.active;
  bool get isInForeground => _inForeground;
  bool get runsInBackground => _runsInBackground;
  SoundDetection? get lastDetection => _lastDetection;
  Stream<SoundDetection> get detections => _detections.stream;

  SoundEngine? get engine => _engine;
  set engine(SoundEngine? e) {
    _engine = e;
    e?.onUnexpectedStop = (reason) async {
      await _detectionSub?.cancel();
      _detectionSub = null;
      await _background.stop();
      _runsInBackground = false;
      reportStopped(reason);
    };
  }

  void attachLifecycle() => WidgetsBinding.instance.addObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;

    // Without a background service (e.g. iPhone for now), the phone
    // blocks the microphone when HearAble is not visible — say so.
    if (state == AppLifecycleState.paused && isActive && !_runsInBackground) {
      stop().then((_) => reportStopped(
          'Monitoring stopped because HearAble left the screen. '
          'Background monitoring is not available on this phone yet — '
          'keep HearAble open.'));
    }
  }

  Future<void> start() async {
    _set(MonitoringStatus.starting);

    var mic = await _permissions.status(AppPermission.microphone);
    if (!mic.isGranted) {
      mic = await _permissions.request(AppPermission.microphone);
    }
    if (!mic.isGranted) {
      _set(MonitoringStatus.permissionRequired,
          'Allow the microphone so HearAble can listen for sounds.');
      return;
    }

    final e = _engine;
    if (e == null) {
      _set(MonitoringStatus.unavailable,
          'The sound detection engine is not installed. '
          'Monitoring is NOT running.');
      return;
    }

    try {
      // Start the foreground service FIRST (Android requires this while
      // the app is visible), then the microphone.
      _runsInBackground = await _background.start();
      await e.start();
      await _detectionSub?.cancel();
      _detectionSub = e.detections.listen(_onDetection);
      _set(
        MonitoringStatus.active,
        _runsInBackground
            ? 'HearAble is listening — also with the screen off or in other '
                'apps. Do not swipe HearAble away from recent apps.'
            : 'HearAble is listening. Keep HearAble open on screen.',
      );
    } catch (err) {
      await _background.stop();
      _runsInBackground = false;
      _set(MonitoringStatus.unavailable,
          'Monitoring could not start. Please try again. ($err)');
    }
  }

  Future<void> stop() async {
    await _detectionSub?.cancel();
    _detectionSub = null;
    try {
      await _engine?.stop();
    } catch (_) {}
    await _background.stop();
    _runsInBackground = false;
    _set(MonitoringStatus.paused);
  }

  /// Monitoring stopped unexpectedly. If the user can't see the app,
  /// also tell them with a notification.
  void reportStopped(String reason) {
    _set(MonitoringStatus.unavailable, reason);
    if (!_inForeground) {
      _background.showStatus('HearAble monitoring stopped', reason);
    }
  }

  void setAlertState(AlertState state) {
    _alertState = state;
    notifyListeners();
  }

  void _onDetection(SoundDetection d) {
    _lastDetection = d;
    _detections.add(d);
    notifyListeners();
  }

  void _set(MonitoringStatus status, [String? message]) {
    _status = status;
    _message = message;
    notifyListeners();
  }
}