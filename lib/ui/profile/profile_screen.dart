import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../design/format.dart';
import '../../design/tokens.dart';
import '../../model/profile.dart';
import '../../state/day_stats_store.dart';
import '../../state/profile_store.dart';
import '../../state/stats_store.dart';
import '../stats/stat_tile.dart';

/// Who you are at this table: level, rank, what earned it, and the badges.
///
/// Every number here is derived from the records on the other two tabs. There
/// is no separate progress file to fall out of step with them, which also
/// means a restored save arrives already carrying the right level.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profileStore = context.watch<ProfileStore>();
    final stats = context.watch<StatsStore>();
    final days = context.watch<DayStatsStore>();

    final profile = Profile.of(
      name: profileStore.displayName,
      lifetime: stats.lifetime,
      peakBankroll: profileStore.peakBankroll,
      daysPlayed: days.daysPlayed,
      dayStreak: days.streakEndingAt(DateTime.now()),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('You', style: AppText.display(34, weight: 700, height: 0.9)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'LEVEL ${profile.level}',
              style: AppText.eyebrow(9, color: AppColor.amber),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Card(profile: profile, store: profileStore),
        const SizedBox(height: 12),
        if (profile.isNew)
          const _Fresh()
        else ...[
          _NextUp(profile: profile),
          const SizedBox(height: 12),
          _Earned(profile: profile),
          const SizedBox(height: 12),
          _Badges(profile: profile),
          const SizedBox(height: 12),
          _Career(profile: profile, stats: stats),
        ],
      ],
    );
  }
}

/// An eyebrow label with a number on the right. The number shrinks to fit
/// rather than pushing the row past the edge of a narrow phone.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.label,
    required this.readout,
    this.tone = AppColor.slate,
  });

  final String label;
  final String readout;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.eyebrow(8),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              readout,
              style: AppText.mono(
                11,
                weight: tone == AppColor.slate ? FontWeight.w400 : FontWeight.w600,
                color: tone,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Name, rank and the bar. The one thing on this screen you can change.
class _Card extends StatelessWidget {
  const _Card({required this.profile, required this.store});

  final Profile profile;
  final ProfileStore store;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Monogram(name: profile.name, level: profile.level),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _rename(context),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.display(
                                26,
                                weight: 700,
                                height: 0.95,
                                color: store.hasName ? AppColor.bone : AppColor.boneMid,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(Icons.edit_outlined, size: 13, color: AppColor.slate),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.rank.name,
                      style: AppText.ui(12.5, weight: 600, color: AppColor.amber),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.rank.note,
                      style: AppText.ui(10.5, color: AppColor.slate, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HeaderRow(
            label: 'LEVEL ${profile.level}',
            readout: '${chips(profile.xpIntoLevel)} / ${chips(profile.xpNeededForLevel)} XP',
          ),
          const SizedBox(height: 7),
          Meter(value: profile.levelProgress, colour: AppColor.amber, height: 8),
          const SizedBox(height: 7),
          Text(
            profile.isNew
                ? 'Play a round and this starts moving.'
                : '${chips(profile.xpToNextLevel)} XP to level ${profile.level + 1}'
                    '  ·  ${chips(profile.xp)} XP earned in total',
            style: AppText.mono(10, color: AppColor.slate),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(initial: store.name),
    );
    if (value != null) store.setName(value);
  }
}

/// Owns its own controller so it can outlive the await in [_Card._rename] —
/// disposing one from the caller tears it down while the dialog is still
/// animating out, and the field rebuilds against a dead controller.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColor.rail,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('What should we call you?', style: AppText.ui(16, weight: 600)),
      content: TextField(
        controller: _field,
        autofocus: true,
        maxLength: ProfileStore.nameLimit,
        textCapitalization: TextCapitalization.words,
        inputFormatters: [LengthLimitingTextInputFormatter(ProfileStore.nameLimit)],
        onSubmitted: (v) => Navigator.pop(context, v),
        style: AppText.ui(15),
        decoration: InputDecoration(
          hintText: 'Player',
          hintStyle: AppText.ui(15, color: AppColor.slate),
          counterStyle: AppText.mono(9, color: AppColor.slate),
          filled: true,
          fillColor: AppColor.railHi,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColor.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColor.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColor.amber),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.ui(13, color: AppColor.boneMid)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _field.text),
          child: Text('Save', style: AppText.ui(13, weight: 600, color: AppColor.amber)),
        ),
      ],
    );
  }
}

/// A chip with your initial struck into it.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.level});

  final String name;
  final int level;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColor.railHi,
        shape: BoxShape.circle,
        border: Border.all(color: AppColor.amber, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppText.display(30, weight: 700, color: AppColor.amber, height: 1),
      ),
    );
  }
}

