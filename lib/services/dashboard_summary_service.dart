import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../models/dashboard_summary.dart';

class DashboardSummaryService {
  DashboardSummaryService._();
  static final DashboardSummaryService instance = DashboardSummaryService._();

  Future<DashboardSummary> fetchSummary() async {
    try {
      final res = await http.get(Uri.parse(dashboardSummaryApiUrl));
      if (res.statusCode != 200) return const DashboardSummary.empty();
      final json = _parseJson(res.body);
      if (json == null) return const DashboardSummary.empty();
      return DashboardSummary.fromJson(json);
    } catch (_) {
      return const DashboardSummary.empty();
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
