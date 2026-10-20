import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileService {
  /// Increase this number whenever the privacy terms change, so
  /// users are asked to accept the new version.
  static const currentPrivacyVersion = 1;

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.collection('users').doc(uid);

  /// True once the user has accepted the current privacy terms.
  Stream<bool> hasAcceptedPrivacy(String uid) {
    return _doc(uid).snapshots().map((snap) {
      final version = snap.data()?['privacyConsentVersion'];
      return version is int && version >= currentPrivacyVersion;
    });
  }

  Future<void> acceptPrivacy(String uid) {
    return _doc(uid).set({
      'privacyConsentVersion': currentPrivacyVersion,
      'privacyConsentAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}