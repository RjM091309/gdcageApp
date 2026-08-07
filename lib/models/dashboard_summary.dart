/// Response from GET /api/dashboard-summary.
class DashboardSummary {
  final bool success;
  final int winLoss;
  final int ngr;
  final int totalCommission;
  final int gameCommission;
  final int additionalCommission;
  final int expenses;
  final int cageRolling;
  final int casinoRolling;

  const DashboardSummary({
    required this.success,
    required this.winLoss,
    required this.ngr,
    required this.totalCommission,
    required this.gameCommission,
    required this.additionalCommission,
    required this.expenses,
    required this.cageRolling,
    required this.casinoRolling,
  });

  /// Parse numeric value from API (may be int, double, or string e.g. "12345.00" from MySQL DECIMAL).
  static int _num(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.round();
    final s = v.toString().trim();
    if (s.isEmpty) return 0;
    final d = double.tryParse(s);
    return d?.round() ?? 0;
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      success: json['success'] as bool? ?? false,
      winLoss: _num(json, 'win_loss'),
      ngr: _num(json, 'ngr'),
      totalCommission: _num(json, 'total_commission'),
      gameCommission: _num(json, 'game_commission'),
      additionalCommission: _num(json, 'additional_commission'),
      expenses: _num(json, 'expenses'),
      cageRolling: _num(json, 'cage_rolling'),
      casinoRolling: _num(json, 'casino_rolling'),
    );
  }

  /// Empty placeholder for loading/error states.
  const DashboardSummary.empty()
      : this(
          success: false,
          winLoss: 0,
          ngr: 0,
          totalCommission: 0,
          gameCommission: 0,
          additionalCommission: 0,
          expenses: 0,
          cageRolling: 0,
          casinoRolling: 0,
        );
}
