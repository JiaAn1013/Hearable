import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static const routeName = '/signup';

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // Your details
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  // Emergency contacts
  final _c1Name = TextEditingController();
  final _c1Phone = TextEditingController();
  final _c2Name = TextEditingController();
  final _c2Phone = TextEditingController();
  final _guardPhone = TextEditingController();

  bool _showSecondContact = false;
  bool _contactConsent = false;
  bool _consentError = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _password, _confirm,
      _c1Name, _c1Phone, _c2Name, _c2Phone, _guardPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Contact numbers must be valid and different from the user's own.
  String? _validateContactPhone(String? value, {bool isRequired = true}) {
    final error = Validators.phone(value, isRequired: isRequired);
    if (error != null || value == null || value.trim().isEmpty) return error;
    final own = Validators.normalizePhone(_phone.text);
    if (own != null && Validators.normalizePhone(value) == own) {
      return 'Use a different number from your own';
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _consentError = !_contactConsent;
    });

    final formValid = _formKey.currentState!.validate();
    if (!formValid || !_contactConsent) return;

    final contacts = <EmergencyContactInput>[
      EmergencyContactInput(
        name: _c1Name.text.trim(),
        phone: Validators.normalizePhone(_c1Phone.text)!,
        role: ContactRole.primary,
      ),
      if (_showSecondContact)
        EmergencyContactInput(
          name: _c2Name.text.trim(),
          phone: Validators.normalizePhone(_c2Phone.text)!,
          role: ContactRole.secondary,
        ),
      if (_guardPhone.text.trim().isNotEmpty)
        EmergencyContactInput(
          name: 'Guard house',
          phone: Validators.normalizePhone(_guardPhone.text)!,
          role: ContactRole.guardHouse,
        ),
    ];

    setState(() => _loading = true);
    try {
      await _authService.signUp(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: Validators.normalizePhone(_phone.text)!,
        contacts: contacts,
      );
      if (!mounted) return;
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
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ---------- Your details ----------
                const _SectionTitle('Your details'),
                AppTextField(
                  controller: _name,
                  label: 'Full name',
                  icon: Icons.person_outline,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => Validators.notEmpty(v, 'Full name'),
                ),
                AppTextField(
                  controller: _email,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                ),
                AppTextField(
                  controller: _phone,
                  label: 'Your phone number',
                  hint: 'e.g. 012-345 6789',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: Validators.phone,
                ),
                AppTextField(
                  controller: _password,
                  label: 'Password',
                  helper: 'At least 8 characters, with letters and numbers',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                ),
                AppTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) =>
                      Validators.confirmPassword(v, _password.text),
                ),

                // ---------- Primary emergency contact ----------
                const _SectionTitle(
                  'Emergency contact',
                  subtitle: 'This person will be alerted if you need help.',
                ),
                AppTextField(
                  controller: _c1Name,
                  label: 'Contact name',
                  icon: Icons.person_pin_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.notEmpty(v, 'Contact name'),
                ),
                AppTextField(
                  controller: _c1Phone,
                  label: 'Contact phone number',
                  hint: 'e.g. 012-345 6789',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: _validateContactPhone,
                ),

                // ---------- Optional second contact ----------
                if (_showSecondContact) ...[
                  const _SectionTitle('Second emergency contact'),
                  AppTextField(
                    controller: _c2Name,
                    label: 'Second contact name',
                    icon: Icons.person_pin_outlined,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.notEmpty(v, 'Second contact name'),
                  ),
                  AppTextField(
                    controller: _c2Phone,
                    label: 'Second contact phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: _validateContactPhone,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() {
                        _showSecondContact = false;
                        _c2Name.clear();
                        _c2Phone.clear();
                      }),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Remove second contact'),
                    ),
                  ),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _showSecondContact = true),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add a second emergency contact'),
                    ),
                  ),

                // ---------- Optional guard house ----------
                const _SectionTitle(
                  'Guard house or security (optional)',
                  subtitle: 'For example, your condominium guard house.',
                ),
                AppTextField(
                  controller: _guardPhone,
                  label: 'Guard-house phone number',
                  hint: 'e.g. 04-123 4567',
                  icon: Icons.security_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      _validateContactPhone(v, isRequired: false),
                ),

                // ---------- Consent ----------
                CheckboxListTile(
                  value: _contactConsent,
                  onChanged: (v) => setState(() {
                    _contactConsent = v ?? false;
                    if (_contactConsent) _consentError = false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'My emergency contacts have agreed to be contacted by '
                    'HearAble if I may be in danger.',
                    style: TextStyle(fontSize: 16, color: AppColors.navy),
                  ),
                  subtitle: _consentError
                      ? const Text(
                          'Please confirm this before continuing.',
                          style: TextStyle(color: AppColors.danger),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                // ---------- Error message ----------
                if (_errorMessage != null)
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        border: Border.all(color: AppColors.danger),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: const TextStyle(
                                    fontSize: 16, color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ---------- Submit ----------
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account?', style: text.bodyMedium),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Log in'),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleLarge?.copyWith(fontSize: 20)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: text.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}