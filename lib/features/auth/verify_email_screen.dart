import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/error_banner.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _authService = AuthService();

  Timer? _pollTimer;
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _checking = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    // Check automatically every 5 seconds
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(silent: true),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    if (!silent) {
      setState(() {
        _errorMessage = null;
        _infoMessage = null;
      });
    }

    try {
      final verified = await _authService.reloadAndCheckVerified();
      if (!mounted) return;
      if (verified) {
        _pollTimer?.cancel();
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        return;
      }
      if (!silent) {
        setState(() => _errorMessage =
            'Not verified yet. Please tap the link in the email first.');
      }
    } catch (_) {
      if (!silent && mounted) {
        setState(() => _errorMessage =
            'Could not check. Please check your internet connection.');
      }
    } finally {
      _checking = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _resend() async {
    if (_cooldownSeconds > 0) return;
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await _authService.resendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _infoMessage = 'A new verification email has been sent.';
        _cooldownSeconds = 60;
      });
      // 60-second wait before another resend (prevents spamming)
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldownSeconds--);
        if (_cooldownSeconds <= 0) t.cancel();
      });
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    }
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final email = _authService.currentUser?.email ?? 'your email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.mark_email_unread_outlined,
                size: 80, color: AppColors.blue),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text('Check your inbox',
                  style: text.headlineMedium, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            Text('We sent a verification link to',
                style: text.bodyLarge, textAlign: TextAlign.center),
            Text(email,
                style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Tap the link in the email, then come back here. '
              'This page updates automatically. Check your spam folder too.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            if (_errorMessage != null) ErrorBanner(_errorMessage!),
            if (_infoMessage != null)
              Semantics(
                liveRegion: true,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.success),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_infoMessage!,
                            style: const TextStyle(
                                fontSize: 16, color: AppColors.success)),
                      ),
                    ],
                  ),
                ),
              ),

            ElevatedButton(
              onPressed: _checking ? null : () => _check(),
              child: _checking
                  ? const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text("I've verified my email"),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _cooldownSeconds > 0 ? null : _resend,
              child: Text(_cooldownSeconds > 0
                  ? 'Resend email in ${_cooldownSeconds}s'
                  : 'Resend verification email'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _logout,
              child: const Text('Log out / use a different account'),
            ),
          ],
        ),
      ),
    );
  }
}