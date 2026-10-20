import 'package:flutter/material.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';
import 'alert_coordinator.dart';
import 'sound_alert_screen.dart';

/// Simulation mode for demonstrations. Every simulated alert is
/// clearly labelled and saved to history as a TEST.
class TestAlertScreen extends StatelessWidget {
  const TestAlertScreen({super.key});

  String _tierLabel(SoundTier t) => switch (t) {
        SoundTier.emergency => 'Tier 2 – emergency',
        SoundTier.checkIn => 'Loud-bang check-in',
        SoundTier.alertOnly => 'Tier 1 – alert only',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Test alert')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                border: Border.all(color: Colors.amber.shade700, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Simulation mode. These alerts are NOT real sound '
                'detections. They are labelled "SIMULATED" and saved to '
                'your history as tests. Simulated alerts never contact '
                'your emergency contacts.',
                style: text.bodyLarge,
              ),
            ),
            const SizedBox(height: 20),
            for (final c in SoundCategory.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  onPressed: () => AlertCoordinator.instance.handle(
                    SoundDetection(
                      category: c,
                      score: 1.0,
                      detectedAt: DateTime.now(),
                      simulated: true,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(SoundAlertScreen.iconFor(c),
                          color: AppColors.blue),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Simulate: ${c.label}'),
                            Text(_tierLabel(c.tier),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}