/// The next rank, and the badges closest to falling.
class _NextUp extends StatelessWidget {
  const _NextUp({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final next = profile.nextRank;
    final nearest = profile.nearest();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT UP', style: AppText.eyebrow(8)),
          const SizedBox(height: 8),
          if (next != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    next.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(13, weight: 600, color: AppColor.bone),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'level ${next.level}',
                  style: AppText.mono(11, color: AppColor.amber),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Meter(
              value: _rankProgress(profile, next),
              colour: AppColor.amber,
              height: 5,
            ),
            const SizedBox(height: 5),
            Text(
              '${chips(xpForLevel(next.level) - profile.xp)} XP away',
              style: AppText.mono(10, color: AppColor.slate),
            ),
          ] else
            Text(
              'Top rank. There is nothing above this one.',
              style: AppText.ui(12, color: AppColor.jade),
            ),
          if (nearest.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: AppColor.line),
            const SizedBox(height: 10),
            Text('CLOSEST BADGES', style: AppText.eyebrow(7.5)),
            const SizedBox(height: 8),
            for (final b in nearest) ...[
              _BadgeRow(badge: b),
              if (b != nearest.last) const SizedBox(height: 9),
            ],
          ],
        ],
      ),
    );
  }

  /// How far through the span between the rank you hold and the next one.
  static double _rankProgress(Profile p, Rank next) {
    final from = xpForLevel(p.rank.level);
    final to = xpForLevel(next.level);
    final span = to - from;
    return span <= 0 ? 1 : ((p.xp - from) / span).clamp(0.0, 1.0);
  }
}

/// Where the experience actually came from.
class _Earned extends StatelessWidget {
  const _Earned({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final parts = profile.breakdown.parts.where((p) => p.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = profile.xp;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            label: 'WHERE IT CAME FROM',
            readout: '${chips(total)} XP',
            tone: AppColor.amber,
          ),
          const SizedBox(height: 12),
          for (final p in parts) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(12, color: AppColor.boneMid),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  chips(p.value),
                  style: AppText.mono(12, weight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Meter(
              value: total <= 0 ? 0 : p.value / total,
              colour: AppColor.amber,
              height: 4,
            ),
            const SizedBox(height: 3),
            Text(p.note, style: AppText.mono(9, color: AppColor.slate)),
            if (p != parts.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final earned = profile.earned;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            label: 'BADGES',
            readout: '${earned.length} of ${profile.badges.length}',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in profile.badges) _BadgeChip(badge: b),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    final on = badge.earned;

    return Semantics(
      label: '${badge.name}. ${badge.note} ${badge.progressLabel}',
      child: Tooltip(
        message: '${badge.note}\n${badge.progressLabel}',
        textStyle: AppText.ui(11, color: AppColor.bone),
        decoration: BoxDecoration(
          color: AppColor.ink,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColor.line),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColor.amber.withValues(alpha: 0.12) : AppColor.railHi,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: on ? AppColor.amber : AppColor.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                size: 14,
                color: on ? AppColor.amber : AppColor.slate,
              ),
              const SizedBox(width: 6),
              Text(
                badge.name,
                style: AppText.ui(
                  11.5,
                  weight: on ? 600 : 500,
                  color: on ? AppColor.bone : AppColor.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge});

  final Achievement badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                badge.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(12, weight: 500),
              ),
            ),
            const SizedBox(width: 10),
            Text(badge.progressLabel, style: AppText.mono(10, color: AppColor.slate)),
          ],
        ),
        const SizedBox(height: 4),
        Meter(value: badge.progress, colour: AppColor.amber, height: 4),
      ],
    );
  }
}

class _Career extends StatelessWidget {
  const _Career({required this.profile, required this.stats});

  final Profile profile;
  final StatsStore stats;

  @override
  Widget build(BuildContext context) {
    final s = stats.lifetime;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CAREER', style: AppText.eyebrow(8)),
          const SizedBox(height: 6),
          StatRow('Rounds dealt', chips(s.rounds)),
          StatRow('Hands played', chips(s.hands)),
          StatRow(
            'Chart accuracy',
            s.decisions == 0 ? '—' : '${(s.accuracy * 100).toStringAsFixed(1)}%',
            tone: s.decisions == 0
                ? AppColor.slate
                : s.accuracy >= 0.95
                    ? AppColor.jade
                    : s.accuracy >= 0.85
                        ? AppColor.amber
                        : AppColor.clay,
          ),
          StatRow(
            'Net result',
            signedChips(s.net),
            tone: s.net > 0
                ? AppColor.jade
                : s.net < 0
                    ? AppColor.clay
                    : AppColor.bone,
          ),
          StatRow('Peak bankroll', chips(profile.peakBankroll), tone: AppColor.amber),
          StatRow('Tables reached', '${profile.tablesReached} of 5'),
          StatRow('Days at the table', '${profile.daysPlayed}'),
          StatRow(
            'Current streak',
            '${profile.dayStreak} day${profile.dayStreak == 1 ? '' : 's'}',
            tone: profile.dayStreak > 0 ? AppColor.amber : AppColor.slate,
          ),
        ],
      ),
    );
  }
}

class _Fresh extends StatelessWidget {
  const _Fresh();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing earned yet', style: AppText.display(26, weight: 700, height: 0.95)),
          const SizedBox(height: 8),
          Text(
            'Levels come mostly from playing the chart correctly, and only a '
            'little from winning. A lucky shoe will not carry you; turning up '
            'and playing it right will.',
            style: AppText.ui(13, color: AppColor.boneMid, height: 1.45),
          ),
          const SizedBox(height: 14),
          for (final line in const [
            'Every round dealt  ·  ${Xp.perRound} XP',
            'Every play that matches the chart  ·  ${Xp.perCorrectDecision} XP',
            'Every day you sit down  ·  ${Xp.perDayPlayed} XP',
            'Every table you reach  ·  ${Xp.perTableReached} XP',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(line, style: AppText.mono(11, color: AppColor.jade)),
            ),
        ],
      ),
    );
  }
}
