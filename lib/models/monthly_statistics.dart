/// One month's row in the "statistics" popup: Win/Loss, Share, Commission, expenses, NGR.
class MonthlyStatRow {
  final String monthKey;
  final String programLabel;
  final int winLoss;
  final int share;
  final int commission;
  final int expenses;
  final int ngr;

  const MonthlyStatRow({
    required this.monthKey,
    required this.programLabel,
    required this.winLoss,
    required this.share,
    required this.commission,
    required this.expenses,
    required this.ngr,
  });

  factory MonthlyStatRow.fromJson(Map<String, dynamic> json) {
    return MonthlyStatRow(
      monthKey: (json['month_key'] ?? '').toString(),
      programLabel: (json['program_label'] ?? '').toString(),
      winLoss: MonthlyStatistics.numFromJson(json, 'win_loss'),
      share: MonthlyStatistics.numFromJson(json, 'share'),
      commission: MonthlyStatistics.numFromJson(json, 'commission'),
      expenses: MonthlyStatistics.numFromJson(json, 'expenses'),
      ngr: MonthlyStatistics.numFromJson(json, 'ngr'),
    );
  }
}

/// Response from GET /api/monthly-statistics.
class MonthlyStatistics {
  final bool success;
  final int year;
  final List<MonthlyStatRow> months;

  const MonthlyStatistics({
    required this.success,
    required this.year,
    required this.months,
  });

  /// Parse numeric value from API (may be int, double, or string e.g. "12345.00" from MySQL DECIMAL).
  static int numFromJson(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final d = double.tryParse(s);
    return d?.round() ?? 0;
  }

  factory MonthlyStatistics.fromJson(Map<String, dynamic> json) {
    final rawMonths = json['months'] as List<dynamic>? ?? [];
    return MonthlyStatistics(
      success: json['success'] as bool? ?? false,
      year: numFromJson(json, 'year'),
      months: rawMonths
          .map((e) => MonthlyStatRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Empty placeholder for loading/error states.
  const MonthlyStatistics.empty()
      : this(success: false, year: 0, months: const []);
}
