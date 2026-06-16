import 'dart:convert';

enum HgsTransactionType {
  pass,
  topUp,
  other;

  String get label {
    return switch (this) {
      HgsTransactionType.pass => 'Geçiş',
      HgsTransactionType.topUp => 'Yükleme',
      HgsTransactionType.other => 'Diğer',
    };
  }

  static HgsTransactionType fromName(String? value) {
    return HgsTransactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => HgsTransactionType.other,
    );
  }
}

class HgsTransaction {
  const HgsTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.note = '',
  });

  final String id;
  final HgsTransactionType type;
  final double amount;
  final DateTime date;
  final String note;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory HgsTransaction.fromMap(Map<String, dynamic> map) {
    return HgsTransaction(
      id: map['id'] as String? ?? '',
      type: HgsTransactionType.fromName(map['type'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String? ?? '',
    );
  }

  static List<HgsTransaction> listFromJson(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => HgsTransaction.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<HgsTransaction> items) {
    return jsonEncode(items.map((item) => item.toMap()).toList());
  }
}
