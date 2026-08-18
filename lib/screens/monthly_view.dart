import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../generated/app_localizations.dart';
import '../models/monthly_games.dart';
import '../services/monthly_games_service.dart';
import '../theme/app_theme.dart';

String _peso(int value) {
  final abs = value.abs();
  final body = abs < 1000
      ? NumberFormat.decimalPattern().format(abs)
      : '${NumberFormat.decimalPattern().format((abs / 1000).round())}K';
  if (value < 0) return '-₱$body';
  return '₱$body';
}

String _rankOf(int index) => index.toString().padLeft(2, '0');

(String name, String? code) _splitAccount(String account) {
  final m = RegExp(r'^(.*)\s*\(([^)]+)\)\s*$').firstMatch(account.trim());
  if (m == null) return (account, null);
  return (m.group(1)!.trim(), m.group(2)!.trim());
}

class MonthlyView extends StatefulWidget {
  const MonthlyView({super.key});

  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  bool _todaySelected = true;
  MonthlyGames? _games;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final games = await MonthlyGamesService.instance.fetchMonthlyGames();
    if (!mounted) return;
    setState(() {
      _games = games;
      _loading = false;
    });
  }

  Widget _segmentTrack({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: children),
      ),
    );
  }

  Widget _segment(
    String label, {
    required bool selected,
    VoidCallback? onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(isFirst ? 14 : 4),
            right: Radius.circular(isLast ? 14 : 4),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? primaryIndigo.withValues(alpha: 0.4) : Colors.transparent,
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(isFirst ? 14 : 4),
                right: Radius.circular(isLast ? 14 : 4),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: primaryIndigo.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.75),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rankBadge(String rank) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primaryIndigo.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryIndigo.withValues(alpha: 0.28)),
      ),
      child: Text(
        rank,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accentPurple,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 7,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.38),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsRow({
    required String buyIn,
    required String cashOut,
    required String commission,
    required String winLoss,
    required Color winLossColor,
  }) {
    final l10n = AppLocalizations.of(context);
    Widget sep() => Container(
          width: 1,
          height: 22,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: Colors.white.withValues(alpha: 0.06),
        );
    return Row(
      children: [
        _metric(l10n.buyIn, buyIn, Colors.white.withValues(alpha: 0.92)),
        sep(),
        _metric(l10n.cashOut, cashOut, Colors.white.withValues(alpha: 0.92)),
        sep(),
        _metric(l10n.commissionLabel, commission, Colors.white.withValues(alpha: 0.92)),
        sep(),
        _metric(l10n.winLossLabel, winLoss, winLossColor),
      ],
    );
  }

  Widget _gameCard({
    required String rank,
    required String title,
    String? code,
    required OngoingGameRow? row,
    SettledGameTotals? totals,
  }) {
    final buyIn = row?.buyIn ?? totals!.buyIn;
    final cashOut = row?.cashOut ?? totals!.cashOut;
    final commission = row?.commission ?? totals!.commission;
    final winLoss = row?.winLoss ?? totals!.winLoss;
    final winLossColor = winLoss == 0
        ? Colors.white.withValues(alpha: 0.92)
        : (winLoss < 0 ? roseAccent : emeraldAccent);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      constraints: const BoxConstraints(maxHeight: 118),
      decoration: BoxDecoration(
        color: const Color(0xFF12121F).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _rankBadge(rank),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (code != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryIndigo.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      code,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: accentPurple,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 8),
            _metricsRow(
              buyIn: _peso(buyIn),
              cashOut: _peso(cashOut),
              commission: _peso(commission),
              winLoss: _peso(winLoss),
              winLossColor: winLossColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _scrollList({required List<Widget> children}) {
    const visibleCards = 3;
    const cardSlot = 126.0;
    const listPad = 16.0;
    if (children.length <= visibleCards) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Column(children: children),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: cardSlot * visibleCards + listPad),
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = _games ?? const MonthlyGames.empty();
    final ongoing = games.ongoing;
    final settled = _todaySelected ? games.settledToday : games.settledPrevious;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _segmentTrack(children: [
                _segment(l10n.ongoingGames, selected: true, isFirst: true, isLast: true),
              ]),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (ongoing.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(l10n.noOngoingGames,
                        style: TextStyle(color: Colors.grey[500])),
                  ),
                )
              else
                _scrollList(
                  children: [
                    for (var i = 0; i < ongoing.length; i++)
                      _gameCard(
                        rank: _rankOf(i),
                        title: _splitAccount(ongoing[i].account).$1,
                        code: _splitAccount(ongoing[i].account).$2,
                        row: ongoing[i],
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.settledGameLabel.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              _segmentTrack(children: [
                _segment(
                  l10n.todayLabel,
                  selected: _todaySelected,
                  isFirst: true,
                  onTap: () => setState(() => _todaySelected = true),
                ),
                _segment(
                  l10n.yesterdayLabel,
                  selected: !_todaySelected,
                  isLast: true,
                  onTap: () => setState(() => _todaySelected = false),
                ),
              ]),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                _scrollList(
                  children: [
                    _gameCard(
                      rank: _rankOf(settled.gameCount),
                      title: '${settled.gameCount} ${l10n.settledGameLabel}',
                      row: null,
                      totals: settled,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
            ),
          ),
        );
      },
    );
  }
}
