import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/routine_config.dart';
import '../../providers/repository_providers.dart';
import '../../providers/water_providers.dart';
import '../../services/battery_optimization_service.dart';
import '../../services/notification_service.dart';
import '../../services/phone_usage_prefs.dart';
import '../../services/phone_usage_service.dart';
import '../../services/reminder_prefs.dart';
import '../../services/reminder_scheduler.dart';
import '../screen_scaffold.dart';

/// RoutineConfig editor + reminders — this is where "configurable, not
/// hard-coded" is enforced. See PROJECT_PLAN.md §3 and
/// lib/domain/routine_config.dart.
///
/// Two persistence layers meet here, deliberately: the "Hydration goal"
/// card edits the real `RoutineConfig` row (via `RoutineConfigRepository`,
/// JSON blob in sqflite) — the first (and so far only) RoutineConfig
/// section actually wired to a UI, per PROJECT_PLAN.md §7. Everything
/// else — reminder on/off + time-of-day for every habit (water, dhyana,
/// desk breaks, knee/weight check-ins), quiet hours — is stored via
/// [ReminderPrefs] (SharedPreferences) and turned into scheduled local
/// notifications by [ReminderScheduler]; see both for why that's a
/// separate, simpler store rather than more RoutineConfig sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionHeader('Hydration goal'),
          SizedBox(height: 8),
          _HydrationGoalCard(),
          SizedBox(height: 24),
          _SectionHeader('Reminders'),
          SizedBox(height: 8),
          _WaterReminderCard(),
          SizedBox(height: 12),
          _DhyanaReminderCard(),
          SizedBox(height: 12),
          _DeskBreaksReminderCard(),
          SizedBox(height: 12),
          _KneeReminderCard(),
          SizedBox(height: 12),
          _WeightReminderCard(),
          SizedBox(height: 12),
          _QuietHoursCard(),
          SizedBox(height: 24),
          _SectionHeader('Background reliability'),
          SizedBox(height: 8),
          _BatteryOptimizationCard(),
          SizedBox(height: 24),
          _SectionHeader('Phone usage'),
          SizedBox(height: 8),
          _PhoneUsageSettingsCard(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    );
  }
}

class _HydrationGoalCard extends ConsumerStatefulWidget {
  const _HydrationGoalCard();

  @override
  ConsumerState<_HydrationGoalCard> createState() => _HydrationGoalCardState();
}

class _HydrationGoalCardState extends ConsumerState<_HydrationGoalCard> {
  int? _goalMl;

  @override
  Widget build(BuildContext context) {
    final hydrationConfigAsync = ref.watch(hydrationConfigProvider);
    return hydrationConfigAsync.when(
      loading: () => const _LoadingCard(),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Could not load hydration goal: $e'),
        ),
      ),
      data: (config) {
        // Track the persisted value until the user drags the slider —
        // once they do, _goalMl (local, unsaved-until-onChangeEnd) takes
        // over so the slider doesn't jump around mid-drag.
        final goal = _goalMl ?? config.dailyGoalMl;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily water goal', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Drives the progress ring on Water, the Dashboard card, and the '
                  'weekly consistency chart.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text('$goal ml'),
                Slider(
                  value: goal.toDouble(),
                  min: 1000,
                  max: 4000,
                  divisions: 30,
                  label: '$goal ml',
                  onChanged: (v) => setState(() => _goalMl = v.round()),
                  onChangeEnd: (v) async {
                    final profile = await ref.read(userProfileProvider.future);
                    await ref
                        .read(routineConfigRepositoryProvider)
                        .setHydrationConfig(
                          profile.routineConfigId,
                          HydrationConfig(
                            dailyGoalMl: v.round(),
                            quickLogAmountsMl: config.quickLogAmountsMl,
                          ),
                        );
                    ref.read(hydrationConfigRefreshProvider.notifier).state++;
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _formatMinutes(int minutesSinceMidnight) {
  final time = TimeOfDay(hour: minutesSinceMidnight ~/ 60, minute: minutesSinceMidnight % 60);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

Future<int?> _pickTime(BuildContext context, int currentMinutes) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60),
  );
  return picked == null ? null : picked.hour * 60 + picked.minute;
}

/// Base card chrome shared by every reminder card: title, description,
/// enable switch.
class _ReminderCardShell extends StatelessWidget {
  final String title;
  final String description;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final List<Widget> children;

  const _ReminderCardShell({
    required this.title,
    required this.description,
    required this.enabled,
    required this.onEnabledChanged,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                Switch(value: enabled, onChanged: onEnabledChanged),
              ],
            ),
            const SizedBox(height: 4),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            if (enabled && children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
          ],
        ),
      ),
    );
  }
}

