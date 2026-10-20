import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart' show ContactRole;
import '../../core/services/contacts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/error_banner.dart';

class ContactFormScreen extends StatefulWidget {
  const ContactFormScreen({
    super.key,
    required this.role,
    this.existing,
    this.otherPhones = const [],
  });

  final ContactRole role;
  final EmergencyContact? existing; // null = adding a new contact
  final List<String> otherPhones; // to prevent duplicate numbers

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = ContactsService();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  bool _consent = false;
  bool _consentError = false;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEdit => widget.existing != null;
  bool get _isGuardHouse => widget.role == ContactRole.guardHouse;
  bool get _needsConsent => !_isEdit && !_isGuardHouse;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existing?.name ?? (_isGuardHouse ? 'Guard house' : ''),
    );
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final error = Validators.phone(value);
    if (error != null) return error;
    final normalized = Validators.normalizePhone(value!);
    if (widget.otherPhones.contains(normalized)) {
      return 'This number is already one of your contacts';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _consentError = _needsConsent && !_consent;
    });
    if (!_formKey.currentState!.validate() || _consentError) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = _name.text.trim();
    final phone = Validators.normalizePhone(_phone.text)!;

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.update(
          uid,
          widget.existing!.id,
          name: name,
          phone: phone,
          phoneChanged: phone != widget.existing!.phone,
        );
      } else {
        await _service.add(uid, name: name, phone: phone, role: widget.role);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage =
            'Could not save this contact. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? 'Edit contact'
        : _isGuardHouse
            ? 'Add guard-house number'
            : 'Add emergency contact';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              AppTextField(
                controller: _name,
                label: _isGuardHouse ? 'Label' : 'Contact name',
                icon: _isGuardHouse
                    ? Icons.security_outlined
                    : Icons.person_pin_outlined,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.notEmpty(v, 'Name'),
              ),
              AppTextField(
                controller: _phone,
                label: 'Phone number',
                hint: _isGuardHouse ? 'e.g. 04-123 4567' : 'e.g. 012-345 6789',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                validator: _validatePhone,
              ),
              if (_needsConsent)
                CheckboxListTile(
                  value: _consent,
                  onChanged: (v) => setState(() {
                    _consent = v ?? false;
                    if (_consent) _consentError = false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'This person has agreed to be contacted by HearAble '
                    'if I may be in danger.',
                    style: TextStyle(fontSize: 16, color: AppColors.navy),
                  ),
                  subtitle: _consentError
                      ? const Text('Please confirm this before saving.',
                          style: TextStyle(color: AppColors.danger))
                      : null,
                ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ErrorBanner(_errorMessage!),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text('Save contact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}