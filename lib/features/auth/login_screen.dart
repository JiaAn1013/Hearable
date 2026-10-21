import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
        await _authService.signIn(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      // The Auth Gate decides: Verify email or Dashboard
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: Image(
                      image: AssetImage('assets/images/logo_light.png'),
                      width: 90, height: 90),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text('Welcome back',
                      style: text.headlineMedium,
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 6),
                Text('Log in to continue monitoring.',
                    style: text.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 28),

                AppTextField(
                  controller: _email,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  // Only check it's filled in — not the sign-up rules
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Password is required'
                      : null,
                  onFieldSubmitted: (_) => _loading ? null : _submit(),
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/forgot-password',
                      arguments: _email.text.trim(),
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 12),

                if (_errorMessage != null) ErrorBanner(_errorMessage!),

                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Log in'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('New to HearAble?', style: text.bodyMedium),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/signup'),
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}