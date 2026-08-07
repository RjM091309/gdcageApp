

const String apiBaseUrl = 'https://gdcage.3core21.com';

String get loginApiUrl => '$apiBaseUrl/api/auth/login';

String get realtimeApiUrl => '$apiBaseUrl/api/realtime';

String get dashboardSummaryApiUrl => '$apiBaseUrl/api/dashboard-summary';

String get dashboardStatementApiUrl => '$apiBaseUrl/api/dashboard-statement';

String get monthlyGamesApiUrl => '$apiBaseUrl/api/monthly-games';

String monthlyStatisticsApiUrl({int? year}) {
  final y = year ?? DateTime.now().year;
  return '$apiBaseUrl/api/monthly-statistics?year=$y';
}

String get notificationsApiUrl => '$apiBaseUrl/api/notifications';

String notificationsApiUrlWithPagination({int limit = 20, int offset = 0}) =>
    '$apiBaseUrl/api/notifications?limit=$limit&offset=$offset';

String get notificationsMarkAllReadUrl => '$apiBaseUrl/api/notifications/mark-all-read';

String notificationMarkReadUrl(int id) => '$apiBaseUrl/api/notifications/$id';

String notificationHideUrl(int id) => '$apiBaseUrl/api/notifications/$id';

String get socketUrl => apiBaseUrl;

String dailySettlementApiUrl({required String startDate, required String endDate}) =>
    '$apiBaseUrl/api/daily-settlement?start_date=$startDate&end_date=$endDate';

String monthlyAccumulatedApiUrl({required int year, required int month}) =>
    '$apiBaseUrl/api/monthly-accumulated?year=$year&month=$month';

String monthlyRollingCasinoByYearApiUrl(int year) =>
    '$apiBaseUrl/api/monthly-rolling-casino-by-year?year=$year';

String get markerApiUrl => '$apiBaseUrl/api/marker';

String rankingApiUrl({int? year, int? month, int? limit, int? offset}) {
  final now = DateTime.now();
  final y = year ?? now.year;
  final m = month ?? now.month;
  var url = '$apiBaseUrl/api/ranking?year=$y&month=$m';
  if (limit != null) url += '&limit=$limit';
  if (offset != null) url += '&offset=$offset';
  return url;
}
