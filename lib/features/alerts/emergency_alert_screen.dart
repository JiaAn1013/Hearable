import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/alert_effects.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';
import 'sound_alert_screen.dart';

enum DecisionType { safe, needHelp, ignore, timeout }

class AlertDecision {
  const AlertDecision(this.type, {this.ignoreReason, this.muteMinutes = 0});
  final DecisionType type;
  final String? ignoreReason;
  final int muteMinutes;
}

/// Full-screen "Are you safe?" screen with countdown.
class EmergencyAlertScreen extends StatefulWidget {
  const EmergencyAlertScreen({
    super.key,
    required this.detection,
    required this.countdownSeconds,
    required this.allowIgnore,
  });

  final SoundDetection detection;
  final int countdownSeconds;
  final bool allowIgnore;

  @override
  State<EmergencyAlertScreen> createState() => _EmergencyAlertScreenState();
}

class _EmergencyAlertScreenState extends State<EmergencyAlertScreen>
    with SingleTickerProviderStateMixin {
  late int _remaining = widget.countdownSeconds;
  Timer? _timer;
  bool _paused = false;
  bool _done = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _tick() {
    if (_paused || _done || !mounted) return;
    setState(() => _remaining--);
    if (_remaining <= 0) {
      _finish(const AlertDecision(DecisionType.timeout));
      return;
    }
    // Vibrate again every 10 seconds
    if (_remaining % 10 == 0) AlertEffects.instance.vibrate(urgent: true);
  }

  void _finish(AlertDecision decision) {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    Navigator.of(context).pop(decision);
  }

  Future<void> _ignore() async {
    // The user is responding, so pause the countdown while they choose
    setState(() => _paused = true);
    final result = await showModalBottomSheet<AlertDecision>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const IgnoreReasonSheet(),
    );
    if (!mounted) return;
    if (result != null) {
      _finish(result);
    } else {
      setState(() => _paused = false);
    }
  }

  Widget _testBanner(String text) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black)),
      );

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    final isBang = d.category == SoundCategory.loudBang;
    final title = isBang
        ? 'LOUD BANG DETECTED'
        : '${d.category.label.toUpperCase()} DETECTED';
    final message = isBang
        ? 'Loud bang detected near you. Please check your surroundings.'
        : 'A possible emergency has been detected. Are you safe?';
    final total = widget.countdownSeconds;

    return PopScope(
      canPop: false, // Back button must not dismiss an emergency
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Scaffold(
          backgroundColor: Color.lerp(
              const Color(0xFF6B0000), AppColors.danger, _pulse.value),
          body: child,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.simulated)
                  _testBanner('SIMULATED TEST — contacts will NOT be notified'),
                Icon(SoundAlertScreen.iconFor(d.category),
                    size: 96, color: Colors.white),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
                const SizedBox(height: 12),
                Text(message,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 20, color: Colors.white)),
                const SizedBox(height: 20),

                // Countdown
                Center(
                  child: Semantics(
                    label: '$_remaining seconds left before your emergency '
                        'contacts are notified',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 170,
                      height: 170,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: _remaining / total,
                            strokeWidth: 12,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$_remaining',
                                    style: const TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white)),
                                const Text('seconds',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  d.simulated
                      ? 'This is a test. Nobody will be contacted.'
                      : 'Emergency contacts will be notified if you do not '
                          'respond.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text('Detected — nothing has been sent yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 24),

                // Actions
                SizedBox(
                  height: 80,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () =>
                        _finish(const AlertDecision(DecisionType.safe)),
                    icon: const Icon(Icons.check_circle, size: 32),
                    label: const Text("I'm safe"),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 80,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      textStyle: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () =>
                        _finish(const AlertDecision(DecisionType.needHelp)),
                    icon: const Icon(Icons.sos, size: 32),
                    label: const Text('I need help'),
                  ),
                ),
                if (widget.allowIgnore) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _ignore,
                    child: const Text('Ignore',
                        style: TextStyle(
                            fontSize: 18,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// Ignore reason + mute duration (loud bang only)
// ==================================================================
class IgnoreReasonSheet extends StatefulWidget {
  const IgnoreReasonSheet({super.key});

  @override
  State<IgnoreReasonSheet> createState() => _IgnoreReasonSheetState();
}

class _IgnoreReasonSheetState extends State<IgnoreReasonSheet> {
  static const _reasons = [
    'I dropped something',
    'Door slammed',
    'Renovation nearby',
    'TV or music',
    'Other',
  ];
  static const _muteOptions = [0, 1, 5, 10];

  String? _reason;
  int _mute = 0;

  String _muteLabel(int m) =>
      m == 0 ? "Don't mute" : '$m minute${m == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('Why are you ignoring this?',
                  style: text.titleLarge?.copyWith(fontSize: 22)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _reasons)
                  ChoiceChip(
                    label: Text(r, style: const TextStyle(fontSize: 16)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Mute loud-bang alerts for:', style: text.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _muteOptions)
                  ChoiceChip(
                    label: Text(_muteLabel(m),
                        style: const TextStyle(fontSize: 16)),
                    selected: _mute == m,
                    onSelected: (_) => setState(() => _mute = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Smoke alarm and glass-breaking alerts are never muted.',
                style: text.bodyMedium),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reason == null
                  ? null
                  : () => Navigator.pop(
                        context,
                        AlertDecision(
                          DecisionType.ignore,
                          ignoreReason: _reason,
                          muteMinutes: _mute,
                        ),
                      ),
              child: const Text('Confirm'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to alert'),
            ),
          ],
        ),
      ),
    );
  }
}