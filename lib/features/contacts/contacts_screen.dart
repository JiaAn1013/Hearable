import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart' show ContactRole;
import '../../core/services/contacts_service.dart';
import '../../core/theme/app_theme.dart';
import 'contact_form_screen.dart';
import 'dart:io' show Platform;
import '../../core/services/sms_service.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  void _openForm(
    BuildContext context, {
    required ContactRole role,
    required List<EmergencyContact> all,
    EmergencyContact? existing,
  }) {
    final otherPhones = all
        .where((c) => c.id != existing?.id)
        .map((c) => c.phone)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactFormScreen(
          role: role,
          existing: existing,
          otherPhones: otherPhones,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EmergencyContact contact,
    List<EmergencyContact> all,
  ) async {
    final personalCount = all.where((c) => c.isPersonal).length;
    final isLastPersonal = contact.isPersonal && personalCount == 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: isLastPersonal
            ? const Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 40)
            : null,
        title: Text(isLastPersonal
            ? 'Remove your only emergency contact?'
            : 'Remove ${contact.name}?'),
        content: Text(
          isLastPersonal
              ? 'HearAble will not be able to notify anyone in an '
                  'emergency until you add a new contact.'
              : 'They will no longer receive HearAble emergency alerts.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ContactsService().delete(_uid, contact, all);
    }
  }
  Future<void> _sendTest(BuildContext context, EmergencyContact c) async {
    final sms = SmsService.instance;
    final messenger = ScaffoldMessenger.of(context);

    if (!await sms.ensurePermission()) {
      messenger.showSnackBar(const SnackBar(
        content: Text('SMS permission is needed to send a test message.',
            style: TextStyle(fontSize: 16)),
      ));
      return;
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send a test SMS to ${c.name}?'),
        content: Text(
          'A short test message will be sent to ${c.phone} from your '
          'phone. Normal SMS charges from your mobile plan apply.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send test'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ContactsService();
    final userName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'A HearAble user';
    await service.setTestStatus(_uid, c.id, 'sending');

    sms
        .sendTracked(
          id: 'test-${c.id}-${DateTime.now().millisecondsSinceEpoch}',
          phone: c.phone,
          message: SmsService.testMessage(userName),
        )
        .listen((u) {
      if (u.status == 'submitted') return;
      service.setTestStatus(_uid, c.id, u.status);
      if (u.status == 'failed') {
        messenger.showSnackBar(SnackBar(
          content: Text('Test SMS failed: ${u.error ?? 'unknown error'}',
              style: const TextStyle(fontSize: 16)),
        ));
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency contacts')),
      body: SafeArea(
        child: StreamBuilder<List<EmergencyContact>>(
          stream: ContactsService().watch(_uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Could not load your contacts.',
                      style: TextStyle(fontSize: 18)),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final all = snapshot.data!;
            final hasPrimary = all.any((c) => c.role == ContactRole.primary);
            final hasSecond = all.any((c) => c.role == ContactRole.secondary);
            final hasGuard = all.any((c) => c.role == ContactRole.guardHouse);

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (!hasPrimary) const _NoContactWarning(),

                for (final c in all)
                  _ContactCard(
                    contact: c,
                    onEdit: () => _openForm(context,
                        role: c.role, all: all, existing: c),
                    onMakePrimary: c.role == ContactRole.secondary
                        ? () => ContactsService().makePrimary(_uid, c, all)
                        : null,
                    onDelete: () => _confirmDelete(context, c, all),
                                        onTestSms: Platform.isAndroid
                        ? () => _sendTest(context, c)
                        : null,
                  ),

                const SizedBox(height: 8),
                if (!hasPrimary)
                  ElevatedButton.icon(
                    onPressed: () => _openForm(context,
                        role: ContactRole.primary, all: all),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add emergency contact'),
                  )
                else if (!hasSecond)
                  OutlinedButton.icon(
                    onPressed: () => _openForm(context,
                        role: ContactRole.secondary, all: all),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Add second contact'),
                  ),
                if (!hasGuard) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openForm(context,
                        role: ContactRole.guardHouse, all: all),
                    icon: const Icon(Icons.security),
                    label: const Text('Add guard-house number'),
                  ),
                ],
                const SizedBox(height: 24),
                                Text(
                  Platform.isAndroid
                      ? 'Test SMS messages are sent from your phone. '
                          'Normal SMS charges apply.'
                      : 'On iPhone, emergency messages open in Messages for '
                          'you to send.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoContactWarning extends StatelessWidget {
  const _NoContactWarning();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          border: Border.all(color: AppColors.danger, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.danger, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No emergency contact set. HearAble cannot notify anyone '
                'if you need help.',
                style: TextStyle(fontSize: 16, color: AppColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    this.onMakePrimary,
    this.onTestSms,
  });

  final EmergencyContact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onTestSms;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isPrimary = contact.role == ContactRole.primary;

    final icon = switch (contact.role) {
      ContactRole.primary => Icons.star,
      ContactRole.secondary => Icons.person,
      ContactRole.guardHouse => Icons.security,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.lightBlue : Colors.white,
        border: Border.all(
          color: isPrimary ? AppColors.blue : AppColors.border,
          width: isPrimary ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Icon(icon, color: AppColors.blue, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact.roleLabel.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue,
                              letterSpacing: 0.5)),
                      const SizedBox(height: 2),
                      Text(contact.name, style: text.titleLarge),
                      Text(contact.phone, style: text.bodyLarge),
                      const SizedBox(height: 4),
                      Text(contact.testStatusLabel, style: text.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
                    Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
              if (onMakePrimary != null)
                TextButton.icon(
                  onPressed: onMakePrimary,
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Set as primary'),
                ),
              if (onTestSms != null)
                TextButton.icon(
                  onPressed: onTestSms,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send test SMS'),
                ),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
                label: const Text('Remove',
                    style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}