import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/alarm_player.dart';
import '../../core/services/alert_effects.dart';
import '../../core/services/events_service.dart';
import '../../core/services/monitoring_controller.dart';
import '../../core/sound/sound_categories.dart';
import 'emergency_alert_screen.dart';
import 'escalation_screen.dart';
import 'sound_alert_screen.dart';
import '../../core/services/emergency_notifier.dart';
import '../../core/services/background_service.dart';

enum _Flow { none, soundAlert, checkIn, emergency, escalation }

/// Receives every detection (real or simulated) and runs the right
/// workflow. Priority: escalation > emergency > check-in > Tier 1.
class AlertCoordinator {
  AlertCoordinator._();
  static final instance = AlertCoordinator._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  /// Countdown lengths (adjustable in Settings later, within safe limits)
  static int emergencyCountdownSeconds = 30;
  static int checkInCountdownSeconds = 60;
  static const safeSuppression = Duration(minutes: 2);

  final _events = EventsService();
  StreamSubscription<SoundDetection>? _sub;

  _Flow _flow = _Flow.none;
  int _flowId = 0; // lets a replaced flow know it was replaced
  Route<dynamic>? _route;
  String? _eventId;
  DateTime? _bangMutedUntil;
  final Map<SoundCategory, DateTime> _suppressedUntil = {};

  DateTime? get loudBangMutedUntil => _bangMutedUntil;

  void start() {
    _sub ??= MonitoringController.instance.detections.listen(handle);
  }

  Future<void> handle(SoundDetection d) async {
    final now = DateTime.now();

    // 2-minute suppression after "I'm safe" (tests always run)
    if (!d.simulated) {
      final until = _suppressedUntil[d.category];
      if (until != null && now.isBefore(until)) {
        debugPrint('HearAble: ${d.category.label} suppressed until $until');
        return;
      }
    }

    switch (d.category.tier) {
      case SoundTier.alertOnly:
        if (_flow != _Flow.none) return; // never interrupt a bigger alert
        await _showSoundAlert(d);

      case SoundTier.checkIn:
        final muted = _bangMutedUntil;
        if (!d.simulated && muted != null && now.isBefore(muted)) {
          debugPrint('HearAble: loud bangs muted until $muted');
          return;
        }
        if (_flow != _Flow.none && _flow != _Flow.soundAlert) return;
        _closeCurrent(replacedBy: d.category.label);
        await _runConfirmation(d,
            kind: _Flow.checkIn,
            seconds: checkInCountdownSeconds,
            allowIgnore: true);

      case SoundTier.emergency:
        // Smoke/fire and glass are NEVER muted by the loud-bang Ignore.
        if (_flow == _Flow.emergency || _flow == _Flow.escalation) return;
        _closeCurrent(replacedBy: d.category.label);
        await _runConfirmation(d,
            kind: _Flow.emergency,
            seconds: emergencyCountdownSeconds,
            allowIgnore: false);
    }
  }

  // ------------------------------------------------------------------
  // Tier 1: visual alert only
  // ------------------------------------------------------------------
  Future<void> _showSoundAlert(SoundDetection d) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final myId = ++_flowId;
    _flow = _Flow.soundAlert;
    final eventId = _eventId = _events.create(d, outcome: 'Alert shown');

