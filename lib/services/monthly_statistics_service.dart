import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../models/monthly_statistics.dart';

class MonthlyStatisticsService {
  MonthlyStatisticsService._();
  static final MonthlyStatisticsService instance = MonthlyStatisticsService._();

  Future<MonthlyStatistics> fetchStatistics({int? year}) async {
    try {
      final res = await http.get(Uri.parse(monthlyStatisticsApiUrl(year: year)));
      if (res.statusCode != 200) return const MonthlyStatistics.empty();
      final json = _parseJson(res.body);
      if (json == null) return const MonthlyStatistics.empty();
      return MonthlyStatistics.fromJson(json);
    } catch (_) {
      return const MonthlyStatistics.empty();
    }
  }

  Map<String, dynamic>? _parseJson(String body) {
    try {
      if (body.isEmpty) return null;
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {
      return null;
    }
  }
}
