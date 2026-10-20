import 'package:flutter/material.dart';
import '../../core/services/settings_service.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';
import '../alerts/sound_alert_screen.dart';
import '../alerts/test_alert_screen.dart';
import '../contacts/contacts_screen.dart';
import 'privacy_policy_screen.dart';
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;

  // Slider values while dragging (saved when you let go)
  double? _emergencyDraft;
  double? _checkInDraft;

  String _sensitivityHelp(Sensitivity s) => switch (s) {
        Sensitivity.low =>
          'Low: fewer false alarms, but quieter or less clear sounds may be missed.',
        Sensitivity.normal => 'Normal: recommended balance.',
        Sensitivity.high =>
          'High: detects quieter or less certain sounds, but may cause more false alarms.',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _settings,
          builder: (context, _) {
            final s = _settings;
            final emergency =
                _emergencyDraft ?? s.emergencyCountdown.toDouble();
            final checkIn = _checkInDraft ?? s.checkInCountdown.toDouble();

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ================= Sounds =================
                const _Header('Sounds to detect'),
                const _SubHeader('Emergency sounds'),
                for (final c in SettingsService.alwaysOn)
                  SwitchListTile(
                    value: true,
                    onChanged: null, // locked on
                    secondary: Icon(SoundAlertScreen.iconFor(c),
                        color: AppColors.blue),
                    title: Text(c.label),
                    subtitle: const Text('Always on for your safety'),
                  ),

                const _SubHeader('Loud-bang check-in'),
                SwitchListTile(
                  value: s.isEnabled(SoundCategory.loudBang),
                  onChanged: (v) =>
                      s.setCategory(SoundCategory.loudBang, v),
                  secondary: Icon(
                      SoundAlertScreen.iconFor(SoundCategory.loudBang),
                      color: AppColors.blue),
                  title: const Text('Loud bang'),
                  subtitle: const Text(
                      'Asks "Are you safe?" and notifies contacts if you do not respond'),
                ),

                const _SubHeader('Alert-only sounds (never contact anyone)'),
                for (final c in SoundCategory.values
                    .where((c) => c.tier == SoundTier.alertOnly))
                  SwitchListTile(
                    value: s.isEnabled(c),
                    onChanged: (v) => s.setCategory(c, v),
                    secondary: Icon(SoundAlertScreen.iconFor(c),
                        color: AppColors.blue),
                    title: Text(c.label),
                  ),

                // ================= Sensitivity =================
                const _Header('Detection sensitivity'),
                SegmentedButton<Sensitivity>(
                  segments: const [
                    ButtonSegment(value: Sensitivity.low, label: Text('Low')),
                    ButtonSegment(
                        value: Sensitivity.normal, label: Text('Normal')),
                    ButtonSegment(
                        value: Sensitivity.high, label: Text('High')),
                  ],
                  selected: {s.sensitivity},
                  onSelectionChanged: (v) => s.setSensitivity(v.first),
                ),
                const SizedBox(height: 8),
                Text(_sensitivityHelp(s.sensitivity), style: text.bodyMedium),

                // ================= Alert methods =================
                const _Header('How you are alerted'),
                const _InfoBox(
                    'Visual alerts on screen are always on and never depend on sound.'),
                SwitchListTile(
                  value: s.vibration,
                  onChanged: s.setVibration,
                  secondary:
                      const Icon(Icons.vibration, color: AppColors.blue),
                  title: const Text('Vibration'),
                ),
                SwitchListTile(
                  value: s.flashlight,
                  onChanged: s.setFlashlight,
                  secondary:
                      const Icon(Icons.flashlight_on, color: AppColors.blue),
                  title: const Text('Flashlight flashing'),
                ),
                SwitchListTile(
                  value: s.localAlarm,
                  onChanged: s.setLocalAlarm,
                  secondary:
                      const Icon(Icons.volume_up, color: AppColors.blue),
                  title: const Text('Loud alarm sound'),
                  subtitle: const Text(
                      'Plays a siren on your phone when an emergency is escalated, '
                      'so people nearby can hear it'),
                ),

                // ================= Countdowns =================
                const _Header('Countdowns'),
                Text(
                  'Smoke/fire and glass: ${emergency.round()} seconds',
                  style: text.titleLarge,
                ),
                Slider(
                  value: emergency,
                  min: SettingsService.emergencyMin.toDouble(),
                  max: SettingsService.emergencyMax.toDouble(),
                  divisions: 9,
                  label: '${emergency.round()} s',
                  onChanged: (v) => setState(() => _emergencyDraft = v),
                  onChangeEnd: (v) {
                    s.setEmergencyCountdown(v.round());
                    setState(() => _emergencyDraft = null);
                  },
                ),
                Text(
                  'Loud-bang check-in: ${checkIn.round()} seconds',
                  style: text.titleLarge,
                ),
                Slider(
                  value: checkIn,
                  min: SettingsService.checkInMin.toDouble(),
                  max: SettingsService.checkInMax.toDouble(),
                  divisions: 9,
                  label: '${checkIn.round()} s',
                  onChanged: (v) => setState(() => _checkInDraft = v),
                  onChangeEnd: (v) {
                    s.setCheckInCountdown(v.round());
                    setState(() => _checkInDraft = null);
                  },
                ),
                Text(
                  'Shorter countdowns notify your contacts sooner, but give you '
                  'less time to cancel a false alarm.',
                  style: text.bodyMedium,
                ),

                // ================= Testing =================
                const _Header('Testing'),
                ListTile(
                  leading: const Icon(Icons.science_outlined,
                      color: AppColors.blue),
                  title: const Text('Test alert (simulation)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TestAlertScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.sms_outlined,
                      color: AppColors.blue),
                  title: const Text('Test SMS to emergency contacts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactsScreen()),
                  ),
                ),                const _Header('Privacy'),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.blue),
                  title: const Text('Privacy policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 22)),
      ),
    );
  }
}

class _SubHeader extends StatelessWidget {
  const _SubHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.blue)),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility, color: AppColors.navy),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}