import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../sound/sound_categories.dart';
import 'contacts_service.dart';
import 'events_service.dart';
import 'monitoring_controller.dart';
import 'sms_service.dart';

/// Delivery status of the emergency SMS for one contact.
class ContactDelivery {
  ContactDelivery({required this.contact, required this.status});

  final EmergencyContact contact;
  String status;
  String? error;

  bool get succeeded => status == 'sent' || status == 'delivered';
  bool get canRetry =>
      status == 'failed' ||
      status == 'not_delivered' ||
      status == 'permission_denied';

  String get label => switch (status) {
        'queued' => 'Waiting to send…',
        'sending' => 'Sending…',
        'sent' => 'Sent — delivery not confirmed yet',
        'delivered' => 'Delivered ✓',
        'not_delivered' => 'Not delivered',
        'failed' => 'Failed${error != null ? ': $error' : ''}',
        'permission_denied' => 'Not sent — SMS permission is off',
        'rate_limited' => 'Not sent — too many alerts in a short time',
        'simulated' => 'Simulated test — not sent',
        'needs_user' => 'Tap "Send message" to send from Messages',
        'composer_opened' => 'Messages opened — check that it was sent',
        _ => status,
      };
}

/// Sends the emergency SMS to every contact when an alert escalates,
/// and tracks the real delivery status of each message.
class EmergencyNotifier extends ChangeNotifier {
  EmergencyNotifier._();
  static final instance = EmergencyNotifier._();

  /// Abuse/cost protection: at most 3 emergency rounds per 30 minutes.
  static const _maxRoundsPerWindow = 3;
  static const _window = Duration(minutes: 30);
  static const _maxRetries = 3;

  final _sms = SmsService.instance;
  final _events = EventsService();
  final Set<String> _notifiedEvents = {}; // one round per event ID
  final List<DateTime> _recentRounds = [];

  String? _eventId;
  SoundDetection? _detection;
  bool _askedForHelp = false;
  String _userName = 'A HearAble user';
  int _retries = 0;
  bool _loading = false;
  List<ContactDelivery> _deliveries = [];

  List<ContactDelivery> get deliveries => List.unmodifiable(_deliveries);
  bool get loading => _loading;
  bool get isSimulated => _detection?.simulated ?? false;
  bool get canRetry =>
      !isSimulated &&
      _retries < _maxRetries &&
      _deliveries.any((d) => d.canRetry);
  bool get anyReached => _deliveries.any((d) => d.succeeded);

  // ------------------------------------------------------------------
  // Start notifying (called once when an alert escalates)
  // ------------------------------------------------------------------
  Future<void> notify({
    required String eventId,
    required SoundDetection detection,
    required bool userAskedForHelp,
  }) async {
    if (_notifiedEvents.contains(eventId)) return; // never send twice
    _notifiedEvents.add(eventId);

    _eventId = eventId;
    _detection = detection;
    _askedForHelp = userAskedForHelp;
    _retries = 0;
    _deliveries = [];
    _loading = true;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      notifyListeners();
      return;
    }

    final contacts = await _loadContacts(uid);
    _userName = await _loadUserName(uid);
    _deliveries = [
      for (final c in contacts) ContactDelivery(contact: c, status: 'queued'),
    ];
    _loading = false;
    notifyListeners();

    if (detection.simulated) {
      for (final d in _deliveries) {
        _setStatus(d, 'simulated');
      }
      return;
    }

    // Rate limit
    final now = DateTime.now();
    _recentRounds.removeWhere((t) => now.difference(t) > _window);
    if (_recentRounds.length >= _maxRoundsPerWindow) {
      for (final d in _deliveries) {
        _setStatus(d, 'rate_limited');
      }
      return;
    }
    _recentRounds.add(now);

