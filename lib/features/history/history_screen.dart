import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/events_service.dart';
import '../../core/sound/sound_categories.dart';
import '../../core/theme/app_theme.dart';
import '../alerts/sound_alert_screen.dart';

// ==================================================================
// One saved event
// ==================================================================
class HistoryEvent {
  HistoryEvent(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;

  SoundCategory? get category {
    for (final c in SoundCategory.values) {
      if (c.name == data['categoryKey']) return c;
    }
    return null;
  }

  SoundTier? get tier {
    for (final t in SoundTier.values) {
      if (t.name == data['tier']) return t;
    }
    return null;
  }

  String get label => data['category'] as String? ?? 'Unknown sound';
  bool get simulated => data['simulated'] == true;
  bool get escalated => data['escalated'] == true;
  bool get cancelled => data['cancelledByUser'] == true;
  DateTime? get detectedAt => (data['detectedAt'] as Timestamp?)?.toDate();
  String? get outcome => data['outcome'] as String?;
  String? get userResponse => data['userResponse'] as String?;
  String? get escalationReason => data['escalationReason'] as String?;
  String? get ignoreReason => data['ignoreReason'] as String?;
  int? get muteMinutes => (data['muteMinutes'] as num?)?.toInt();
  double? get score => (data['score'] as num?)?.toDouble();

  Map<String, dynamic> get notifications {
    final n = data['notifications'];
    return n is Map ? Map<String, dynamic>.from(n) : {};
  }
}

String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}  '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String tierLabel(SoundTier? t) => switch (t) {
      SoundTier.emergency => 'Tier 2 – emergency',
      SoundTier.checkIn => 'Loud-bang check-in',
      SoundTier.alertOnly => 'Tier 1 – alert only',
      null => 'Unknown',
    };

String deliveryLabel(String? status) => switch (status) {
      'delivered' => 'Delivered ✓',
      'sent' => 'Sent (delivery not confirmed)',
      'sending' || 'queued' => 'Was still sending',
      'not_delivered' => 'Not delivered',
      'failed' => 'Failed',
      'permission_denied' => 'Not sent – SMS permission off',
      'rate_limited' => 'Not sent – rate limit',
      'simulated' => 'Simulated – not sent',
      'needs_user' || 'composer_opened' => 'Message app opened (not confirmed)',
      _ => status ?? 'Unknown',
    };

enum _TypeFilter { all, emergency, loudBang, alertOnly, tests }

enum _DateFilter { today, week, month, all, custom }

// ==================================================================
// History screen
// ==================================================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _events = EventsService();
  late final _col = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('events');

  _TypeFilter _type = _TypeFilter.all;
  _DateFilter _date = _DateFilter.week;
  DateTimeRange? _customRange;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _buildStream();

  // ---------------- Query (date filter runs in Firestore) ----------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    final now = DateTime.now();
    final DateTime? start = switch (_date) {
      _DateFilter.today => DateTime(now.year, now.month, now.day),
      _DateFilter.week => now.subtract(const Duration(days: 7)),
      _DateFilter.month => now.subtract(const Duration(days: 30)),
      _DateFilter.custom => _customRange?.start,
      _DateFilter.all => null,
    };
    final DateTime? end = _date == _DateFilter.custom && _customRange != null
        ? _customRange!.end.add(const Duration(days: 1))
        : null;

    Query<Map<String, dynamic>> q =
        _col.orderBy('detectedAt', descending: true);
    if (start != null) {
      q = q.where('detectedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start));
    }
    if (end != null) {
      q = q.where('detectedAt', isLessThan: Timestamp.fromDate(end));
    }
    return q.limit(300).snapshots();
  }

  void _setDate(_DateFilter f) {
    setState(() {
      _date = f;
      _stream = _buildStream();
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customRange,
    );
    if (range == null) return;
    _customRange = range;
    _setDate(_DateFilter.custom);
  }

  // ---------------- Type filter (runs on the phone) ----------------
  bool _matches(HistoryEvent e) => switch (_type) {
        _TypeFilter.all => true,
        _TypeFilter.emergency => !e.simulated && e.tier == SoundTier.emergency,
        _TypeFilter.loudBang => !e.simulated && e.tier == SoundTier.checkIn,
        _TypeFilter.alertOnly =>
          !e.simulated && e.tier == SoundTier.alertOnly,
        _TypeFilter.tests => e.simulated,
      };

  // ---------------- Delete ----------------
  Future<void> _deleteAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_forever,
            color: AppColors.danger, size: 40),
        title: const Text('Delete all history?'),
        content: const Text(
          'Every saved alert, including emergency records and SMS delivery '
          'details, will be permanently deleted. This cannot be undone.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete all',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final count = await _events.deleteAll();
      messenger.showSnackBar(SnackBar(
        content: Text('Deleted $count events.',
            style: const TextStyle(fontSize: 16)),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not delete history. Check your internet '
            'connection and try again.',
            style: TextStyle(fontSize: 16)),
      ));
    }
  }

  void _openDetails(HistoryEvent e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventDetails(
        event: e,
        onDelete: () async {
          Navigator.pop(context);
          await _events.delete(e.id);
        },
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Delete all history',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAll,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (f, label) in const [
                    (_TypeFilter.all, 'All'),
                    (_TypeFilter.emergency, 'Emergency'),
                    (_TypeFilter.loudBang, 'Loud bang'),
                    (_TypeFilter.alertOnly, 'Alert only'),
                    (_TypeFilter.tests, 'Tests'),
                  ])
                    ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 15)),
                      selected: _type == f,
                      onSelected: (_) => setState(() => _type = f),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (f, label) in const [
                    (_DateFilter.today, 'Today'),
                    (_DateFilter.week, '7 days'),
                    (_DateFilter.month, '30 days'),
                    (_DateFilter.all, 'All time'),
                  ])
                    ChoiceChip(
                      label: Text(label, style: const TextStyle(fontSize: 15)),
                      selected: _date == f,
                      onSelected: (_) => _setDate(f),
                    ),
                  ChoiceChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text(
                      _date == _DateFilter.custom && _customRange != null
                          ? '${_customRange!.start.day}/${_customRange!.start.month}'
                              ' – ${_customRange!.end.day}/${_customRange!.end.month}'
                          : 'Pick dates',
                      style: const TextStyle(fontSize: 15),
                    ),
                    selected: _date == _DateFilter.custom,
                    onSelected: (_) => _pickRange(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Could not load history.',
                          style: text.bodyLarge),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snap.data!.docs
                      .map((d) => HistoryEvent(d.id, d.data()))
                      .where(_matches)
                      .toList();

                  if (events.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No alerts match these filters.',
                            style: text.bodyLarge,
                            textAlign: TextAlign.center),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: events.length,
                    itemBuilder: (context, i) => _EventTile(
                      event: events[i],
                      onTap: () => _openDetails(events[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// List item
// ==================================================================
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.onTap});

  final HistoryEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final text = Theme.of(context).textTheme;
    final category = e.category;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: e.escalated && !e.simulated
                ? AppColors.danger
                : AppColors.border,
            width: e.escalated && !e.simulated ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  category == null
                      ? Icons.graphic_eq
                      : SoundAlertScreen.iconFor(category),
                  color: AppColors.blue,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(e.label, style: text.titleLarge),
                          if (e.simulated)
                            const _Badge('TEST', Colors.amber, Colors.black),
                          if (e.escalated && !e.simulated)
                            const _Badge(
                                'ESCALATED', AppColors.danger, Colors.white),
                        ],
                      ),
                      if (e.detectedAt != null)
                        Text(formatDateTime(e.detectedAt!),
                            style: text.bodyMedium),
                      if (e.outcome != null)
                        Text(e.outcome!,
                            style: text.bodyMedium?.copyWith(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.background, this.foreground);
  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: foreground)),
    );
  }
}

