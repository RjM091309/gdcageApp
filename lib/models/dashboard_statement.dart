/// One row under "Add Charge" in DashboardStatement (F&B, Hotel, Incidental, Delivery, ...).
/// Category list is whatever's active in services_category — not hardcoded, so new categories
/// added on the backend show up here automatically.
class ServiceCategoryBalance {
  final String key;
  final String label;
  final int balance;

  const ServiceCategoryBalance({
    required this.key,
    required this.label,
    required this.balance,
  });

  factory ServiceCategoryBalance.fromJson(Map<String, dynamic> json) {
    return ServiceCategoryBalance(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      balance: DashboardStatement.numFromJson(json, 'balance'),
    );
  }
}

/// Response from GET /api/dashboard-statement.
class DashboardStatement {
  final bool success;
  final int company;
  final int credit;
  final int expenses;
  final int lossAmount;
  final int commission;
  final int additionalCommission;
  final List<ServiceCategoryBalance> serviceCategories;
  final int tipBalance;
  final int guestLine;

  const DashboardStatement({
    required this.success,
    required this.company,
    required this.credit,
    required this.expenses,
    required this.lossAmount,
    required this.commission,
    required this.additionalCommission,
    required this.serviceCategories,
    required this.tipBalance,
    required this.guestLine,
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

  factory DashboardStatement.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['service_categories'] as List<dynamic>? ?? [];
    return DashboardStatement(
      success: json['success'] as bool? ?? false,
      company: numFromJson(json, 'company'),
      credit: numFromJson(json, 'credit'),
      expenses: numFromJson(json, 'expenses'),
      lossAmount: numFromJson(json, 'loss_amount'),
      commission: numFromJson(json, 'commission'),
      additionalCommission: numFromJson(json, 'additional_commission'),
      serviceCategories: rawCategories
          .map((e) => ServiceCategoryBalance.fromJson(e as Map<String, dynamic>))
          .toList(),
      tipBalance: numFromJson(json, 'tip_balance'),
      guestLine: numFromJson(json, 'guest_line'),
    );
  }

  /// Empty placeholder for loading/error states.
  const DashboardStatement.empty()
      : this(
          success: false,
          company: 0,
          credit: 0,
          expenses: 0,
          lossAmount: 0,
          commission: 0,
          additionalCommission: 0,
          serviceCategories: const [],
          tipBalance: 0,
          guestLine: 0,
        );
}