class _WaterReminderCard extends StatefulWidget {
  const _WaterReminderCard();

  @override
  State<_WaterReminderCard> createState() => _WaterReminderCardState();
}

class _WaterReminderCardState extends State<_WaterReminderCard> {
  bool _enabled = true;
  int _intervalMinutes = ReminderPrefs.defaultWaterIntervalMinutes;
  int _fromMinutes = ReminderPrefs.defaultWaterFromMinutes;
  int _toMinutes = ReminderPrefs.defaultWaterToMinutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ReminderPrefs.waterEnabled();
    final interval = await ReminderPrefs.waterIntervalMinutes();
    final from = await ReminderPrefs.waterFromMinutes();
    final to = await ReminderPrefs.waterToMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _intervalMinutes = interval;
      _fromMinutes = from;
      _toMinutes = to;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return _ReminderCardShell(
      title: 'Water',
      description: 'Hydration reminders through the day, on a repeating interval.',
      enabled: _enabled,
      onEnabledChanged: (v) async {
        setState(() => _enabled = v);
        await ReminderPrefs.setWaterEnabled(v);
        await ReminderScheduler.instance.rescheduleAll();
      },
      children: [
        Text('Every $_intervalMinutes minutes'),
        Slider(
          value: _intervalMinutes.toDouble(),
          min: 30,
          max: 240,
          divisions: 14,
          label: '$_intervalMinutes min',
          onChanged: (v) => setState(() => _intervalMinutes = v.round()),
          onChangeEnd: (v) async {
            await ReminderPrefs.setWaterIntervalMinutes(v.round());
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
        _TimeRangeRow(
          fromLabel: 'From ${_formatMinutes(_fromMinutes)}',
          toLabel: 'To ${_formatMinutes(_toMinutes)}',
          onTapFrom: () async {
            final picked = await _pickTime(context, _fromMinutes);
            if (picked == null) return;
            setState(() => _fromMinutes = picked);
            await ReminderPrefs.setWaterFromMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
          onTapTo: () async {
            final picked = await _pickTime(context, _toMinutes);
            if (picked == null) return;
            setState(() => _toMinutes = picked);
            await ReminderPrefs.setWaterToMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
      ],
    );
  }
}

class _DhyanaReminderCard extends StatefulWidget {
  const _DhyanaReminderCard();

  @override
  State<_DhyanaReminderCard> createState() => _DhyanaReminderCardState();
}

class _DhyanaReminderCardState extends State<_DhyanaReminderCard> {
  bool _enabled = true;
  int _timeMinutes = ReminderPrefs.defaultDhyanaTimeMinutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ReminderPrefs.dhyanaEnabled();
    final time = await ReminderPrefs.dhyanaTimeMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _timeMinutes = time;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return _ReminderCardShell(
      title: 'Dhyana',
      description: 'A daily reminder to sit for your meditation practice.',
      enabled: _enabled,
      onEnabledChanged: (v) async {
        setState(() => _enabled = v);
        await ReminderPrefs.setDhyanaEnabled(v);
        await ReminderScheduler.instance.rescheduleAll();
      },
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Time: ${_formatMinutes(_timeMinutes)}'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final picked = await _pickTime(context, _timeMinutes);
            if (picked == null) return;
            setState(() => _timeMinutes = picked);
            await ReminderPrefs.setDhyanaTimeMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
      ],
    );
  }
}

class _KneeReminderCard extends StatefulWidget {
  const _KneeReminderCard();

  @override
  State<_KneeReminderCard> createState() => _KneeReminderCardState();
}

class _KneeReminderCardState extends State<_KneeReminderCard> {
  bool _enabled = true;
  int _timeMinutes = ReminderPrefs.defaultKneeTimeMinutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ReminderPrefs.kneeEnabled();
    final time = await ReminderPrefs.kneeTimeMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _timeMinutes = time;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return _ReminderCardShell(
      title: 'Knee check-in',
      description: 'A daily nudge to log pain, swelling, and stiffness.',
      enabled: _enabled,
      onEnabledChanged: (v) async {
        setState(() => _enabled = v);
        await ReminderPrefs.setKneeEnabled(v);
        await ReminderScheduler.instance.rescheduleAll();
      },
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Time: ${_formatMinutes(_timeMinutes)}'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final picked = await _pickTime(context, _timeMinutes);
            if (picked == null) return;
            setState(() => _timeMinutes = picked);
            await ReminderPrefs.setKneeTimeMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
      ],
    );
  }
}

