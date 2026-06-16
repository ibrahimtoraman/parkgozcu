import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/edge_swipe_back.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/hgs_storage.dart';
import '../domain/hgs_profile.dart';
import '../domain/hgs_transaction.dart';

class HgsTrackingTab extends StatefulWidget {
  const HgsTrackingTab({super.key});

  @override
  State<HgsTrackingTab> createState() => _HgsTrackingTabState();
}

class _HgsTrackingTabState extends State<HgsTrackingTab> {
  final _storage = HgsStorage();
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final _dateFormat = DateFormat.yMMMd('tr_TR');
  final _dateTimeFormat = DateFormat('d MMM yyyy, HH:mm', 'tr_TR');

  HgsProfile? _profile;
  List<HgsTransaction> _transactions = const [];
  bool _isLoading = true;
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<AuthController>().user?.id;
    unawaited(_loadData(userId));
  }

  Future<void> _loadData(String? userId) async {
    if (userId == null || userId == 'demo-guest') {
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _profile = null;
        _transactions = const [];
        _isLoading = false;
      });
      return;
    }

    if (_loadedUserId == userId && !_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final profile = await _storage.loadProfile(userId);
      final transactions = await _storage.loadTransactions(userId);
      transactions.sort((a, b) => b.date.compareTo(a.date));
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _profile = profile;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedUserId = userId;
        _profile = null;
        _transactions = const [];
        _isLoading = false;
      });
    }
  }

  Future<bool> _saveProfile(HgsProfile profile) async {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null || userId == 'demo-guest') return false;
    await _storage.saveProfile(userId, profile);
    if (!mounted) return false;
    setState(() => _profile = profile);
    return true;
  }

  Future<bool> _saveTransactions() async {
    final userId = context.read<AuthController>().user?.id;
    if (userId == null || userId == 'demo-guest') return false;
    await _storage.saveTransactions(userId, _transactions);
    return true;
  }

  Future<void> _openProfileEditor({HgsProfile? profile}) async {
    final saved = await Navigator.of(context).push<HgsProfile>(
      MaterialPageRoute(
        builder: (_) => HgsProfileEditorPage(profile: profile),
      ),
    );
    if (saved == null || !mounted) return;
    await _saveProfile(saved);
  }

  Future<void> _updateBalance() async {
    if (_profile == null) return;

    final controller = TextEditingController(
      text: _profile!.balance.toStringAsFixed(0),
    );

    final newBalance = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bakiye güncelle'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Güncel HGS bakiyesi',
            suffixText: '₺',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              final value =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              if (value == null || value < 0) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newBalance == null || !mounted) return;

    final updated = _profile!.copyWith(
      balance: newBalance,
      balanceUpdatedAt: DateTime.now(),
    );
    await _saveProfile(updated);
  }

  Future<void> _openTransactionEditor({HgsTransaction? transaction}) async {
    final saved = await Navigator.of(context).push<HgsTransaction>(
      MaterialPageRoute(
        builder: (_) => HgsTransactionEditorPage(transaction: transaction),
      ),
    );
    if (saved == null || !mounted) return;

    setState(() {
      if (transaction == null) {
        _transactions = [saved, ..._transactions];
      } else {
        _transactions = _transactions
            .map((item) => item.id == transaction.id ? saved : item)
            .toList();
      }
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    });
    await _saveTransactions();
  }

  Future<void> _deleteTransaction(HgsTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlemi sil'),
        content: const Text('Bu HGS kaydı silinsin mi?'),
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
      _transactions =
          _transactions.where((item) => item.id != transaction.id).toList();
    });
    await _saveTransactions();
  }

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_profile == null || _profile!.plate.isEmpty) {
      return _HgsSetupView(onSetup: () => _openProfileEditor());
    }

    final profile = _profile!;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _HgsBalanceCard(
              profile: profile,
              currencyFormat: _currencyFormat,
              dateTimeFormat: _dateTimeFormat,
              onUpdateBalance: _updateBalance,
              onEditProfile: () => _openProfileEditor(profile: profile),
            ),
            const SizedBox(height: 12),
            _HgsQuickLinks(onOpenLink: _openExternalLink),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'İşlem geçmişi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Text(
                  '${_transactions.length} kayıt',
                  style: const TextStyle(color: AppColors.mediumGrey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_transactions.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long,
                          size: 36, color: Colors.grey.shade500),
                      const SizedBox(height: 10),
                      const Text(
                        'Henüz HGS işlemi eklemedin.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Geçiş veya yükleme tutarlarını manuel kaydedebilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._transactions.map(
                (transaction) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _typeColor(transaction.type)
                          .withValues(alpha: 0.14),
                      child: Icon(
                        _typeIcon(transaction.type),
                        color: _typeColor(transaction.type),
                      ),
                    ),
                    title: Text(
                      '${transaction.type.label} • ${_currencyFormat.format(transaction.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${_dateFormat.format(transaction.date)}'
                      '${transaction.note.isEmpty ? '' : '\n${transaction.note}'}',
                    ),
                    isThreeLine: transaction.note.isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openTransactionEditor(transaction: transaction);
                        } else if (value == 'delete') {
                          _deleteTransaction(transaction);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                    ),
                    onTap: () =>
                        _openTransactionEditor(transaction: transaction),
                  ),
                ),
              ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _openTransactionEditor(),
            icon: const Icon(Icons.add),
            label: const Text('İşlem ekle'),
          ),
        ),
      ],
    );
  }

  Color _typeColor(HgsTransactionType type) {
    return switch (type) {
      HgsTransactionType.pass => Colors.orange.shade800,
      HgsTransactionType.topUp => Colors.green.shade700,
      HgsTransactionType.other => AppColors.mediumGrey,
    };
  }

  IconData _typeIcon(HgsTransactionType type) {
    return switch (type) {
      HgsTransactionType.pass => Icons.toll,
      HgsTransactionType.topUp => Icons.add_card,
      HgsTransactionType.other => Icons.more_horiz,
    };
  }
}

