import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../sound/sound_categories.dart';

/// Saves alerts to users/{uid}/events. Works offline: Firestore keeps
/// the write on the phone and syncs it when the connection returns.
class EventsService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('events');
  }

  /// Creates an event with a unique ID and returns that ID.
  String? create(SoundDetection d, {required String outcome}) {
    final col = _col();
    if (col == null) return null;

    final ref = col.doc(); // unique event ID
    ref.set({
      'categoryKey': d.category.name,
      'category': d.simulated
          ? 'TEST – ${d.category.label}'
          : d.category.label,
      'tier': d.category.tier.name,
      'score': d.score,
      'simulated': d.simulated,
      'detectedAt': Timestamp.fromDate(d.detectedAt),
      'createdAt': FieldValue.serverTimestamp(),
      'outcome': outcome,
      'escalated': false,
    }).ignore();
    return ref.id;
  }

  void update(String? eventId, Map<String, dynamic> data) {
    if (eventId == null) return;
    _col()?.doc(eventId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }).ignore();
  }

  void recordResponse(
    String? eventId, {
    required String outcome,
    required String response,
    String? ignoreReason,
    int? muteMinutes,
  }) {
    update(eventId, {
      'outcome': outcome,
      'userResponse': response,
      'respondedAt': FieldValue.serverTimestamp(),
      'ignoreReason': ?ignoreReason,
      'muteMinutes': ?muteMinutes,
    });
  }

  /// Marks the event for emergency notification. In Phase 5 a secure
  /// backend function will send the messages for events with
  /// escalationStatus == 'pending_notification' (once per event ID).
  void markEscalated(
    String? eventId, {
    required String reason,
    required bool simulated,
  }) {
    update(eventId, {
      'outcome': simulated
          ? 'Escalated (simulated – nothing sent)'
          : 'Escalated – $reason',
      'escalated': true,
      'escalationReason': reason,
      'escalatedAt': FieldValue.serverTimestamp(),
      'escalationStatus':
      simulated ? 'simulated_not_sent' : 'sms_from_phone',
    });
  }

  void markCancelled(String? eventId) {
    update(eventId, {
      'outcome': 'Cancelled by user – safe',
      'cancelledByUser': true,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }
    /// Deletes one event.
  Future<void> delete(String eventId) async {
    await _col()
        ?.doc(eventId)
        .delete()
        .timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  /// Deletes ALL of the user's events. Returns how many were deleted.
  Future<int> deleteAll() async {
    final col = _col();
    if (col == null) return 0;
    var total = 0;
    while (true) {
      final snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 20));
      total += snap.docs.length;
      if (snap.docs.length < 400) break;
    }
    return total;
  }
}