import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/user_profile_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';
import 'dart:io' show Platform;
import '../settings/privacy_policy_screen.dart';

class PermissionsConsentScreen extends StatefulWidget {
  const PermissionsConsentScreen({super.key});

  @override
  State<PermissionsConsentScreen> createState() =>
      _PermissionsConsentScreenState();
}

class _PermissionsConsentScreenState extends State<PermissionsConsentScreen>
    with WidgetsBindingObserver {
  final _permissions = PermissionService();
  final _profile = UserProfileService();
  final Map<AppPermission, PermissionStatus> _status = {};

  bool _agreed = false;
  bool _agreeError = false;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when the user returns from phone Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    for (final p in AppPermission.values) {
            if ((p == AppPermission.sms || p == AppPermission.battery) &&
          !Platform.isAndroid) {
        continue;
      }
      _status[p] = await _permissions.status(p);
    }
    if (mounted) setState(() {});
  }

  Future<void> _request(AppPermission p) async {
    final current = _status[p];
    // If blocked, the phone won't show the popup again — open Settings
    if (current != null &&
        (current.isPermanentlyDenied || current.isRestricted)) {
      await _permissions.openSettings();
      return;
    }
    final result = await _permissions.request(p);
    if (mounted) setState(() => _status[p] = result);
  }

  Future<void> _continue() async {
    if (!_agreed) {
      setState(() => _agreeError = true);
      return;
    }

    // Warn (but don't block) if the microphone is not allowed
    final mic = _status[AppPermission.microphone];
    if (mic == null || !mic.isGranted) {
      final goOn = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Microphone not allowed'),
          content: const Text(
            'HearAble cannot detect any sounds until you allow the '
            'microphone. You can allow it later from the dashboard.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue anyway'),
            ),
          ],
        ),
      );
      if (goOn != true) return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      // The Auth Gate sees the saved consent and opens the dashboard
      await _profile.acceptPrivacy(uid).timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Saved on the phone; Firebase syncs it when back online
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Could not save. Check your internet connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions & privacy'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'HearAble needs a few permissions to alert you. '
              'Here is why each one is needed.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 20),

            // ---------- Permissions ----------
            _PermissionTile(
              icon: Icons.mic,
              title: 'Microphone',
              reason: 'To listen for alarms, breaking glass, loud bangs, '
                  'horns and doorbells. Sound is analysed on your phone '
                  'and is not recorded or uploaded.',
              status: _status[AppPermission.microphone],
              onPressed: () => _request(AppPermission.microphone),
            ),
            _PermissionTile(
              icon: Icons.notifications_active,
              title: 'Notifications',
              reason: 'To alert you when the app is in the background, and '
                  'to show that monitoring is switched on.',
              status: _status[AppPermission.notifications],
              onPressed: () => _request(AppPermission.notifications),
            ),
                        if (Platform.isAndroid)
              _PermissionTile(
                icon: Icons.sms,
                title: 'Send SMS',
                reason: 'To text your emergency contacts automatically if you '
                    'ask for help or do not respond to an emergency alert. '
                    'Also used for test messages you start yourself.',
                status: _status[AppPermission.sms],
                onPressed: () => _request(AppPermission.sms),
              ),
            const _InfoTile(
              icon: Icons.flashlight_on,
              title: 'Flashlight and vibration',
              text: 'Used to alert you by light and touch. '
                  'No permission is needed.',
            ),
            const _InfoTile(
              icon: Icons.location_on_outlined,
              title: 'Location (optional)',
              text: 'Only if you turn on location sharing later. Your '
                  'location is then included in emergency messages.',
            ),
            const SizedBox(height: 12),

            // ---------- Privacy ----------
            Semantics(
              header: true,
              child: Text('Your privacy', style: text.headlineMedium),
            ),
            const SizedBox(height: 12),
            const _Bullet('We store your name, email, phone number, emergency '
                'contacts and alert history in your private account.'),
            const _Bullet('Raw audio is never saved or uploaded by default. '
                'Sounds are classified on your phone.'),
            const _Bullet('Your name, alert type and time are shared with your '
                'emergency contacts only when an emergency alert is sent.'),
            const _Bullet('We never sell your personal data. You can delete '
                'your history and request account deletion at any time.'),
                            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Read the full privacy policy'),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Honest limitations ----------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.navy),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'HearAble may miss sounds if your phone is far away, '
                      'covered, muted, or if the phone stops background '
                      'monitoring. It cannot guarantee that alerts or '
                      'messages are delivered.',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() {
                _agreed = v ?? false;
                if (_agreed) _agreeError = false;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I agree to the privacy terms above and understand '
                'HearAble\'s limitations.',
                style: TextStyle(fontSize: 16, color: AppColors.navy),
              ),
              subtitle: _agreeError
                  ? const Text('Please agree before continuing.',
                      style: TextStyle(color: AppColors.danger))
                  : null,
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null) ErrorBanner(_errorMessage!),

            ElevatedButton(
              onPressed: _saving ? null : _continue,
              child: _saving
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _logout, child: const Text('Log out')),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Small building blocks
// ------------------------------------------------------------------

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.reason,
    required this.status,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String reason;
  final PermissionStatus? status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = status;

    final granted = s != null && (s.isGranted || s.isLimited);
    final blocked = s != null && (s.isPermanentlyDenied || s.isRestricted);

    final (label, color, statusIcon) = switch (s) {
      null => ('Checking…', AppColors.textMuted, Icons.hourglass_empty),
      _ when granted => ('Allowed', AppColors.success, Icons.check_circle),
      _ when blocked => ('Blocked — change in Settings', AppColors.danger,
          Icons.block),
      _ => ('Not allowed yet', AppColors.textMuted, Icons.radio_button_unchecked),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: AppColors.blue),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    const SizedBox(height: 4),
                    Text(reason, style: text.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: '$title permission: $label',
            excludeSemantics: true,
            child: Row(
              children: [
                Icon(statusIcon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ),
              ],
            ),
          ),
          if (s != null && !granted) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              child: Text(blocked ? 'Open Settings' : 'Allow $title'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppColors.navy),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.titleLarge),
                  const SizedBox(height: 4),
                  Text(text, style: theme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ',
              style: TextStyle(fontSize: 18, color: AppColors.navy)),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}