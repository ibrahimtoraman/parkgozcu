import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/maintenance_note_storage.dart';
import '../domain/maintenance_note.dart';

class AutoCarePage extends StatefulWidget {
  const AutoCarePage({super.key});

  @override
  State<AutoCarePage> createState() => _AutoCarePageState();
}

class _AutoCarePageState extends State<AutoCarePage> {
  static const _categories = [
    'Periyodik Bakım',
    'Lastik',
    'Sigorta',
    'Servis',
    'Diğer',
  ];

  final _storage = MaintenanceNoteStorage();
  final _dateFormat = DateFormat.yMMMd('tr_TR');

  List<MaintenanceNote> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null || userId == 'demo-guest') {
      setState(() {
        _notes = const [];
        _isLoading = false;
      });
      return;
    }

    final notes = await _storage.loadNotes(userId);
    notes.sort((a, b) => b.date.compareTo(a.date));
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _persistNotes() async {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null || userId == 'demo-guest') return;
    await _storage.saveNotes(userId, _notes);
  }

  Future<void> _openNoteEditor({MaintenanceNote? note}) async {
    final titleController = TextEditingController(text: note?.title ?? '');
    final descriptionController =
        TextEditingController(text: note?.description ?? '');
    final kilometerController = TextEditingController(
      text: note?.kilometer?.toString() ?? '',
    );
    var selectedCategory = note?.category ?? _categories.first;
    var selectedDate = note?.date ?? DateTime.now();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note == null ? 'Bakım notu ekle' : 'Bakım notunu düzenle',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Başlık',
                        hintText: 'Örn: Yağ değişimi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedCategory = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarih'),
                      subtitle: Text(_dateFormat.format(selectedDate)),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2010),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 3)),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kilometerController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kilometre (isteğe bağlı)',
                        hintText: 'Örn: 84500',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Not',
                        hintText:
                            'Servis detayı, hatırlatma veya masraf bilgisi',
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Başlık girmelisin.')),
                          );
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: Text(note == null
                          ? 'Notu kaydet'
                          : 'Değişiklikleri kaydet'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved != true || !mounted) {
      titleController.dispose();
      descriptionController.dispose();
      kilometerController.dispose();
      return;
    }

    final kilometerText = kilometerController.text.trim();
    final kilometer =
        kilometerText.isEmpty ? null : int.tryParse(kilometerText);
    final updatedNote = MaintenanceNote(
      id: note?.id ?? const Uuid().v4(),
      title: titleController.text.trim(),
      category: selectedCategory,
      date: selectedDate,
      description: descriptionController.text.trim(),
      kilometer: kilometer,
    );

    titleController.dispose();
    descriptionController.dispose();
    kilometerController.dispose();

    setState(() {
      if (note == null) {
        _notes = [updatedNote, ..._notes];
      } else {
        _notes = _notes
            .map((item) => item.id == note.id ? updatedNote : item)
            .toList();
      }
      _notes.sort((a, b) => b.date.compareTo(a.date));
    });
    await _persistNotes();
  }

  Future<void> _deleteNote(MaintenanceNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notu sil'),
        content: Text('"${note.title}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _notes = _notes.where((item) => item.id != note.id).toList();
    });
    await _persistNotes();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Oto Bakım')),
      floatingActionButton: auth.isGuest
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openNoteEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Not ekle'),
            ),
      body: auth.isGuest
          ? _GuestAutoCareGate(onSignIn: auth.signOut)
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
                  ? _EmptyAutoCare(onAdd: () => _openNoteEditor())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding:
                                const EdgeInsets.fromLTRB(16, 12, 8, 12),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.red.withValues(alpha: 0.14),
                              child: Icon(
                                _categoryIcon(note.category),
                                color: AppColors.red,
                              ),
                            ),
                            title: Text(
                              note.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                    '${note.category} • ${_dateFormat.format(note.date)}'),
                                if (note.kilometer != null)
                                  Text('${note.kilometer} km'),
                                if (note.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    note.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openNoteEditor(note: note);
                                } else if (value == 'delete') {
                                  _deleteNote(note);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                    value: 'edit', child: Text('Düzenle')),
                                PopupMenuItem(
                                    value: 'delete', child: Text('Sil')),
                              ],
                            ),
                            onTap: () => _openNoteEditor(note: note),
                          ),
                        );
                      },
                    ),
    );
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      'Periyodik Bakım' => Icons.settings_suggest,
      'Lastik' => Icons.tire_repair,
      'Sigorta' => Icons.shield_outlined,
      'Servis' => Icons.car_repair,
      _ => Icons.note_alt_outlined,
    };
  }
}

class _EmptyAutoCare extends StatelessWidget {
  const _EmptyAutoCare({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.red.withValues(alpha: 0.12),
              child:
                  const Icon(Icons.car_repair, color: AppColors.red, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz bakım notun yok',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Periyodik bakım, lastik, sigorta ve servis notlarını burada takip edebilirsin.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('İlk notu ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestAutoCareGate extends StatelessWidget {
  const _GuestAutoCareGate({required this.onSignIn});

  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 42, color: AppColors.red),
            const SizedBox(height: 16),
            Text(
              'Bakım notları için giriş yap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Araç bakım notlarını kaydetmek için Google veya Apple ile giriş yapmalısın.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Giriş ekranına dön'),
            ),
          ],
        ),
      ),
    );
  }
}