class _WeightReminderCard extends StatefulWidget {
  const _WeightReminderCard();

  @override
  State<_WeightReminderCard> createState() => _WeightReminderCardState();
}

class _WeightReminderCardState extends State<_WeightReminderCard> {
  bool _enabled = true;
  int _timeMinutes = ReminderPrefs.defaultWeightTimeMinutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ReminderPrefs.weightEnabled();
    final time = await ReminderPrefs.weightTimeMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _timeMinutes = time;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return _ReminderCardShell(
      title: 'Weigh-in',
      description: 'A daily reminder to log your weight.',
      enabled: _enabled,
      onEnabledChanged: (v) async {
        setState(() => _enabled = v);
        await ReminderPrefs.setWeightEnabled(v);
        await ReminderScheduler.instance.rescheduleAll();
      },
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Time: ${_formatMinutes(_timeMinutes)}'),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            final picked = await _pickTime(context, _timeMinutes);
            if (picked == null) return;
            setState(() => _timeMinutes = picked);
            await ReminderPrefs.setWeightTimeMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
      ],
    );
  }
}

class _QuietHoursCard extends StatefulWidget {
  const _QuietHoursCard();

  @override
  State<_QuietHoursCard> createState() => _QuietHoursCardState();
}

class _QuietHoursCardState extends State<_QuietHoursCard> {
  bool _enabled = true;
  int _startMinutes = ReminderPrefs.defaultQuietHoursStartMinutes;
  int _endMinutes = ReminderPrefs.defaultQuietHoursEndMinutes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ReminderPrefs.quietHoursEnabled();
    final start = await ReminderPrefs.quietHoursStartMinutes();
    final end = await ReminderPrefs.quietHoursEndMinutes();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _startMinutes = start;
      _endMinutes = end;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return _ReminderCardShell(
      title: 'Quiet hours',
      description:
          'No reminders — water, desk breaks, dhyana, knee/weigh-in check-ins — '
          'fire during this window. Applies every day.',
      enabled: _enabled,
      onEnabledChanged: (v) async {
        setState(() => _enabled = v);
        await ReminderPrefs.setQuietHoursEnabled(v);
        await ReminderScheduler.instance.rescheduleAll();
      },
      children: [
        _TimeRangeRow(
          fromLabel: 'From ${_formatMinutes(_startMinutes)}',
          toLabel: 'To ${_formatMinutes(_endMinutes)}',
          onTapFrom: () async {
            final picked = await _pickTime(context, _startMinutes);
            if (picked == null) return;
            setState(() => _startMinutes = picked);
            await ReminderPrefs.setQuietHoursStartMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
          onTapTo: () async {
            final picked = await _pickTime(context, _endMinutes);
            if (picked == null) return;
            setState(() => _endMinutes = picked);
            await ReminderPrefs.setQuietHoursEndMinutes(picked);
            await ReminderScheduler.instance.rescheduleAll();
          },
        ),
      ],
    );
  }
}

class _DeskBreaksReminderCard extends StatefulWidget {
  const _DeskBreaksReminderCard();

  @override
  State<_DeskBreaksReminderCard> createState() => _DeskBreaksReminderCardState();
}

