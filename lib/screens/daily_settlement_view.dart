import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../generated/app_localizations.dart';
import '../models/dashboard_statement.dart';
import '../services/dashboard_statement_service.dart';
import '../theme/app_theme.dart';

final _fmt = NumberFormat.decimalPattern('en_US');

class _StatementRow {
  final String label;
  final String value;
  final bool negative;

  const _StatementRow(this.label, this.value, {this.negative = false});
}

class _StatementSection {
  final String? title;
  final List<_StatementRow> rows;

  const _StatementSection({this.title, required this.rows});
}

/// Natural-sign display: negative values shown in parens/red, matching the web dashboard's fmtAmt().
_StatementRow _amtRow(String label, int value) {
  final isNeg = value < 0;
  final text = isNeg ? '(${_fmt.format(value.abs())})' : _fmt.format(value);
  return _StatementRow(label, text, negative: isNeg);
}

/// Liability display: always shown in parens/red unless exactly zero, matching the web
/// dashboard's fmtNeg() — Credit/Expenses/Commission etc. are amounts owed, so the sign of the
/// stored value doesn't matter, only whether there's a balance at all.
_StatementRow _negRow(String label, int value) {
  if (value == 0) return _StatementRow(label, '0');
  return _StatementRow(label, '(${_fmt.format(value.abs())})', negative: true);
}

List<_StatementSection> _buildSections(DashboardStatement s, AppLocalizations l10n) {
  return [
    _StatementSection(rows: [_amtRow(l10n.companyLabel, s.company)]),
    _StatementSection(title: l10n.liabilitiesLabel, rows: [
      _negRow(l10n.creditLabel, s.credit),
      _negRow(l10n.expensesLabel, s.expenses),
      _negRow(l10n.lossAmountLabel, s.lossAmount),
    ]),
    _StatementSection(title: l10n.settlementLabel, rows: [
      _negRow(l10n.commissionLabel, s.commission),
      _negRow(l10n.additionalLabel, s.additionalCommission),
    ]),
    _StatementSection(
      title: l10n.addChargeLabel,
      rows: [
        for (final cat in s.serviceCategories) _amtRow(cat.label, cat.balance),
      ],
    ),
    _StatementSection(
        title: l10n.etcTipLabel, rows: [_amtRow(l10n.tipBalanceLabel, s.tipBalance)]),
    _StatementSection(
        title: l10n.depositOfGuestsLabel, rows: [_amtRow(l10n.lineLabel, s.guestLine)]),
  ];
}

class DailySettlementView extends StatefulWidget {
  const DailySettlementView({super.key});

  @override
  State<DailySettlementView> createState() => _DailySettlementViewState();
}

class _DailySettlementViewState extends State<DailySettlementView> {
  DashboardStatement? _statement;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final statement = await DashboardStatementService.instance.fetchStatement();
    if (!mounted) return;
    setState(() {
      _statement = statement;
      _loading = false;
    });
  }

  Widget _row(_StatementRow row, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(row.label,
              style: TextStyle(
                  fontSize: isTablet ? 19 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[300])),
          Text(row.value,
              style: TextStyle(
                  fontSize: isTablet ? 19 : 16,
                  fontWeight: FontWeight.bold,
                  color: row.negative ? roseAccent : Colors.white)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isTablet) {
    return Container(
      width: double.infinity,
      color: primaryIndigo.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(title,
          style: TextStyle(
              fontSize: isTablet ? 15 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: accentPurple)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 500;
        final sections =
            _buildSections(_statement ?? const DashboardStatement.empty(), l10n);
        return Transform.translate(
          offset: const Offset(0, -6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: surfaceDarkStart,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(l10n.mainLabel,
                    style: TextStyle(
                        fontSize: isTablet ? 18 : 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: Colors.white)),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final section in sections) ...[
                  if (section.title != null)
                    _sectionTitle(section.title!, isTablet),
                  for (final row in section.rows) ...[
                    _row(row, isTablet),
                    const Divider(height: 1, color: Colors.white12),
                  ],
                ],
            ],
          ),
        );
      },
    );
  }
}