    await _sendTo(_deliveries);
  }

  Future<void> retryFailed() async {
    if (!canRetry) return;
    _retries++;
    await _sendTo(_deliveries.where((d) => d.canRetry).toList());
  }

  /// iPhone: open Messages with the emergency text for one contact.
  Future<void> openComposer(ContactDelivery d) async {
    final opened =
        await _sms.openComposer(phone: d.contact.phone, message: _message());
    if (opened) _setStatus(d, 'composer_opened');
  }

  /// After "I'm safe — cancel", tell contacts who received the alert.
  Future<void> sendAllClear() async {
    if (isSimulated || !Platform.isAndroid) return;
    final reached = _deliveries.where((d) => d.succeeded).toList();
    if (reached.isEmpty || !await _sms.hasPermission()) return;

    final message = SmsService.allClearMessage(_userName);
    for (final d in reached) {
      _sms
          .sendTracked(
            id: 'clear-$_eventId-${d.contact.id}',
            phone: d.contact.phone,
            message: message,
          )
          .listen((_) {});
    }
    _events.update(_eventId, {'allClearSent': true});
  }

  String get summary {
    if (_loading) return 'Preparing messages…';
    if (_deliveries.isEmpty) {
      return 'No emergency contacts are set, so no message could be sent.';
    }
    if (isSimulated) return 'Simulated test: no SMS messages are sent.';
    if (_deliveries.every(
        (d) => d.status == 'needs_user' || d.status == 'composer_opened')) {
      return 'iPhone cannot send SMS automatically. Tap "Send message" for '
          'each contact below.';
    }

    final total = _deliveries.length;
    final delivered =
        _deliveries.where((d) => d.status == 'delivered').length;
    final sent = _deliveries.where((d) => d.succeeded).length;

    if (delivered == total) return 'Delivered to all $total contacts.';
    if (sent > 0) {
      return 'Sent to $sent of $total contacts. '
          '${delivered > 0 ? 'Delivered to $delivered.' : 'Delivery not confirmed yet.'}';
    }
    if (_deliveries.any((d) => d.status == 'sending' || d.status == 'queued')) {
      return 'Sending messages…';
    }
    return 'Messages could NOT be sent. Please call your contacts now.';
  }

  bool get hasProblem =>
      !isSimulated &&
      !_loading &&
      !anyReached &&
      !_deliveries.any((d) =>
          d.status == 'sending' ||
          d.status == 'queued' ||
          d.status == 'needs_user' ||
          d.status == 'composer_opened');

  // ------------------------------------------------------------------
  // Internals
  // ------------------------------------------------------------------
  Future<void> _sendTo(List<ContactDelivery> targets) async {
    if (!Platform.isAndroid) {
      for (final d in targets) {
        _setStatus(d, 'needs_user');
      }
      return;
    }
    if (!await _sms.hasPermission()) {
      for (final d in targets) {
        _setStatus(d, 'permission_denied');
      }
      return;
    }

    final message = _message();
    for (final d in targets) {
      _setStatus(d, 'sending');
      _sms
          .sendTracked(
            id: '$_eventId-${d.contact.id}-'
                '${DateTime.now().millisecondsSinceEpoch}',
            phone: d.contact.phone,
            message: message,
          )
          .listen((u) {
        if (u.status == 'submitted') return;
        _setStatus(d, u.status, error: u.error);
      });
    }
  }

  String _message() {
    final d = _detection!;
    final t = d.detectedAt;
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${two(t.hour)}:${two(t.minute)} on ${two(t.day)}/${two(t.month)}/${t.year}';
    return SmsService.emergencyMessage(
      userName: _userName,
      category: d.category.label.toLowerCase(),
      time: time,
      userAskedForHelp: _askedForHelp,
    );
  }

  void _setStatus(ContactDelivery d, String status, {String? error}) {
    d.status = status;
    d.error = error;
    _events.update(_eventId, {
      'notifications.${d.contact.id}': {
        'name': d.contact.name,
        'phone': d.contact.phone,
        'role': d.contact.role.name,
        'status': status,
        'error': ?error,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    });
    if (d.succeeded) {
      MonitoringController.instance
          .setAlertState(AlertState.notificationSent);
    }
    notifyListeners();
  }

  Future<List<EmergencyContact>> _loadContacts(String uid) async {
    try {
      return await ContactsService()
          .watch(uid)
          .first
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return [];
    }
  }

  Future<String> _loadUserName(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final name = snap.data()?['fullName'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.displayName ??
        'A HearAble user';
  }
}