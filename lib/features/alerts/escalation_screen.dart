import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/alarm_player.dart';
import '../../core/services/emergency_notifier.dart';
import '../../core/services/events_service.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';

/// Shown after "I need help" or when the countdown runs out.
class EscalationScreen extends StatefulWidget {
  const EscalationScreen({
    super.key,
    required this.detection,
    required this.eventId,
    required this.reason,
  });

  final SoundDetection detection;
  final String? eventId;
  final String reason;

  @override
  State<EscalationScreen> createState() => _EscalationScreenState();
}

class _EscalationScreenState extends State<EscalationScreen> {
  final _notifier = EmergencyNotifier.instance;
  bool _alarmOn = true;

  Future<void> _call(String phone) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri(scheme: 'tel', path: phone));
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open the phone app. Number: $phone',
            style: const TextStyle(fontSize: 16)),
      ));
    }
  }

  Future<void> _stopAlarm() async {
    await AlarmPlayer.instance.stop();
    if (mounted) setState(() => _alarmOn = false);
  }

  Future<void> _cancel() async {
    final reached = _notifier.anyReached;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel the emergency alert?'),
        content: Text(
          'Only do this if you are safe.'
          '${reached ? '\n\nContacts who received the alert will get an '
              '"I am safe" message.' : ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep alert'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, I'm safe"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    EventsService().markCancelled(widget.eventId);
    _notifier.sendAllClear();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    const white = TextStyle(color: Colors.white);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF6B0000),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (d.simulated)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'SIMULATED TEST — no messages are sent',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.black),
                  ),
                ),
              const Icon(Icons.campaign, size: 90, color: Colors.white),
              Semantics(
                liveRegion: true,
                header: true,
                child: Text('EMERGENCY ALERT STARTED',
                    textAlign: TextAlign.center,
                    style: white.copyWith(
                        fontSize: 30, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(height: 8),
              Text('${d.category.label} • ${widget.reason}',
                  textAlign: TextAlign.center,
                  style: white.copyWith(fontSize: 18)),
              if (widget.eventId != null)
                Text('Event ID: ${widget.eventId}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 20),

              // Live per-contact delivery status + call buttons
              ListenableBuilder(
                listenable: _notifier,
                builder: (context, _) =>
                    _DeliveryCard(notifier: _notifier, onCall: _call),
              ),
              const SizedBox(height: 16),

              if (_alarmOn)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                  onPressed: _stopAlarm,
                  icon: const Icon(Icons.volume_off),
                  label: const Text('Stop alarm sound'),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _cancel,
                  icon: const Icon(Icons.check_circle, size: 30),
                  label: const Text("I'm safe — cancel alert"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close this screen',
                    style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// Delivery status card
// ==================================================================
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.notifier, required this.onCall});

  final EmergencyNotifier notifier;
  final void Function(String phone) onCall;

  (IconData, Color) _look(String status) => switch (status) {
        'delivered' => (Icons.check_circle, AppColors.success),
        'sent' => (Icons.done, AppColors.success),
        'sending' || 'queued' => (Icons.schedule, AppColors.blue),
        'simulated' => (Icons.science_outlined, AppColors.textMuted),
        'needs_user' || 'composer_opened' => (Icons.sms_outlined, AppColors.blue),
        _ => (Icons.error, AppColors.danger),
      };

  @override
  Widget build(BuildContext context) {
    final problem = notifier.hasProblem;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Emergency messages',
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              notifier.summary,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: problem ? AppColors.danger : AppColors.navy,
              ),
            ),
          ),
          if (notifier.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 12),

          for (final d in notifier.deliveries) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MergeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_look(d.status).$1,
                            color: _look(d.status).$2, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.contact.name,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.navy)),
                              Text(
                                  '${d.contact.roleLabel} • ${d.contact.phone}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              Text(d.label,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _look(d.status).$2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (d.status == 'needs_user' ||
                      d.status == 'composer_opened') ...[
                    OutlinedButton.icon(
                      onPressed: () => notifier.openComposer(d),
                      icon: const Icon(Icons.sms),
                      label: const Text('Send message'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => onCall(d.contact.phone),
                    icon: const Icon(Icons.call),
                    label: Text('Call ${d.contact.name}'),
                  ),
                ],
              ),
            ),
          ],

          if (notifier.canRetry)
            OutlinedButton.icon(
              onPressed: notifier.retryFailed,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry failed messages'),
            ),
        ],
      ),
    );
  }
}