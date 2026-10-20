import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _lastUpdated = '18 October 2026';
  static const _contactEmail = 'jiaanlee20@gmail.com';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('HearAble Privacy Policy', style: text.headlineMedium),
            const SizedBox(height: 4),
            Text('Last updated: $_lastUpdated', style: text.bodyMedium),
            const SizedBox(height: 16),
            const _Notice(
              'HearAble is a support tool for deaf and hard-of-hearing '
              'people. It cannot guarantee that every sound is detected or '
              'that every message is delivered. Do not rely on it as your '
              'only safety measure.',
            ),

            const _Section('1. What we collect', [
              'Account details: your full name, email address and phone number.',
              'Emergency contacts: the names and phone numbers you add, '
                  'including an optional guard-house number.',
              'Alert history: the type of sound detected, the time, your '
                  'response (safe, help or ignore), any false-alarm reason you '
                  'choose, whether an alert was escalated, and the delivery '
                  'status of emergency messages.',
              'Settings: your sound categories, sensitivity, alert methods, '
                  'countdown lengths and language.',
            ]),

            const _Section('2. What we do NOT collect', [
              'We do not record, save or upload microphone audio. Sound is '
                  'analysed on your phone in short pieces of about one second '
                  'and is discarded immediately after analysis.',
              'We do not collect your location unless you turn on location '
                  'sharing (if this feature is offered).',
              'We do not sell your personal data, and we do not use it for '
                  'advertising.',
            ]),

            const _Section('3. Why we use your data', [
              'To create and protect your account.',
              'To alert you visually and by vibration when important sounds '
                  'are detected.',
              'To notify your emergency contacts when you ask for help or do '
                  'not respond to an emergency alert.',
              'To show your alert history and help you understand false '
                  'alarms.',
            ]),

            const _Section('4. When your data is shared', [
              'With your emergency contacts, ONLY when an emergency alert is '
                  'escalated or when you send a test message yourself. The '
                  'message contains your name, the type of sound and the time.',
              'Emergency SMS messages are sent from your own phone using your '
                  'mobile network. Normal SMS charges from your provider apply.',
              'Your account data is stored with Google Firebase (Firebase '
                  'Authentication and Cloud Firestore), located in the '
                  'asia-southeast1 (Singapore) region.',
              'We do not share your data with anyone else, unless required by law.',
            ]),

            const _Section('5. Your emergency contacts', [
              'You must only add people who have agreed to be contacted by '
                  'HearAble. You confirm this when you add each contact.',
              'Their names and numbers are only visible to you and are only '
                  'used to send HearAble alerts.',
            ]),

            const _Section('6. Security', [
              'Your password is handled by Firebase Authentication and is '
                  'never stored by HearAble.',
              'Security rules ensure that only you can read or change your '
                  'profile, contacts and history.',
              'All network communication uses encrypted HTTPS connections.',
            ]),

            const _Section('7. How long we keep your data', [
              'Your data is kept until you delete it.',
              'You can delete single alerts or your whole history at any time '
                  'from the History page.',
              'You can delete your account from your Profile. This permanently '
                  'removes your profile, contacts, settings and history from '
                  'our database, and deletes your login.',
            ]),

            const _Section('8. Permissions', [
              'Microphone: to detect important sounds (analysed on the phone only).',
              'Notifications: to alert you when HearAble is in the background '
                  'and to show that monitoring is on.',
              'SMS (Android): to text your emergency contacts.',
              'Battery and full-screen alerts (Android): so monitoring can '
                  'continue in the background and emergencies can wake the screen.',
              'You can change any permission at any time in your phone settings.',
            ]),

            const _Section('9. Your rights', [
              'You can view and correct your personal data in the app at any time.',
              'You can withdraw consent by turning off monitoring, removing '
                  'permissions, or deleting your account.',
              'For any privacy question or request, contact: $_contactEmail',
            ]),

            const _Section('10. Changes to this policy', [
              'If this policy changes, HearAble will ask you to review and '
                  'accept the new version before you continue.',
            ]),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.points);
  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: text.titleLarge?.copyWith(fontSize: 20)),
          ),
          const SizedBox(height: 8),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ',
                      style: TextStyle(fontSize: 18, color: AppColors.navy)),
                  Expanded(child: Text(p, style: text.bodyLarge)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}