// ==================================================================
// Details sheet
// ==================================================================
class _EventDetails extends StatelessWidget {
  const _EventDetails({required this.event, required this.onDelete});

  final HistoryEvent event;
  final Future<void> Function() onDelete;

  String _responseLabel(HistoryEvent e) {
    switch (e.userResponse) {
      case 'safe':
        return 'Confirmed safe';
      case 'need_help':
        return 'Asked for help';
      case 'ignored':
        return 'Ignored';
    }
    if (e.cancelled) return 'Cancelled after escalation (safe)';
    if (e.escalated) return 'No response';
    return e.tier == SoundTier.alertOnly ? 'Not needed (alert only)' : '—';
  }

  @override
  Widget build(BuildContext context) {
    final e = event;
    final text = Theme.of(context).textTheme;
    final notifications = e.notifications;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            Semantics(
              header: true,
              child: Text(e.label,
                  style: text.headlineMedium?.copyWith(fontSize: 24)),
            ),
            const SizedBox(height: 16),
            _Row('Date and time',
                e.detectedAt == null ? '—' : formatDateTime(e.detectedAt!)),
            _Row('Classification', tierLabel(e.tier)),
            _Row('Real or test',
                e.simulated ? 'Simulated test' : 'Real sound detection'),
            if (!e.simulated && e.score != null)
              _Row('Model score',
                  '${e.score!.toStringAsFixed(2)} (an estimate, not a probability)'),
            _Row('Your response', _responseLabel(e)),
            _Row('Escalated', e.escalated ? 'Yes' : 'No'),
            if (e.escalationReason != null)
              _Row('Escalation reason', e.escalationReason!),
            if (e.ignoreReason != null)
              _Row(
                'False-alarm reason',
                '${e.ignoreReason}'
                    '${(e.muteMinutes ?? 0) > 0 ? ' (loud bangs muted ${e.muteMinutes} min)' : ''}',
              ),
            if (e.outcome != null) _Row('Outcome', e.outcome!),

            if (notifications.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Notification delivery', style: text.titleLarge),
              const SizedBox(height: 8),
              for (final entry in notifications.entries)
                if (entry.value is Map)
                  _Row(
                    '${(entry.value as Map)['name'] ?? 'Contact'}',
                    deliveryLabel((entry.value as Map)['status'] as String?),
                  ),
            ] else if (e.escalated) ...[
              const SizedBox(height: 12),
              _Row('Notification delivery', 'No delivery record'),
            ],

            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 2),
              ),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete this event'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.blue)),
            Text(value,
                style: const TextStyle(fontSize: 17, color: AppColors.navy)),
          ],
        ),
      ),
    );
  }
}