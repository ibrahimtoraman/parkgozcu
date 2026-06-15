import 'package:shared_preferences/shared_preferences.dart';

import '../domain/maintenance_note.dart';

class MaintenanceNoteStorage {
  static String _keyForUser(String userId) => 'maintenance_notes_$userId';

  Future<List<MaintenanceNote>> loadNotes(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyForUser(userId));
    if (raw == null || raw.isEmpty) return const [];
    return MaintenanceNote.listFromJson(raw);
  }

  Future<void> saveNotes(String userId, List<MaintenanceNote> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keyForUser(userId), MaintenanceNote.listToJson(notes));
  }
}
