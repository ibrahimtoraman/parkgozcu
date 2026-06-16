import 'package:shared_preferences/shared_preferences.dart';

import '../domain/hgs_profile.dart';
import '../domain/hgs_transaction.dart';

class HgsStorage {
  static String _profileKey(String userId) => 'hgs_profile_$userId';
  static String _transactionsKey(String userId) => 'hgs_transactions_$userId';

  Future<HgsProfile?> loadProfile(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey(userId));
    if (raw == null || raw.isEmpty) return null;
    return HgsProfile.fromJson(raw);
  }

  Future<void> saveProfile(String userId, HgsProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(userId), profile.toJson());
  }

  Future<List<HgsTransaction>> loadTransactions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_transactionsKey(userId));
    if (raw == null || raw.isEmpty) return const [];
    return HgsTransaction.listFromJson(raw);
  }

  Future<void> saveTransactions(
    String userId,
    List<HgsTransaction> transactions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _transactionsKey(userId),
      HgsTransaction.listToJson(transactions),
    );
  }
}
