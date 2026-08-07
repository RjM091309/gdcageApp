import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../generated/app_localizations.dart';
import '../models/monthly_games.dart';
import '../services/monthly_games_service.dart';
import '../theme/app_theme.dart';

String _kFmt(int value) {
  if (value == 0) return '0';
  // Small non-zero amounts (e.g. ₱450) would round to "0K" and look identical to an actually
  // zero value — show the exact figure instead of abbreviating.
  if (value.abs() < 1000) return NumberFormat.decimalPattern().format(value);
  return '${NumberFormat.decimalPattern().format((value / 1000).round())}K';
}

String _rankOf(int index) => index.toString().padLeft(2, '0');

class MonthlyView extends StatefulWidget {
  const MonthlyView({super.key});

  @override
  State<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends State<MonthlyView> {
  bool _todaySelected = true;
  MonthlyGames? _games;
  bool _loading = true;

  // Uniform text scale: matches the row/section font sizes used on the Weekly (statement) tab.
  static const _rowFontMobile = 16.0;
  static const _rowFontTablet = 19.0;
  static const _headerFontMobile = 14.0;
  static const _headerFontTablet = 16.0;

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

  Widget _sectionTitleBar(String text, bool isTablet, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: primaryIndigo.withValues(alpha: 0.28),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text,
              style: TextStyle(
                  fontSize: isTablet ? _headerFontTablet : _headerFontMobile,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _toggleButton(
      String label, bool selected, bool isTablet, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? primaryIndigo : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected
                    ? primaryIndigo
                    : Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: isTablet ? _headerFontTablet : _headerFontMobile,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey[400])),
        ),
      ),
    );
  }

  Widget _tableHeader(bool isTablet, {bool showGuest = true}) {
    final l10n = AppLocalizations.of(context);
    final fontSize = isTablet ? _headerFontTablet : _headerFontMobile;
    final style = TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: Colors.grey[400]);
    return Container(
      color: Colors.white.withValues(alpha: 0.03),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 40),
          if (showGuest)
            Expanded(flex: 2, child: Text(l10n.guestLabel, style: style)),
          Expanded(
              child:
                  Text(l10n.buyIn, textAlign: TextAlign.end, style: style)),
          Expanded(
              child:
                  Text(l10n.cashOut, textAlign: TextAlign.end, style: style)),
          Expanded(
              child: Text(l10n.commissionLabel,
                  textAlign: TextAlign.end, style: style)),
          Expanded(
              child: Text(l10n.winLossLabel,
                  textAlign: TextAlign.end, style: style)),
        ],
      ),
    );
  }

  Widget _rankBadge(String rank) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: amberAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(rank,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: amberAccent)),
    );
  }

  Widget _ongoingRow(String rank, OngoingGameRow row, bool isTablet, bool striped) {
    final fontSize = isTablet ? _rowFontTablet : _rowFontMobile;
    return Container(
      color: striped ? Colors.white.withValues(alpha: 0.02) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _rankBadge(rank),
          const SizedBox(width: 14),
          Expanded(
              flex: 2,
              child: Text(row.account,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: tealAccent))),
          Expanded(
              child: Text(_kFmt(row.buyIn),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: roseAccent))),
          Expanded(
              child: Text(_kFmt(row.cashOut),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: roseAccent))),
          Expanded(
              child: Text(_kFmt(row.commission),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: amberAccent))),
          Expanded(
              child: Text(_kFmt(row.winLoss),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: accentPurple))),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.grey[500])),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  /// Narrow screens can't fit a 6-column table without wrapping, so show each
  /// game as a card with a 2-column stat grid instead.
  Widget _ongoingCardMobile(String rank, OngoingGameRow row) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _rankBadge(rank),
              const SizedBox(width: 10),
              Flexible(
                child: Text(row.account,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: tealAccent)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _miniStat(l10n.buyIn, _kFmt(row.buyIn), roseAccent)),
              Expanded(
                  child: _miniStat(
                      l10n.cashOut, _kFmt(row.cashOut), roseAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _miniStat(l10n.commissionLabel,
                      _kFmt(row.commission), amberAccent)),
              Expanded(
                  child: _miniStat(l10n.winLossLabel, _kFmt(row.winLoss),
                      accentPurple)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _settledRow(SettledGameTotals totals, bool isTablet) {
    final fontSize = isTablet ? _rowFontTablet : _rowFontMobile;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _rankBadge(_rankOf(totals.gameCount)),
          const SizedBox(width: 14),
          Expanded(
              child: Text(_kFmt(totals.buyIn),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: roseAccent))),
          Expanded(
              child: Text(_kFmt(totals.cashOut),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: roseAccent))),
          Expanded(
              child: Text(_kFmt(totals.commission),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: amberAccent))),
          Expanded(
              child: Text(_kFmt(totals.winLoss),
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: accentPurple))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 500;
        final games = _games ?? const MonthlyGames.empty();
        final ongoing = games.ongoing;
        final settled =
            _todaySelected ? games.settledToday : games.settledPrevious;

        return Column(
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
                  _sectionTitleBar(l10n.ongoingGames, isTablet),
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
                  else if (isTablet) ...[
                    _tableHeader(isTablet),
                    for (var i = 0; i < ongoing.length; i++)
                      _ongoingRow(_rankOf(i), ongoing[i], isTablet, i.isOdd),
                  ] else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          for (var i = 0; i < ongoing.length; i++)
                            _ongoingCardMobile(_rankOf(i), ongoing[i]),
                        ],
                      ),
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
                  _sectionTitleBar(
                    l10n.settledGameLabel,
                    isTablet,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toggleButton(l10n.todayLabel, _todaySelected,
                            isTablet, () => setState(() => _todaySelected = true)),
                        const SizedBox(width: 8),
                        _toggleButton(l10n.yesterdayLabel, !_todaySelected,
                            isTablet, () => setState(() => _todaySelected = false)),
                      ],
                    ),
                  ),
                  _tableHeader(isTablet, showGuest: false),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _settledRow(settled, isTablet),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
