import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const routeName = '/welcome';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Logo
              Center(
                child: Semantics(
                  label: 'HearAble logo',
                  child: Container(
                      child: Image.asset('assets/images/logo_light.png',
                      width: 140, height: 140),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text('HearAble',
                  style: text.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('See the sounds around you.',
                  style: text.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              // What the app does
              const _FeatureRow(
                icon: Icons.graphic_eq,
                title: 'Detects important sounds',
                subtitle:
                    'Smoke alarms, breaking glass, loud bangs, doorbells and vehicle horns.',
              ),
              const _FeatureRow(
                icon: Icons.vibration,
                title: 'Visual and vibration alerts',
                subtitle:
                    'Flashing screen, flashlight and vibration — you never need to hear a sound.',
              ),
              const _FeatureRow(
                icon: Icons.contact_phone,
                title: 'Alerts your emergency contacts',
                subtitle:
                    'If you ask for help, or do not respond in time to a possible emergency.',
              ),
              const SizedBox(height: 8),

              // Honest limitation notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.navy),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'HearAble is a support tool. It cannot guarantee that '
                        'every sound is detected or that every message is delivered.',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/signup'),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/login'),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row: icon + title + description.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // MergeSemantics: screen readers read the row as one item
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.blue, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: 4),
                  Text(subtitle, style: text.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}