class _DeskBreaksReminderCardState extends State<_DeskBreaksReminderCard> {
  int _fromMinutes = ReminderPrefs.defaultDeskFromMinutes;
  int _toMinutes = ReminderPrefs.defaultDeskToMinutes;
  final Map<DeskBreakType, bool> _enabled = {};
  final Map<DeskBreakType, int> _intervals = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = await ReminderPrefs.deskFromMinutes();
    final to = await ReminderPrefs.deskToMinutes();
    for (final type in DeskBreakType.values) {
      _enabled[type] = await ReminderPrefs.deskBreakEnabled(type);
      _intervals[type] = await ReminderPrefs.deskBreakIntervalMinutes(type);
    }
    if (!mounted) return;
    setState(() {
      _fromMinutes = from;
      _toMinutes = to;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Desk breaks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Eye, movement, knee mobility, and neck-exercise reminders during '
              'your active hours.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _TimeRangeRow(
              fromLabel: 'Active from ${_formatMinutes(_fromMinutes)}',
              toLabel: 'to ${_formatMinutes(_toMinutes)}',
              onTapFrom: () async {
                final picked = await _pickTime(context, _fromMinutes);
                if (picked == null) return;
                setState(() => _fromMinutes = picked);
                await ReminderPrefs.setDeskFromMinutes(picked);
                await ReminderScheduler.instance.rescheduleAll();
              },
              onTapTo: () async {
                final picked = await _pickTime(context, _toMinutes);
                if (picked == null) return;
                setState(() => _toMinutes = picked);
                await ReminderPrefs.setDeskToMinutes(picked);
                await ReminderScheduler.instance.rescheduleAll();
              },
            ),
            const Divider(height: 24),
            for (final type in DeskBreakType.values) _deskBreakRow(type),
          ],
        ),
      ),
    );
  }

  Widget _deskBreakRow(DeskBreakType type) {
    final enabled = _enabled[type] ?? true;
    final interval = _intervals[type] ?? type.defaultIntervalMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(type.label)),
              Switch(
                value: enabled,
                onChanged: (v) async {
                  setState(() => _enabled[type] = v);
                  await ReminderPrefs.setDeskBreakEnabled(type, v);
                  await ReminderScheduler.instance.rescheduleAll();
                },
              ),
            ],
          ),
          if (enabled) ...[
            Text('Every $interval minutes', style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: interval.toDouble(),
              min: 15,
              max: 180,
              divisions: 11,
              label: '$interval min',
              onChanged: (v) => setState(() => _intervals[type] = v.round()),
              onChangeEnd: (v) async {
                await ReminderPrefs.setDeskBreakIntervalMinutes(type, v.round());
                await ReminderScheduler.instance.rescheduleAll();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeRangeRow extends StatelessWidget {
  final String fromLabel;
  final String toLabel;
  final VoidCallback onTapFrom;
  final VoidCallback onTapTo;

  const _TimeRangeRow({
    required this.fromLabel,
    required this.toLabel,
    required this.onTapFrom,
    required this.onTapTo,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton(onPressed: onTapFrom, child: Text(fromLabel)),
        OutlinedButton(onPressed: onTapTo, child: Text(toLabel)),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _BatteryOptimizationCard extends StatefulWidget {
  const _BatteryOptimizationCard();

  @override
  State<_BatteryOptimizationCard> createState() => _BatteryOptimizationCardState();
}

class _BatteryOptimizationCardState extends State<_BatteryOptimizationCard>
    with WidgetsBindingObserver {
  bool _exempted = false;
  bool _canScheduleExact = true;
  bool _loaded = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when returning from the system dialog/Settings screen.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final exempted = await BatteryOptimizationService.isExempted();
    final canScheduleExact = await NotificationService.instance.canScheduleExactAlarms();
    if (!mounted) return;
    final becameExact = canScheduleExact && !_canScheduleExact;
    setState(() {
      _exempted = exempted;
      _canScheduleExact = canScheduleExact;
      _loaded = true;
    });
    // Alarms scheduled while exact wasn't available used the inexact
    // fallback (see NotificationService.scheduleDaily) — relay them now
    // that exact scheduling just became available.
    if (becameExact) {
      await ReminderScheduler.instance.rescheduleAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const _LoadingCard();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Battery optimization', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Some phones (Motorola included) aggressively kill background '
              'apps and silently drop scheduled reminder notifications — even '
              'when the reminder itself is set up correctly. Exempting Nirvana '
              'from battery optimization stops that.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!_supported)
              const Text('Not applicable on this platform.')
            else if (_exempted)
              Row(
                children: [
                  Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Exempted — reminders can run unrestricted.'),
                ],
              )
            else ...[
              FilledButton.tonal(
                onPressed: () async {
                  await BatteryOptimizationService.requestExemption();
                  await _load();
                },
                child: const Text('Exempt from battery optimization'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => BatteryOptimizationService.openSystemAppSettings(),
                child: const Text('Open app settings'),
              ),
            ],
            if (_supported) ...[
              const Divider(height: 32),
              Text('Exact alarms', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Without this, Android may batch reminders into a window up to an '
                'hour late instead of firing them on time.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              if (_canScheduleExact)
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text('Allowed — reminders fire on time.'),
                  ],
                )
              else
                FilledButton.tonal(
                  onPressed: () async {
                    await NotificationService.instance.requestExactAlarmsPermission();
                    await _load();
                  },
                  child: const Text('Allow exact alarms'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PhoneUsageSettingsCard extends StatefulWidget {
  const _PhoneUsageSettingsCard();

  @override
  State<_PhoneUsageSettingsCard> createState() => _PhoneUsageSettingsCardState();
}

class _PhoneUsageSettingsCardState extends State<_PhoneUsageSettingsCard>
    with WidgetsBindingObserver {
  bool _enabled = true;
  int _thresholdMinutes = PhoneUsagePrefs.defaultThresholdMinutes;
  int _snoozeMinutes = PhoneUsagePrefs.defaultSnoozeMinutes;
  bool _hasPermission = false;
  bool _loaded = false;

  bool get _supported => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permission when returning from the system Settings screen.
    if (state == AppLifecycleState.resumed && _supported) {
      _refreshPermission();
    }
  }

  Future<void> _load() async {
    final enabled = await PhoneUsagePrefs.isEnabled();
    final threshold = await PhoneUsagePrefs.thresholdMinutes();
    final snooze = await PhoneUsagePrefs.snoozeMinutes();
    final hasPermission = _supported ? await PhoneUsageService.hasPermission() : false;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _thresholdMinutes = threshold;
      _snoozeMinutes = snooze;
      _hasPermission = hasPermission;
      _loaded = true;
    });
  }

  Future<void> _refreshPermission() async {
    final hasPermission = await PhoneUsageService.hasPermission();
    if (!mounted) return;
    setState(() => _hasPermission = hasPermission);
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => _enabled = value);
    await PhoneUsagePrefs.setEnabled(value);
    if (value) {
      await PhoneUsageService.registerBackgroundCheck();
    } else {
      await PhoneUsageService.cancelBackgroundCheck();
    }
  }

  Future<void> _setThreshold(int minutes) async {
    setState(() => _thresholdMinutes = minutes);
    await PhoneUsagePrefs.setThresholdMinutes(minutes);
  }

  Future<void> _setSnooze(int minutes) async {
    setState(() => _snoozeMinutes = minutes);
    await PhoneUsagePrefs.setSnoozeMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const _LoadingCard();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone usage warning', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Warns when the screen has been continuously on for too long, '
              'with a snooze option. No shaming — just a nudge.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!_supported)
              const Text(
                'Not available on this platform — it needs an Android-only '
                'system permission with no iOS equivalent.',
              )
            else ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enabled'),
                value: _enabled,
                onChanged: _setEnabled,
              ),
              if (_enabled && !_hasPermission)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FilledButton.tonal(
                    onPressed: () async {
                      await PhoneUsageService.requestPermission();
                    },
                    child: const Text('Grant "Usage access" permission'),
                  ),
                ),
              Text('Warn after: $_thresholdMinutes minutes'),
              Slider(
                value: _thresholdMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                label: '$_thresholdMinutes min',
                onChanged: _enabled ? (v) => _setThreshold(v.round()) : null,
              ),
              Text('Snooze for: $_snoozeMinutes minutes'),
              Slider(
                value: _snoozeMinutes.toDouble(),
                min: 5,
                max: 60,
                divisions: 11,
                label: '$_snoozeMinutes min',
                onChanged: _enabled ? (v) => _setSnooze(v.round()) : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
