import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart' show ContactRole;

/// One emergency contact, as stored in users/{uid}/contacts/{id}.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.lastTestStatus,
  });

  final String id;
  final String name;
  final String phone;
  final ContactRole role;
  final String lastTestStatus;

  factory EmergencyContact.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EmergencyContact(
      id: doc.id,
      name: d['name'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      role: ContactRole.values.firstWhere(
        (r) => r.name == d['role'],
        orElse: () => ContactRole.secondary,
      ),
      lastTestStatus: d['lastTestStatus'] as String? ?? 'never_tested',
    );
  }

  bool get isPersonal => role != ContactRole.guardHouse;

  String get roleLabel => switch (role) {
        ContactRole.primary => 'Primary contact',
        ContactRole.secondary => 'Second contact',
        ContactRole.guardHouse => 'Guard house / security',
      };

  String get testStatusLabel => switch (lastTestStatus) {
        'sending' => 'Sending test SMS…',
        'sent' => 'Test SMS sent (delivery not confirmed)',
        'delivered' => 'Test SMS delivered ✓',
        'not_delivered' => 'Test SMS not delivered',
        'failed' => 'Test SMS failed',
        _ => 'Not tested yet',
      };
}

class ContactsService {
  ContactsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('contacts');

  /// Live list, ordered: primary, second, guard house.
  Stream<List<EmergencyContact>> watch(String uid) {
    return _col(uid).snapshots().map((snap) {
      final list = snap.docs.map(EmergencyContact.fromDoc).toList();
      list.sort((a, b) => a.role.index.compareTo(b.role.index));
      return list;
    });
  }

  Future<void> add(
    String uid, {
    required String name,
    required String phone,
    required ContactRole role,
  }) {
    return _run(_col(uid).add({
      'name': name,
      'phone': phone,
      'role': role.name,
      'lastTestStatus': 'never_tested',
      'consentConfirmed': true,
      'createdAt': FieldValue.serverTimestamp(),
    }));
  }

  Future<void> update(
    String uid,
    String id, {
    required String name,
    required String phone,
    required bool phoneChanged,
  }) {
    return _run(_col(uid).doc(id).update({
      'name': name,
      'phone': phone,
      // A new number has never been tested
      if (phoneChanged) 'lastTestStatus': 'never_tested',
      'updatedAt': FieldValue.serverTimestamp(),
    }));
  }

  /// Deletes a contact. If it was the primary, the second contact
  /// is promoted to primary in the same operation.
  Future<void> delete(
    String uid,
    EmergencyContact contact,
    List<EmergencyContact> all,
  ) {
    final batch = _db.batch();
    batch.delete(_col(uid).doc(contact.id));
    if (contact.role == ContactRole.primary) {
      for (final c in all) {
        if (c.role == ContactRole.secondary) {
          batch.update(_col(uid).doc(c.id), {'role': 'primary'});
          break;
        }
      }
    }
    return _run(batch.commit());
  }

  /// Makes [target] the primary; the old primary becomes second.
  Future<void> makePrimary(
    String uid,
    EmergencyContact target,
    List<EmergencyContact> all,
  ) {
    final batch = _db.batch();
    for (final c in all) {
      if (c.role == ContactRole.primary && c.id != target.id) {
        batch.update(_col(uid).doc(c.id), {'role': 'secondary'});
      }
    }
    batch.update(_col(uid).doc(target.id), {'role': 'primary'});
    return _run(batch.commit());
  }
  Future<void> setTestStatus(String uid, String id, String status) {
    return _run(_col(uid).doc(id).update({
      'lastTestStatus': status,
      'lastTestAt': FieldValue.serverTimestamp(),
    }));
  }
  /// When offline, Firestore saves on the phone and syncs later,
  /// so we don't make the user wait forever.
  /// 
  Future<void> _run(Future<void> operation) async {
    try {
      await operation.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Queued offline — will sync automatically.
    }
  }
}