import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/kilometer_formatter.dart';
import '../../../core/widgets/edge_swipe_back.dart';
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
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthController>().user?.id;
    unawaited(_ensureNotesLoaded(userId));
  }

  Future<void> _ensureNotesLoaded(String? userId) async {
    if (userId == null || userId == 'demo-guest') {
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _notes = const [];
        _isLoading = false;
      });
      return;
    }

    if (_loadedUserId == userId && !_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final notes = await _storage.loadNotes(userId);
      notes.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _notes = notes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _notes = const [];
        _isLoading = false;
      });
    }
  }

  Future<bool> _persistNotes() async {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null || userId == 'demo-guest') return false;

    try {
      await _storage.saveNotes(userId, _notes);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not kaydedilemedi. Tekrar dene.')),
        );
      }
      return false;
    }
  }

  Future<void> _openNoteEditor({MaintenanceNote? note}) async {
    final savedNote = await Navigator.of(context).push<MaintenanceNote>(
      MaterialPageRoute(
        builder: (_) => MaintenanceNoteEditorPage(
          note: note,
          categories: _categories,
        ),
      ),
    );

    if (savedNote == null || !mounted) return;

    setState(() {
      if (note == null) {
        _notes = [savedNote, ..._notes];
      } else {
        _notes = _notes
            .map((item) => item.id == note.id ? savedNote : item)
            .toList();
      }
      _notes.sort((a, b) => b.date.compareTo(a.date));
    });

    final persisted = await _persistNotes();
    if (persisted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                note == null ? 'Bakım notu kaydedildi.' : 'Not güncellendi.')),
      );
    }
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
                                  '${note.category} • ${_dateFormat.format(note.date)}',
                                ),
                                if (note.kilometer != null)
                                  Text(
                                    KilometerFormatter.formatForDisplay(
                                      note.kilometer!,
                                    ),
                                  ),
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
                                  value: 'edit',
                                  child: Text('Düzenle'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Sil'),
                                ),
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

class MaintenanceNoteEditorPage extends StatefulWidget {
  const MaintenanceNoteEditorPage({
    super.key,
    this.note,
    required this.categories,
  });

  final MaintenanceNote? note;
  final List<String> categories;

  @override
  State<MaintenanceNoteEditorPage> createState() =>
      _MaintenanceNoteEditorPageState();
}

class _MaintenanceNoteEditorPageState extends State<MaintenanceNoteEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _kilometerController = TextEditingController();
  final _dateFormat = DateFormat.yMMMd('tr_TR');

  late String _selectedCategory;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.note?.category ?? widget.categories.first;
    _selectedDate = widget.note?.date ?? DateTime.now();
    _titleController.text = widget.note?.title ?? '';
    _descriptionController.text = widget.note?.description ?? '';
    _kilometerController.text =
        KilometerFormatter.formatForInput(widget.note?.kilometer);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _kilometerController.dispose();
    super.dispose();
  }

  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _save() {
    _closeKeyboard();
    if (!_formKey.currentState!.validate()) return;

    final note = MaintenanceNote(
      id: widget.note?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      category: _selectedCategory,
      date: _selectedDate,
      description: _descriptionController.text.trim(),
      kilometer: KilometerFormatter.parse(_kilometerController.text),
    );

    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return EdgeSwipeBack(
      child: GestureDetector(
        onTap: _closeKeyboard,
        child: Scaffold(
          appBar: AppBar(
            title: Text(isEditing ? 'Notu düzenle' : 'Bakım notu ekle'),
            actions: [
              TextButton(
                onPressed: _save,
                child: const Text('Kaydet'),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bakım bilgileri',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Başlık',
                                hintText: 'Örn: Yağ değişimi',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Başlık girmelisin.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedCategory,
                              decoration:
                                  const InputDecoration(labelText: 'Kategori'),
                              items: widget.categories
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedCategory = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                _closeKeyboard();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2010),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365 * 3)),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Tarih',
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _dateFormat.format(_selectedDate),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_month),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _kilometerController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [KilometerInputFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Kilometre (isteğe bağlı)',
                                hintText: 'Örn: 150.000',
                                suffixText: 'KM',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _descriptionController,
                          minLines: 4,
                          maxLines: 6,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _closeKeyboard(),
                          decoration: const InputDecoration(
                            labelText: 'Not',
                            hintText:
                                'Servis detayı, hatırlatma veya masraf bilgisi',
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                          isEditing ? 'Değişiklikleri kaydet' : 'Notu kaydet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
