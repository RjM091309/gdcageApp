import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../generated/app_localizations.dart';
import '../main.dart';
import '../models/dashboard_summary.dart';
import '../models/monthly_statistics.dart';
import '../services/dashboard_summary_service.dart';
import '../services/monthly_statistics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_box.dart';
import '../widgets/stat_card.dart';

final _fmt =
    NumberFormat.currency(locale: 'en_PH', symbol: '₱', decimalDigits: 0);

const _monthNamesEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthLabel(String monthKey, Locale? locale) {
  final parts = monthKey.split('-');
  if (parts.length < 2) return monthKey;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return monthKey;
  if (locale?.languageCode == 'en') return _monthNamesEn[m - 1];
  return '$m월';
}

class RealTimeView extends StatefulWidget {
  const RealTimeView({super.key, this.onPollTick});

  /// Called every 3s so other polled data (e.g. notifications) stays in sync while this tab is active.
  final VoidCallback? onPollTick;

  @override
  State<RealTimeView> createState() => _RealTimeViewState();
}

class _RealTimeViewState extends State<RealTimeView> {
  Timer? _pollTimer;
  Timer? _summaryTimer;
  DashboardSummary? _summary;
  bool _loadingSummary = true;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      widget.onPollTick?.call();
    });
    _loadSummary();
    _summaryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadSummary();
    });
  }

  Future<void> _loadSummary() async {
    final summary = await DashboardSummaryService.instance.fetchSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loadingSummary = false;
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _summaryTimer?.cancel();
    super.dispose();
  }

  void _showStatisticsDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _StatisticsDialog(),
    );
  }

  Widget _buildHighlightCard() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emeraldAccent.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            emeraldAccent.withValues(alpha: 0.22),
            emeraldAccent.withValues(alpha: 0.05)
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: emeraldAccent.withValues(alpha: 0.25),
                    shape: BoxShape.circle),
                child: Icon(Icons.trending_up, size: 18, color: emeraldAccent),
              ),
              const Spacer(),
              Material(
                color: surfaceDarkStart.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _showStatisticsDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    child: Text(l10n.statisticsLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              // Wider (tablet) card: push the pair further apart. Narrow (mobile): keep it tight so text doesn't overflow.
              final dividerMargin =
                  ((constraints.maxWidth - 260) * 0.3).clamp(20.0, 90.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(l10n.winLossLabel,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _amountText(_summary?.winLoss,
                          fontSize: 24, color: Colors.white),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    margin: EdgeInsets.symmetric(horizontal: dividerMargin),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(l10n.ngrLabel,
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _amountText(_summary?.ngr,
                          fontSize: 24, color: Colors.white),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _amountText(int? value,
      {required double fontSize, required Color color}) {
    if (_loadingSummary || value == null) {
      return SkeletonBox(width: fontSize * 4, height: fontSize * 1.1);
    }
    return Text(_fmt.format(value),
        style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.bold, color: color));
  }

  Widget _wideStatCard(
      {required IconData icon,
      required Color color,
      required String label,
      String? subLabel,
      required int? value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w600)),
              if (subLabel != null)
                Text(subLabel,
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              _amountText(value, fontSize: 19, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHighlightCard(),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.95,
              children: [
                StatCard(
                  label: l10n.totalCommissionLabel,
                  value: '',
                  valueWidget: _amountText(_summary?.totalCommission,
                      fontSize: 24, color: Colors.white),
                  icon: Icons.account_balance_wallet,
                  color: StatCardColor.amber,
                  centered: true,
                ),
                StatCard(
                  label: l10n.gameCommissionLabel,
                  value: '',
                  valueWidget: _amountText(_summary?.gameCommission,
                      fontSize: 24, color: Colors.white),
                  icon: Icons.casino,
                  color: StatCardColor.teal,
                  centered: true,
                ),
                StatCard(
                  label: l10n.additionalCommissionLabel,
                  value: '',
                  valueWidget: _amountText(_summary?.additionalCommission,
                      fontSize: 24, color: Colors.white),
                  icon: Icons.layers,
                  color: StatCardColor.purple,
                  centered: true,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _wideStatCard(
            icon: Icons.shield,
            color: roseAccent,
            label: l10n.accumulatedExpenses,
            subLabel: l10n.mtdExpenditure,
            value: _summary?.expenses),
        const SizedBox(height: 14),
        _wideStatCard(
            icon: Icons.videogame_asset,
            color: primaryIndigo,
            label: l10n.cageRollingLabel,
            value: _summary?.cageRolling),
        const SizedBox(height: 14),
        _wideStatCard(
            icon: Icons.casino,
            color: primaryIndigo,
            label: l10n.casinoRollingLabel,
            value: _summary?.casinoRolling),
      ],
    );
  }
}

class _StatisticsDialog extends StatefulWidget {
  const _StatisticsDialog();

  @override
  State<_StatisticsDialog> createState() => _StatisticsDialogState();
}

class _StatisticsDialogState extends State<_StatisticsDialog> {
  MonthlyStatistics? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await MonthlyStatisticsService.instance.fetchStatistics();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  static const _monthColumnWidth = 34.0;

  Widget _headerCell(String text) => Expanded(
        child: Text(text,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400])),
      );

  Widget _monthCell(String month) => SizedBox(
        width: _monthColumnWidth,
        child: Text(month,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      );

  Widget _valueCell(int value, Color color) {
    String text;
    if (value == 0) {
      text = '0';
    } else if (value.abs() < 1000) {
      // Small non-zero amounts (e.g. ₱450) would round to "0K" and look identical to an
      // actually-zero month — show the exact figure instead of abbreviating.
      text = NumberFormat.decimalPattern().format(value);
    } else {
      text = '${NumberFormat.decimalPattern().format((value / 1000).round())}K';
    }
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.end,
        style:
            TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = AppLocaleScope.of(context).locale;
    final year = locale?.languageCode == 'en'
        ? '${DateTime.now().year}'
        : '${DateTime.now().year}년';
    final months = _stats?.months ?? const [];
    return Dialog(
      backgroundColor: surfaceDarkMid,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(year,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 18),
            Row(
              children: [
                const SizedBox(width: _monthColumnWidth),
                _headerCell(l10n.winLossLabel),
                _headerCell(l10n.shareLabel),
                _headerCell(l10n.commissionLabel),
                _headerCell(l10n.expensesLabel),
                _headerCell(l10n.ngrLabel),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (months.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(l10n.noDataYet,
                      style: TextStyle(color: Colors.grey[500])),
                ),
              )
            else
              for (final s in months) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    _monthCell(_monthLabel(s.monthKey, locale)),
                    _valueCell(s.winLoss, amberAccent),
                    _valueCell(s.share, roseAccent),
                    _valueCell(s.commission, roseAccent),
                    _valueCell(s.expenses, amberAccent),
                    _valueCell(s.ngr, Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: Colors.white12),
              ],
            const SizedBox(height: 4),
            Center(
              child: Icon(Icons.keyboard_double_arrow_down,
                  color: primaryIndigo, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