    AlertEffects.instance.vibrate();
    AlertEffects.instance.startFlashing();
    _notifyIfBackground('${d.category.label} detected', 'Tap to open HearAble.');

    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => SoundAlertScreen(detection: d),
    );
    _route = route;
    await nav.push(route);

    if (myId != _flowId) return; // replaced by a more serious alert
    await AlertEffects.instance.stopAll();
    _events.update(eventId, {'outcome': 'Seen and dismissed'});
    _finish();
  }

  // ------------------------------------------------------------------
  // Tier 2 / loud bang: "Are you safe?" with countdown
  // ------------------------------------------------------------------
  Future<void> _runConfirmation(
    SoundDetection d, {
    required _Flow kind,
    required int seconds,
    required bool allowIgnore,
  }) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final myId = ++_flowId;
    _flow = kind;
    final eventId =
        _eventId = _events.create(d, outcome: 'Waiting for response');

    MonitoringController.instance.setAlertState(AlertState.pending);
    AlertEffects.instance.vibrate(urgent: true);
    AlertEffects.instance.startFlashing(duration: Duration(seconds: seconds));
        _notifyIfBackground(
      '${d.category.label.toUpperCase()} DETECTED — are you safe?',
      'Open HearAble to respond. Your emergency contacts will be notified '
          'in $seconds seconds if you do not respond.',
    );

    final route = MaterialPageRoute<AlertDecision>(
      fullscreenDialog: true,
      builder: (_) => EmergencyAlertScreen(
        detection: d,
        countdownSeconds: seconds,
        allowIgnore: allowIgnore,
      ),
    );
    _route = route;
    final decision = await nav.push(route);

    if (myId != _flowId) return; // replaced by a more serious alert
    _route = null;
    await AlertEffects.instance.stopAll();

    switch (decision?.type) {
      case null:
        _finish();

      case DecisionType.safe:
        _suppressedUntil[d.category] = DateTime.now().add(safeSuppression);
        _events.recordResponse(eventId,
            outcome: 'User confirmed safe', response: 'safe');
        _finish();

      case DecisionType.ignore:
        final minutes = decision!.muteMinutes;
        if (minutes > 0) {
          _bangMutedUntil = DateTime.now().add(Duration(minutes: minutes));
        }
        _events.recordResponse(
          eventId,
          outcome: 'Ignored – ${decision.ignoreReason}'
              '${minutes > 0 ? ' (muted $minutes min)' : ''}',
          response: 'ignored',
          ignoreReason: decision.ignoreReason,
          muteMinutes: minutes,
        );
        _finish();

      case DecisionType.needHelp:
        _events.recordResponse(eventId,
            outcome: 'User asked for help', response: 'need_help');
        await _escalate(d, eventId, 'User asked for help', myId);

      case DecisionType.timeout:
        await _escalate(
            d, eventId, 'No response within $seconds seconds', myId);
    }
  }

  // ------------------------------------------------------------------
  // Escalation
  // ------------------------------------------------------------------
  Future<void> _escalate(
    SoundDetection d,
    String? eventId,
    String reason,
    int myId,
  ) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    _flow = _Flow.escalation;

    _events.markEscalated(eventId, reason: reason, simulated: d.simulated);

    // Send the emergency SMS (once per event, never for simulations)
    EmergencyNotifier.instance.notify(
      eventId: eventId ?? 'local-${DateTime.now().millisecondsSinceEpoch}',
      detection: d,
      userAskedForHelp: reason == 'User asked for help',
    );

    AlarmPlayer.instance.start();
        _notifyIfBackground(
      'HearAble emergency alert started',
      'Your emergency contacts are being notified. Open HearAble to see the status.',
    );
    AlertEffects.instance.vibrate(urgent: true);

    final route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          EscalationScreen(detection: d, eventId: eventId, reason: reason),
    );
    _route = route;
    await nav.push(route);

    if (myId != _flowId) return;
    await AlarmPlayer.instance.stop();
    _finish();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Closes the current (less serious) alert screen.
  void _closeCurrent({required String replacedBy}) {
    final route = _route;
    final nav = navigatorKey.currentState;
    if (route == null || nav == null) return;

    _events.update(_eventId, {'outcome': 'Replaced by $replacedBy alert'});
    _flowId++; // the old flow will ignore its result
    _route = null;
    AlertEffects.instance.stopAll();

    if (route.isActive) {
      // Close anything on top of it first (e.g. the Ignore sheet)
      nav.popUntil((r) => r == route || r.isFirst);
      nav.removeRoute(route);
    }
  }
  /// When HearAble is not on screen, show a heads-up / full-screen
  /// notification so the user actually sees the alert.
  void _notifyIfBackground(String title, String body) {
    if (!MonitoringController.instance.isInForeground) {
      BackgroundService.instance.showAlert(title, body);
    }
  }
    void _finish() {
    _flow = _Flow.none;
    _route = null;
    _eventId = null;
    MonitoringController.instance.setAlertState(AlertState.none);
    BackgroundService.instance.alertFinished();
  }
}