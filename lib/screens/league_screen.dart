import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../models/league.dart';
import '../services/gamification_controller.dart';
import '../services/league_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Weekly league leaderboard (plan §4.6). Ranked by Cal Points earned Mon–Sun.
class LeagueScreen extends StatefulWidget {
  /// [now] is only for tests — the countdown is otherwise clock-dependent and
  /// would make the golden flaky.
  final DateTime? now;
  const LeagueScreen({super.key, this.now});

  @override
  State<LeagueScreen> createState() => _LeagueScreenState();
}

class _LeagueScreenState extends State<LeagueScreen> {
  GamificationController? get _gami => GamificationController.instance;

  LeagueService? _service;
  LeagueState? _state;
  List<LeagueRow> _rows = [];

  void _onChanged() {
    if (mounted) _reload();
  }

  @override
  void initState() {
    super.initState();
    final gami = _gami;
    if (gami != null) _service = LeagueService(gami.storage, gami);
    gami?.revision.addListener(_onChanged);
    _reload();
  }

  @override
  void dispose() {
    _gami?.revision.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    final service = _service;
    if (service == null) return;
    final s = await service.sync();
    if (!mounted) return;
    setState(() {
      _state = s;
      _rows = service.leaderboard();
    });
  }

  String _countdown() {
    final now = widget.now ?? DateTime.now();
    final end = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 7));
    final left = end.difference(now);
    final days = left.inDays;
    final hours = left.inHours % 24;
    return days > 0 ? '${days}d ${hours}h left' : '${hours}h left';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final tier = state == null
        ? LeagueService.tiers.first
        : LeagueService.tierFor(state.tier);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(
          'League',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ),
      body: state == null
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                _tierCard(tier, state),
                SizedBox(height: 16),
                if (state.lastPosition != null && state.weeksPlayed > 0)
                  _lastWeekBanner(state),
                SizedBox(height: 12),
                ..._rows.map((r) => _row(r, tier)),
              ],
            ),
    );
  }

  Widget _tierCard(LeagueTier tier, LeagueState state) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Icon(Symbols.eco_rounded,
              size: 34, color: AppColors.green),
          SizedBox(height: 6),
          Text(
            '${tier.name} League',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Tier ${tier.index} of ${LeagueService.tiers.length} · ${_countdown()}',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // label first, then the value — 'Top 20' is a threshold, not a
              // score, so it must not read like the points number next to it.
              _pill('Top ${tier.promote}', 'Promote', AppColors.green),
              _pill('${state.weeklyPoints}', 'Your points', AppColors.ink),
              _pill(
                'Bottom ${tier.demote}',
                'Demote',
                tier.demote == 0 ? AppColors.faint : AppColors.missedRed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppType.micro,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: AppType.bodyStrong,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _lastWeekBanner(LeagueState state) {
    final result = state.lastResult ?? 'stay';
    final color = result == 'promote'
        ? AppColors.green
        : (result == 'demote' ? AppColors.missedRed : AppColors.muted);
    final text = result == 'promote'
        ? 'You were promoted to ${LeagueService.tierFor(state.tier).name}!'
        : (result == 'demote'
              ? "You'll bounce back — a fresh week starts now."
              : 'Last week you finished #${state.lastPosition}.');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppType.body,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _row(LeagueRow r, LeagueTier tier) {
    final isPromote = r.position <= tier.promote;
    final isDemote =
        tier.demote > 0 && r.position > LeagueService.members - tier.demote;
    final zoneColor = isPromote
        ? AppColors.green
        : (isDemote ? AppColors.missedRed : null);
    return Semantics(
      label:
          'Position ${r.position}, ${r.name}${r.isYou ? ', you' : ''}, '
          '${r.points} points',
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: r.isYou ? AppColors.cardSelected : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: r.isYou ? Border.all(color: AppColors.ink, width: 1.5) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${r.position}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: zoneColor ?? AppColors.muted,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                r.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: r.isYou ? FontWeight.w800 : FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
            Text(
              '${r.points} pts',
              style: TextStyle(
                fontSize: AppType.body,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
