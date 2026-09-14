import 'package:flutter/material.dart';

import '../models/league.dart';
import '../services/gamification_controller.dart';
import '../services/league_service.dart';
import '../theme/app_colors.dart';

/// Weekly league leaderboard (plan §4.6). Ranked by Cal Points earned Mon–Sun.
class LeagueScreen extends StatefulWidget {
  const LeagueScreen({super.key});

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
    final now = DateTime.now();
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
          Text(tier.emoji, style: TextStyle(fontSize: 32)),
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
              _pill('Top ${tier.promote}', 'promote', AppColors.green),
              _pill('${state.weeklyPoints}', 'your points', AppColors.ink),
              _pill(
                'Bottom ${tier.demote}',
                'demote',
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
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }

  Widget _lastWeekBanner(LeagueState state) {
    final result = state.lastResult ?? 'stay';
    final color = result == 'promote'
        ? AppColors.green
        : (result == 'demote' ? AppColors.missedRed : AppColors.muted);
    final text = result == 'promote'
        ? 'You were promoted to ${LeagueService.tierFor(state.tier).name}! 🎉'
        : (result == 'demote'
              ? "You'll bounce back — a fresh week starts now 💪"
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
          fontSize: 13,
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
                fontSize: 13,
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
