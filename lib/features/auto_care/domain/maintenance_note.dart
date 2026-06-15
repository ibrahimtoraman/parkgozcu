import 'dart:convert';

class MaintenanceNote {
  const MaintenanceNote({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.description,
    this.kilometer,
  });

  final String id;
  final String title;
  final String category;
  final DateTime date;
  final String description;
  final int? kilometer;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'date': date.toIso8601String(),
      'description': description,
      'kilometer': kilometer,
    };
  }

  factory MaintenanceNote.fromMap(Map<String, dynamic> map) {
    return MaintenanceNote(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'Diğer',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      description: map['description'] as String? ?? '',
      kilometer: map['kilometer'] as int?,
    );
  }

  static List<MaintenanceNote> listFromJson(String raw) {
    if (raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => MaintenanceNote.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<MaintenanceNote> notes) {
    return jsonEncode(notes.map((note) => note.toMap()).toList());
  }
}
