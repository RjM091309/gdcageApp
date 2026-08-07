import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_config.dart';
import '../models/monthly_games.dart';

class MonthlyGamesService {
  MonthlyGamesService._();
  static final MonthlyGamesService instance = MonthlyGamesService._();

  Future<MonthlyGames> fetchMonthlyGames() async {
    try {
      final res = await http.get(Uri.parse(monthlyGamesApiUrl));
      if (res.statusCode != 200) return const MonthlyGames.empty();
      final json = _parseJson(res.body);
      if (json == null) return const MonthlyGames.empty();
      return MonthlyGames.fromJson(json);
    } catch (_) {
      return const MonthlyGames.empty();
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
