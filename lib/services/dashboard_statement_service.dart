import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../models/dashboard_statement.dart';

class DashboardStatementService {
  DashboardStatementService._();
  static final DashboardStatementService instance = DashboardStatementService._();

  Future<DashboardStatement> fetchStatement() async {
    try {
      final res = await http.get(Uri.parse(dashboardStatementApiUrl));
      if (res.statusCode != 200) return const DashboardStatement.empty();
      final json = _parseJson(res.body);
      if (json == null) return const DashboardStatement.empty();
      return DashboardStatement.fromJson(json);
    } catch (_) {
      return const DashboardStatement.empty();
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