class _HgsSetupView extends StatelessWidget {
  const _HgsSetupView({required this.onSetup});

  final VoidCallback onSetup;

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
              child: const Icon(Icons.toll, color: AppColors.red, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'HGS takibini başlat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Plaka ve HGS etiket bilgilerini kaydet, bakiyeni manuel güncelle ve geçiş/yükleme hareketlerini takip et.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.playlist_add),
              label: const Text('HGS bilgilerini ekle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HgsBalanceCard extends StatelessWidget {
  const _HgsBalanceCard({
    required this.profile,
    required this.currencyFormat,
    required this.dateTimeFormat,
    required this.onUpdateBalance,
    required this.onEditProfile,
  });

  final HgsProfile profile;
  final NumberFormat currencyFormat;
  final DateFormat dateTimeFormat;
  final VoidCallback onUpdateBalance;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final updatedLabel = profile.balanceUpdatedAt == null
        ? 'Henüz güncellenmedi'
        : 'Son güncelleme: ${dateTimeFormat.format(profile.balanceUpdatedAt!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.plate.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Etiket: ${profile.tagNumber}',
                        style: const TextStyle(color: AppColors.mediumGrey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Bilgileri düzenle',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              currencyFormat.format(profile.balance),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: profile.isLowBalance ? Colors.red.shade700 : AppColors.red,
              ),
            ),
            const SizedBox(height: 4),
            Text(updatedLabel, style: const TextStyle(color: AppColors.mediumGrey)),
            if (profile.isLowBalance) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bakiye ${currencyFormat.format(profile.lowBalanceThreshold)} altında. Yükleme yapman gerekebilir.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUpdateBalance,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Bakiye güncelle'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _HgsQuickLinks.openTopUp(),
                    icon: const Icon(Icons.payment),
                    label: const Text('Bakiye yükle'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HgsQuickLinks extends StatelessWidget {
  const _HgsQuickLinks({required this.onOpenLink});

  final Future<void> Function(String url) onOpenLink;

  static Future<void> openTopUp() async {
    final uri = Uri.parse('https://hgs.ptt.gov.tr/');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ActionChip(
          avatar: const Icon(Icons.language, size: 18),
          label: const Text('PTT HGS'),
          onPressed: () => onOpenLink('https://hgs.ptt.gov.tr/'),
        ),
        ActionChip(
          avatar: const Icon(Icons.account_balance, size: 18),
          label: const Text('e-Devlet'),
          onPressed: () => onOpenLink(
            'https://www.turkiye.gov.tr/ulastirma-ve-altyapi-hizmetleri',
          ),
        ),
        ActionChip(
          avatar: const Icon(Icons.info_outline, size: 18),
          label: const Text('KGM'),
          onPressed: () => onOpenLink('https://www.kgm.gov.tr/'),
        ),
      ],
    );
  }
}

class HgsProfileEditorPage extends StatefulWidget {
  const HgsProfileEditorPage({super.key, this.profile});

