import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ContactRole { primary, secondary, guardHouse }

class EmergencyContactInput {
  const EmergencyContactInput({
    required this.name,
    required this.phone,
    required this.role,
  });
  final String name;
  final String phone; // international format, e.g. +60123456789
  final ContactRole role;
}

/// An error with a message that is safe to show to the user.
class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// The currently logged-in user, or null.
  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------
  // SIGN UP
  // ---------------------------------------------------------------
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required List<EmergencyContactInput> contacts,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
    final user = credential.user!;

    try {
      final userRef = _db.collection('users').doc(user.uid);
      final batch = _db.batch();

      batch.set(userRef, {
        'fullName': fullName,
        'email': email.trim(),
        'phone': phone,
        'language': 'en',
        'contactConsentConfirmed': true,
        'contactConsentAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (final contact in contacts) {
        batch.set(userRef.collection('contacts').doc(), {
          'name': contact.name,
          'phone': contact.phone,
          'role': contact.role.name,
          'lastTestStatus': 'never_tested',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit().timeout(const Duration(seconds: 20));
    } catch (_) {
      try {
        await user.delete();
      } catch (_) {}
      throw AuthException(
          'Could not save your details. Check your internet connection '
          'and try again.');
    }

    try {
      await user.updateDisplayName(fullName);
      await user.sendEmailVerification();
    } catch (_) {}
  }

  // ---------------------------------------------------------------
  // LOG IN
  // ---------------------------------------------------------------
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  // ---------------------------------------------------------------
  // FORGOT PASSWORD
  // ---------------------------------------------------------------
  /// Sends a reset link. For privacy, we never reveal whether an
  /// account exists for this email.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return; // stay neutral
      throw AuthException(_messageFor(e.code));
    }
  }
  // ---------------------------------------------------------------
  // EMAIL VERIFICATION
  // ---------------------------------------------------------------
  /// Refreshes the user from Firebase and returns true if verified.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> resendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }
    // ---------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _db.collection('users').doc(user.uid).update({
        'fullName': fullName,
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
      await user.updateDisplayName(fullName);
    } on TimeoutException {
      // Saved on the phone; Firestore syncs it when back online.
    } catch (_) {
      throw AuthException('Could not save your profile. Please try again.');
    }
  }

  // ---------------------------------------------------------------
  // DELETE ACCOUNT AND ALL PERSONAL DATA
  // ---------------------------------------------------------------
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    // 1. Confirm it's really the user (Firebase requires a recent login)
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }

    // 2. Delete all their data (must be online to delete everything)
    final userRef = _db.collection('users').doc(user.uid);
    try {
      for (final sub in ['events', 'contacts']) {
        while (true) {
          final snap = await userRef
              .collection(sub)
              .limit(400)
              .get(const GetOptions(source: Source.server));
          if (snap.docs.isEmpty) break;
          final batch = _db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit().timeout(const Duration(seconds: 20));
          if (snap.docs.length < 400) break;
        }
      }
      await userRef.delete().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw AuthException(
          'Could not delete your data. Check your internet connection and '
          'try again. Your account has NOT been deleted.');
    }

    // 3. Delete the login itself
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }
  // ---------------------------------------------------------------
  // LOG OUT
  // ---------------------------------------------------------------
  Future<void> signOut() => _auth.signOut();

  // ---------------------------------------------------------------
  // Friendly error messages
  // ---------------------------------------------------------------
  String _messageFor(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Try logging in.';
      case 'invalid-email':
        return 'This email address is not valid.';
      case 'weak-password':
        return 'This password is too weak. Use at least 8 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled in Firebase yet.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}