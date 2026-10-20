import 'package:flutter/material.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';

/// Full-screen visual alert. Readable without hearing anything.
class SoundAlertScreen extends StatefulWidget {
  const SoundAlertScreen({super.key, required this.detection});

  final SoundDetection detection;

  static IconData iconFor(SoundCategory c) => switch (c) {
        SoundCategory.smokeAlarm => Icons.local_fire_department,
        SoundCategory.glassBreaking => Icons.broken_image,
        SoundCategory.loudBang => Icons.bolt,
        SoundCategory.vehicleHorn => Icons.directions_car,
        SoundCategory.siren => Icons.campaign,
        SoundCategory.doorbell => Icons.doorbell,
        SoundCategory.knocking => Icons.door_front_door,
        SoundCategory.babyCrying => Icons.child_care,
        SoundCategory.screaming => Icons.record_voice_over,
        SoundCategory.carAlarm => Icons.car_crash,
      };

  @override
  State<SoundAlertScreen> createState() => _SoundAlertScreenState();
}

class _SoundAlertScreenState extends State<SoundAlertScreen>
    with SingleTickerProviderStateMixin {
  // Slow pulse (~1 per second) — well below seizure-risk flash rates
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    final alertOnly = d.category.tier == SoundTier.alertOnly;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Scaffold(
        backgroundColor:
            Color.lerp(AppColors.navy, AppColors.blue, _pulse.value),
        body: child,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (d.simulated)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'SIMULATED TEST — not a real sound',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black),
                  ),
                ),
              const Spacer(),
              Icon(SoundAlertScreen.iconFor(d.category),
                  size: 130, color: Colors.white),
              const SizedBox(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  d.category.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Detected at ${_time(d.detectedAt)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                alertOnly
                    ? 'Alert only — nobody has been contacted.'
                    : 'Please check your surroundings.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const Spacer(),
              SizedBox(
                height: 76,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.navy,
                    textStyle: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK, dismiss'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}