  final HgsProfile? profile;

  @override
  State<HgsProfileEditorPage> createState() => _HgsProfileEditorPageState();
}

class _HgsProfileEditorPageState extends State<HgsProfileEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  final _tagController = TextEditingController();
  final _balanceController = TextEditingController();
  final _thresholdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _plateController.text = profile?.plate ?? '';
    _tagController.text = profile?.tagNumber ?? '';
    _balanceController.text = profile == null
        ? ''
        : profile.balance.toStringAsFixed(0);
    _thresholdController.text = profile == null
        ? '50'
        : profile.lowBalanceThreshold.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _plateController.dispose();
    _tagController.dispose();
    _balanceController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final balance = double.parse(
      _balanceController.text.trim().replaceAll(',', '.'),
    );
    final threshold = double.parse(
      _thresholdController.text.trim().replaceAll(',', '.'),
    );

    Navigator.of(context).pop(
      HgsProfile(
        plate: _plateController.text.trim().toUpperCase(),
        tagNumber: _tagController.text.trim(),
        balance: balance,
        balanceUpdatedAt: DateTime.now(),
        lowBalanceThreshold: threshold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.profile == null ? 'HGS bilgileri' : 'HGS düzenle'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Plaka',
                    hintText: '34 ABC 123',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Plaka gir.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tagController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'HGS etiket numarası',
                    hintText: 'Etiket veya kart numarası',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Etiket no gir.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Güncel bakiye',
                    suffixText: '₺',
                  ),
                  validator: (value) {
                    final parsed =
                        double.tryParse((value ?? '').replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) return 'Geçerli bakiye gir.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _thresholdController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Düşük bakiye uyarısı',
                    suffixText: '₺',
                    helperText: 'Bu tutarın altına düşünce uyarı gösterilir.',
                  ),
                  validator: (value) {
                    final parsed =
                        double.tryParse((value ?? '').replaceAll(',', '.'));
                    if (parsed == null || parsed < 0) return 'Geçerli tutar gir.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Canlı HGS bakiyesi resmi API ile alınamadığı için bakiyeyi PTT/banka uygulamasından kontrol edip buraya manuel girmen gerekir.',
                  style: TextStyle(color: AppColors.mediumGrey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Kaydet')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HgsTransactionEditorPage extends StatefulWidget {
  const HgsTransactionEditorPage({super.key, this.transaction});

  final HgsTransaction? transaction;

  @override
  State<HgsTransactionEditorPage> createState() =>
      _HgsTransactionEditorPageState();
}

class _HgsTransactionEditorPageState extends State<HgsTransactionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _dateFormat = DateFormat.yMMMd('tr_TR');

  late HgsTransactionType _selectedType;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.transaction?.type ?? HgsTransactionType.pass;
    _selectedDate = widget.transaction?.date ?? DateTime.now();
    _amountController.text = widget.transaction == null
        ? ''
        : widget.transaction!.amount.toStringAsFixed(2);
    _noteController.text = widget.transaction?.note ?? '';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      HgsTransaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        type: _selectedType,
        amount: double.parse(_amountController.text.trim().replaceAll(',', '.')),
        date: _selectedDate,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.transaction == null ? 'HGS işlemi ekle' : 'İşlemi düzenle'),
          actions: [
            TextButton(onPressed: _save, child: const Text('Kaydet')),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<HgsTransactionType>(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: 'İşlem türü'),
                  items: HgsTransactionType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedType = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tutar',
                    suffixText: '₺',
                  ),
                  validator: (value) {
                    final parsed =
                        double.tryParse((value ?? '').replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) return 'Geçerli tutar gir.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('tr', 'TR'),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Tarih'),
                    child: Row(
                      children: [
                        Expanded(child: Text(_dateFormat.format(_selectedDate))),
                        const Icon(Icons.calendar_month),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Not (isteğe bağlı)',
                    hintText: 'Örn: İstanbul-Ankara geçişi',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Kaydet')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
