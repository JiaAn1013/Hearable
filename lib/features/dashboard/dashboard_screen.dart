import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/auth_service.dart' show AuthService, ContactRole;
import '../../core/services/contacts_service.dart';
import '../../core/services/monitoring_controller.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/app_theme.dart';
import '../contacts/contacts_screen.dart';
import '../../core/sound/yamnet_engine.dart';
import '../alerts/test_alert_screen.dart';
import 'dart:io' show Platform;
import '../../core/services/background_service.dart';
import '../../core/services/settings_service.dart';
import '../settings/settings_screen.dart';
import '../history/history_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final _permissions = PermissionService();
  final _monitor = MonitoringController.instance;

  PermissionStatus? _mic;
  PermissionStatus? _notifications;
  PermissionStatus? _sms;
  PermissionStatus? _battery;
  bool? _fullScreenOk;

  late final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final _userDoc =
      FirebaseFirestore.instance.collection('users').doc(_uid);
  late final _profileStream = _userDoc.snapshots();
  late final _contactsStream = ContactsService().watch(_uid);
  late final _eventsStream = _userDoc
      .collection('events')
      .orderBy('detectedAt', descending: true)
      .limit(5)
      .snapshots();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
        SettingsService.instance.attach(_uid);
    _refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions();
  }

  Future<void> _refreshPermissions() async {
    final mic = await _permissions.status(AppPermission.microphone);
    final notif = await _permissions.status(AppPermission.notifications);
        final sms = Platform.isAndroid
        ? await _permissions.status(AppPermission.sms)
        : null;
    final battery = Platform.isAndroid
        ? await _permissions.status(AppPermission.battery)
        : null;
    final fullScreen = await BackgroundService.instance.canUseFullScreenAlerts();
    if (!mounted) return;
    setState(() {
      _mic = mic;
      _notifications = notif;
      _sms = sms;
      _battery = battery;
      _fullScreenOk = fullScreen;
    });
    // Microphone removed while monitoring? Say so honestly.
    if (!mic.isGranted && _monitor.isActive) {
      await _monitor.stop();
      _monitor.reportStopped(
          'Monitoring stopped because microphone permission was turned off.');
    }
  }

  Future<void> _fixPermission(AppPermission p, PermissionStatus? s) async {
    if (s != null && (s.isPermanentlyDenied || s.isRestricted)) {
      await _permissions.openSettings();
      return;
    }
    await _permissions.request(p);
    await _refreshPermissions();
  }

  Future<void> _toggleMonitoring() async {
    if (_monitor.isActive) {
      await _monitor.stop();
    } else {
      await _monitor.start();
    }
    await _refreshPermissions();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Monitoring will stop and you will not receive HearAble alerts '
          'while logged out.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _monitor.stop();
        SettingsService.instance.detach();
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _openContacts() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ContactsScreen()),
      );

  String _permissionLabel(PermissionStatus? s) {
    if (s == null) return 'Checking…';
    if (s.isGranted || s.isLimited) return 'Allowed';
    if (s.isPermanentlyDenied || s.isRestricted) {
      return 'Blocked — tap to open Settings';
    }
    return 'Not allowed — tap to allow';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final micOk = _mic?.isGranted ?? false;
    final notifOk = _notifications?.isGranted ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HearAble'),
        automaticallyImplyLeading: false,
        actions: [
                    IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
                    IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ---------- Welcome ----------
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _profileStream,
              builder: (context, snap) {
                final name = snap.data?.data()?['fullName'] as String? ??
                    FirebaseAuth.instance.currentUser?.displayName ??
                    '';
                return Semantics(
                  header: true,
                  child: Text(
                    name.isEmpty ? 'Welcome' : 'Welcome, $name',
                    style: text.headlineMedium,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // ---------- Monitoring card ----------
            ListenableBuilder(
              listenable: _monitor,
              builder: (context, _) => _MonitoringCard(
                controller: _monitor,
                onToggle: _toggleMonitoring,
              ),
            ),
            const SizedBox(height: 16),
            const _LiveSoundCard(),
            const SizedBox(height: 24),

            // ---------- Status ----------
            const _SectionTitle('Status'),
            _StatusRow(
              icon: Icons.mic,
              label: 'Microphone',
              value: _permissionLabel(_mic),
              ok: micOk,
              onTap: micOk
                  ? null
                  : () => _fixPermission(AppPermission.microphone, _mic),
            ),
            _StatusRow(
              icon: Icons.notifications_active,
              label: 'Notifications',
              value: _permissionLabel(_notifications),
              ok: notifOk,
              onTap: notifOk
                  ? null
                  : () => _fixPermission(
                      AppPermission.notifications, _notifications),
            ),
                        if (Platform.isAndroid)
              _StatusRow(
                icon: Icons.sms,
                label: 'Emergency SMS',
                value: _permissionLabel(_sms),
                ok: _sms?.isGranted ?? false,
                onTap: (_sms?.isGranted ?? false)
                    ? null
                    : () => _fixPermission(AppPermission.sms, _sms),
              ),
                          if (Platform.isAndroid) ...[
              _StatusRow(
                icon: Icons.battery_alert,
                label: 'Battery optimisation',
                value: (_battery?.isGranted ?? false)
                    ? 'Unrestricted'
                    : 'Restricted — tap so HearAble can run in the background',
                ok: _battery?.isGranted ?? false,
                onTap: (_battery?.isGranted ?? false)
                    ? null
                    : () => _fixPermission(AppPermission.battery, _battery),
              ),
              _StatusRow(
                icon: Icons.fullscreen,
                label: 'Full-screen alerts',
                value: (_fullScreenOk ?? true)
                    ? 'Allowed'
                    : 'Off — tap to allow alerts over the lock screen',
                ok: _fullScreenOk ?? true,
                onTap: (_fullScreenOk ?? true)
                    ? null
                    : BackgroundService.instance.openFullScreenSettings,
              ),
            ],
            StreamBuilder<List<EmergencyContact>>(
              stream: _contactsStream,
              builder: (context, snap) {
                final all = snap.data ?? [];
                final hasPrimary =
                    all.any((c) => c.role == ContactRole.primary);
                final personal = all.where((c) => c.isPersonal).length;
                final hasGuard =
                    all.any((c) => c.role == ContactRole.guardHouse);

                final value = !snap.hasData
                    ? 'Checking…'
                    : !hasPrimary
                        ? 'None set — tap to add'
                        : '$personal contact${personal == 1 ? '' : 's'}'
                            '${hasGuard ? ' + guard house' : ''}';

                return _StatusRow(
                  icon: Icons.contacts,
                  label: 'Emergency contacts',
                  value: value,
                  ok: hasPrimary,
                  onTap: _openContacts,
                );
              },
            ),
            const SizedBox(height: 24),

            // ---------- Recent alerts ----------
            const _SectionTitle('Recent alerts'),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _eventsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Could not load alert history.',
                      style: text.bodyMedium);
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'No alerts yet. Detected sounds will appear here.',
                      style: text.bodyLarge,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final d in docs) _EventRow(data: d.data()),
                  ],
                );
              },
            ),
                        Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                icon: const Icon(Icons.history),
                label: const Text('See full history'),
              ),
            ),
            const SizedBox(height: 28),

            // ---------- Navigation ----------
            ElevatedButton.icon(
              onPressed: _openContacts,
              icon: const Icon(Icons.contacts),
              label: const Text('Emergency contacts'),
            ),
                        const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestAlertScreen()),
              ),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Test alert'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// Monitoring status card
