import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../onboarding/welcome_screen.dart';
import '../permissions/permissions_consent_screen.dart';
import 'verify_email_screen.dart';

/// Decides which screen to show:
/// Welcome → Verify email → Permissions & privacy → Dashboard
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();
        if (!user.emailVerified) return const VerifyEmailScreen();
        return _ConsentGate(uid: user.uid);
      },
    );
  }
}

/// Shows the consent screen until the current privacy terms are accepted.
class _ConsentGate extends StatelessWidget {
  const _ConsentGate({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: UserProfileService().hasAcceptedPrivacy(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load your profile. Check your internet '
                  'connection and reopen the app.',
                  style: TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const _SplashScreen();
        return snapshot.data!
            ? const DashboardScreen()
            : const PermissionsConsentScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hearing, size: 80, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}