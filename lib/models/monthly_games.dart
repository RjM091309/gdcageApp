/// One row under "On-Going Game" — a currently active/unsettled game for one guest/account.
class OngoingGameRow {
  final int gameId;
  final String account;
  final int buyIn;
  final int cashOut;
  final int commission;
  final int winLoss;

  const OngoingGameRow({
    required this.gameId,
    required this.account,
    required this.buyIn,
    required this.cashOut,
    required this.commission,
    required this.winLoss,
  });

  factory OngoingGameRow.fromJson(Map<String, dynamic> json) {
    return OngoingGameRow(
      gameId: MonthlyGames.numFromJson(json, 'game_id'),
      account: (json['account'] ?? '').toString(),
      buyIn: MonthlyGames.numFromJson(json, 'buy_in'),
      cashOut: MonthlyGames.numFromJson(json, 'cash_out'),
      commission: MonthlyGames.numFromJson(json, 'commission'),
      winLoss: MonthlyGames.numFromJson(json, 'win_loss'),
    );
  }
}

/// Aggregate totals for all Settled games on one day (settled_today / settled_previous).
class SettledGameTotals {
  final String date;
  final int gameCount;
  final int buyIn;
  final int cashOut;
  final int commission;
  final int winLoss;

  const SettledGameTotals({
    required this.date,
    required this.gameCount,
    required this.buyIn,
    required this.cashOut,
    required this.commission,
    required this.winLoss,
  });

  factory SettledGameTotals.fromJson(Map<String, dynamic> json) {
    return SettledGameTotals(
      date: (json['date'] ?? '').toString(),
      gameCount: MonthlyGames.numFromJson(json, 'game_count'),
      buyIn: MonthlyGames.numFromJson(json, 'buy_in'),
      cashOut: MonthlyGames.numFromJson(json, 'cash_out'),
      commission: MonthlyGames.numFromJson(json, 'commission'),
      winLoss: MonthlyGames.numFromJson(json, 'win_loss'),
    );
  }

  static const empty = SettledGameTotals(
    date: '',
    gameCount: 0,
    buyIn: 0,
    cashOut: 0,
    commission: 0,
    winLoss: 0,
  );
}

/// Response from GET /api/monthly-games.
class MonthlyGames {
  final bool success;
  final List<OngoingGameRow> ongoing;
  final SettledGameTotals settledToday;
  final SettledGameTotals settledPrevious;

  const MonthlyGames({
    required this.success,
    required this.ongoing,
    required this.settledToday,
    required this.settledPrevious,
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

  factory MonthlyGames.fromJson(Map<String, dynamic> json) {
    final rawOngoing = json['ongoing'] as List<dynamic>? ?? [];
    return MonthlyGames(
      success: json['success'] as bool? ?? false,
      ongoing: rawOngoing
          .map((e) => OngoingGameRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      settledToday: json['settled_today'] != null
          ? SettledGameTotals.fromJson(json['settled_today'] as Map<String, dynamic>)
          : SettledGameTotals.empty,
      settledPrevious: json['settled_previous'] != null
          ? SettledGameTotals.fromJson(json['settled_previous'] as Map<String, dynamic>)
          : SettledGameTotals.empty,
    );
  }

  /// Empty placeholder for loading/error states.
  const MonthlyGames.empty()
      : this(
          success: false,
          ongoing: const [],
          settledToday: SettledGameTotals.empty,
          settledPrevious: SettledGameTotals.empty,
        );
}