// ==================================================================
class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.controller, required this.onToggle});

  final MonitoringController controller;
  final VoidCallback onToggle;

  (String, String, Color, IconData) _describe() {
    // An emergency always takes priority on screen
    switch (controller.alertState) {
      case AlertState.pending:
        return (
          'Emergency alert pending',
          'Respond to the alert on screen.',
          AppColors.danger,
          Icons.warning_amber_rounded,
        );
      case AlertState.notificationSent:
        return (
          'Emergency notification sent',
          'Your emergency contacts are being notified. '
              'Check the delivery status in your history.',
          AppColors.danger,
          Icons.campaign,
        );
      case AlertState.none:
        break;
    }

    return switch (controller.status) {
            MonitoringStatus.active => (
          'Monitoring active',
          controller.message ?? 'HearAble is listening for important sounds.',
          AppColors.success,
          Icons.hearing,
        ),
      MonitoringStatus.starting => (
          'Starting…',
          'Getting the microphone ready.',
          AppColors.blue,
          Icons.hourglass_top,
        ),
      MonitoringStatus.paused => (
          'Monitoring paused',
          'You will not receive sound alerts until you start monitoring.',
          AppColors.navy,
          Icons.hearing_disabled,
        ),
      MonitoringStatus.permissionRequired => (
          'Permission required',
          controller.message ?? 'Allow the microphone to start monitoring.',
          AppColors.danger,
          Icons.mic_off,
        ),
      MonitoringStatus.unavailable => (
          'Monitoring unavailable',
          controller.message ?? 'Monitoring is not running.',
          AppColors.danger,
          Icons.error_outline,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (title, message, color, icon) = _describe();
    final isActive = controller.status == MonitoringStatus.active;
    final isStarting = controller.status == MonitoringStatus.starting;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 44, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: color)),
                      const SizedBox(height: 4),
                      Text(message,
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 72,
              child: isActive
                  ? OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: const Icon(Icons.stop_circle_outlined, size: 30),
                      label: const Text('Stop monitoring'),
                    )
                  : ElevatedButton.icon(
                      onPressed: isStarting ? null : onToggle,
                      icon: isStarting
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child:
                                  CircularProgressIndicator(strokeWidth: 3),
                            )
                          : const Icon(Icons.play_circle_fill, size: 30),
                      label:
                          Text(isStarting ? 'Starting…' : 'Start monitoring'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// Small building blocks
// ==================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(title,
            style:
                Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21)),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.ok,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.danger;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: ok ? AppColors.border : AppColors.danger),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.blue, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(value,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      ],
                    ),
                  ),
                  Icon(ok ? Icons.check_circle : Icons.error, color: color),
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, color: AppColors.navy),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.data});
  final Map<String, dynamic> data;

  static String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} '
        '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final category = data['category'] as String? ?? 'Unknown sound';
    final detectedAt = (data['detectedAt'] as Timestamp?)?.toDate();
    final outcome = data['outcome'] as String?;

    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    [
                      if (detectedAt != null) _formatTime(detectedAt),
                      ?outcome,
                    ].join(' • '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ==================================================================
// Live sound display (only while monitoring is active)
// ==================================================================
class _LiveSoundCard extends StatelessWidget {
  const _LiveSoundCard();

  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final monitor = MonitoringController.instance;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final engine = monitor.engine;
        if (!monitor.isActive || engine is! YamnetSoundEngine) {
          return const SizedBox.shrink();
        }
        final last = monitor.lastDetection;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What HearAble hears now', style: text.titleLarge),
              const SizedBox(height: 4),
              Text('Model scores are estimates, not certainties.',
                  style: text.bodyMedium),
              const SizedBox(height: 10),
              ValueListenableBuilder<List<(String, double)>>(
                valueListenable: engine.topSounds,
                builder: (context, top, _) {
                  if (top.isEmpty) {
                    return Text('Listening…', style: text.bodyLarge);
                  }
                  return Column(
                    children: [
                      for (final (name, score) in top)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(name, style: text.bodyLarge)),
                              Text(score.toStringAsFixed(2),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.blue)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 24),
              Semantics(
                liveRegion: true,
                child: Text(
                  last == null
                      ? 'No important sound detected yet.'
                      : 'Last detected: ${last.category.label} '
                          'at ${_time(last.detectedAt)}',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}