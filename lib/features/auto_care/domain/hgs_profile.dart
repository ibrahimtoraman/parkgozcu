import 'dart:convert';

class HgsProfile {
  const HgsProfile({
    required this.plate,
    required this.tagNumber,
    required this.balance,
    this.balanceUpdatedAt,
    this.lowBalanceThreshold = 50,
  });

  final String plate;
  final String tagNumber;
  final double balance;
  final DateTime? balanceUpdatedAt;
  final double lowBalanceThreshold;

  bool get isLowBalance => balance < lowBalanceThreshold;

  HgsProfile copyWith({
    String? plate,
    String? tagNumber,
    double? balance,
    DateTime? balanceUpdatedAt,
    double? lowBalanceThreshold,
  }) {
    return HgsProfile(
      plate: plate ?? this.plate,
      tagNumber: tagNumber ?? this.tagNumber,
      balance: balance ?? this.balance,
      balanceUpdatedAt: balanceUpdatedAt ?? this.balanceUpdatedAt,
      lowBalanceThreshold: lowBalanceThreshold ?? this.lowBalanceThreshold,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plate': plate,
      'tagNumber': tagNumber,
      'balance': balance,
      'balanceUpdatedAt': balanceUpdatedAt?.toIso8601String(),
      'lowBalanceThreshold': lowBalanceThreshold,
    };
  }

  factory HgsProfile.fromMap(Map<String, dynamic> map) {
    return HgsProfile(
      plate: map['plate'] as String? ?? '',
      tagNumber: map['tagNumber'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      balanceUpdatedAt: DateTime.tryParse(
        map['balanceUpdatedAt'] as String? ?? '',
      ),
      lowBalanceThreshold:
          (map['lowBalanceThreshold'] as num?)?.toDouble() ?? 50,
    );
  }

  static HgsProfile? fromJson(String raw) {
    if (raw.isEmpty) return null;
    return HgsProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  String toJson() => jsonEncode(toMap());
}
