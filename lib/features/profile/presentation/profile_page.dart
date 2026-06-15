import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_shell_controller.dart';
import '../../../core/widgets/edge_swipe_back.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auto_care/presentation/auto_care_page.dart';
import '../../reports/domain/entities/report.dart';
import '../../reports/presentation/home_map_page.dart';
import '../../reports/presentation/report_detail_page.dart';
import '../../reports/presentation/report_controller.dart';

class ProfileAwareShell extends StatelessWidget {
  const ProfileAwareShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AppShellController>();
    return Scaffold(
      body: IndexedStack(
        index: shell.selectedIndex,
        children: const [
          HomeMapPage(),
          ParkAreaPage(),
          AutoCarePage(),
          ProfilePage(),
        ],
      ),
      bottomNavigationBar: _ModernBottomNav(
        selectedIndex: shell.selectedIndex,
        onSelected: shell.selectTab,
      ),
    );
  }
}

class _ModernBottomNav extends StatelessWidget {
  const _ModernBottomNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (icon: Icons.map_rounded, label: 'Harita'),
    (icon: Icons.local_parking_rounded, label: 'Park'),
    (icon: Icons.car_repair_rounded, label: 'Oto Bakım'),
    (icon: Icons.person_rounded, label: 'Hesabım'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101A10) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            children: [
              for (var index = 0; index < _items.length; index++)
                Expanded(
                  child: _ModernNavItem(
                    icon: _items[index].icon,
                    label: _items[index].label,
                    isSelected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernNavItem extends StatelessWidget {
  const _ModernNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        isDark ? const Color(0xFFB6C3B6) : AppColors.mediumGrey;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.red.withValues(alpha: isDark ? 0.18 : 0.10)
              : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.red : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.red : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParkAreaPage extends StatelessWidget {
  const ParkAreaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Park Alanı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.red.withValues(alpha: 0.15),
                    child:
                        const Icon(Icons.local_parking, color: AppColors.red),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Yakındaki park alanları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bu bölümde ilerleyen aşamada güvenli park alanları, kullanıcı önerileri ve uygun park noktaları listelenecek.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (auth.isGuest) {
      return const _GuestProfileGate();
    }

    final reports = context.read<ReportController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesabım'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeroCard(
            name: user.name,
            email: _formatProfileEmail(user.email),
            photoUrl: user.photoUrl,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: reports.watchUserReportCount(user.id),
                  builder: (context, snapshot) {
                    return _MetricCard(
                      title: 'Bildirim',
                      value: '${snapshot.data ?? 0}',
                      icon: Icons.campaign,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<int>(
                  stream: reports.watchVerifiedUserReportCount(user.id),
                  builder: (context, snapshot) {
                    return _MetricCard(
                      title: 'Doğrulanan',
                      value: '${snapshot.data ?? 0}',
                      icon: Icons.verified,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<int>(
                  stream: reports.watchFalseFlaggedUserReportCount(user.id),
                  builder: (context, snapshot) {
                    return _MetricCard(
                      title: 'Yanlış bilgi',
                      value: '${snapshot.data ?? 0}',
                      icon: Icons.report,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              leading: const CircleAvatar(
                backgroundColor: AppColors.red,
                child: Icon(Icons.history, color: Colors.white),
              ),
              title: const Text(
                'Geçmiş bildirimlerim',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Yayınladığın tüm bildirimleri görüntüle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserReportsPage(userId: user.id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestProfileGate extends StatelessWidget {
  const _GuestProfileGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Hesabım')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.red.withValues(alpha: 0.14),
                    child: const Icon(Icons.lock_outline,
                        color: AppColors.red, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hesabım için giriş yapmalısın',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Misafir olarak haritadaki bildirimleri görebilirsin. Bildirim oluşturmak, geçmiş bildirimlerini görmek ve profil bilgilerine erişmek için Google veya Apple ile giriş yapmalısın.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: auth.signOut,
                    icon: const Icon(Icons.login),
                    label: const Text('Giriş ekranına dön'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserReportsPage extends StatefulWidget {
  const UserReportsPage({super.key, required this.userId});

  final String userId;

  @override
  State<UserReportsPage> createState() => _UserReportsPageState();
}

class _UserReportsPageState extends State<UserReportsPage> {
  static const _pageSize = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final reports = context.read<ReportController>();

    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: const Text('Geçmiş bildirimlerim')),
        body: StreamBuilder<List<ParkingReport>>(
          stream: reports.watchUserReports(widget.userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allReports = snapshot.data ?? const <ParkingReport>[];
            if (allReports.isEmpty) {
              return const Center(child: Text('Henüz bildirim oluşturmadın.'));
            }

            final pageCount = (allReports.length / _pageSize).ceil();
            final safePage = _page.clamp(0, pageCount - 1);
            if (safePage != _page) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _page = safePage);
              });
            }
            final start = safePage * _pageSize;
            final end = (start + _pageSize).clamp(0, allReports.length);
            final visibleReports = allReports.sublist(start, end);

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleReports.length,
                    itemBuilder: (context, index) {
                      return _ReportHistoryCard(report: visibleReports[index]);
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: safePage == 0
                                ? null
                                : () => setState(() => _page--),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Önceki'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('${safePage + 1} / $pageCount'),
                        ),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: safePage >= pageCount - 1
                                ? null
                                : () => setState(() => _page++),
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Sonraki'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Aydınlatma Metni',
              onTap: () => _openInfoPage(
                context,
                title: 'Aydınlatma Metni',
                body:
                    'ParkGözcü, bildirim oluşturma ve topluluk doğrulama özellikleri için konum, açıklama, fotoğraf ve hesap bilgilerini işler. Bu bilgiler uygulama deneyimini sağlamak, güvenliği artırmak ve bildirimleri toplulukla paylaşmak amacıyla kullanılır.',
              ),
            ),
            _SettingsTile(
              icon: Icons.gavel_outlined,
              title: 'Kullanım Koşulları',
              onTap: () => _openInfoPage(
                context,
                title: 'Kullanım Koşulları',
                body:
                    'ParkGözcü üzerinde paylaşılan bildirimlerin doğru, güncel ve iyi niyetli olması kullanıcıların sorumluluğundadır. Yanlış veya yanıltıcı içerikler topluluk doğrulamasıyla işaretlenebilir.',
              ),
            ),
            _SettingsTile(
              icon: Icons.mail_outline,
              title: 'İletişim',
              onTap: () => _openInfoPage(
                context,
                title: 'İletişim',
                body:
                    'Görüş, öneri ve destek talepleri için bizimle iletişime geçebilirsin.\n\nE-posta: destek@parkgozcu.com',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade700),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Çıkış Yap'),
            ),
          ],
        ),
      ),
    );
  }

  void _openInfoPage(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _InfoTextPage(title: title, body: body),
      ),
    );
  }
}

String _formatProfileEmail(String email) {
  final trimmed = email.trim();
  if (trimmed.isEmpty) {
    return 'E-posta paylaşılmadı';
  }
  if (trimmed.contains('privaterelay.appleid.com')) {
    return trimmed;
  }
  return trimmed;
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.red.withValues(alpha: 0.14),
          child: Icon(icon, color: AppColors.red),
        ),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _InfoTextPage extends StatelessWidget {
  const _InfoTextPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportHistoryCard extends StatelessWidget {
  const _ReportHistoryCard({required this.report});

  final ParkingReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ReportDetailPage(reportId: report.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReportPhotoPreview(urls: report.imageUrls),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(report.type.icon,
                            color: report.type.color, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            report.type.label,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (report.address.isNotEmpty)
                      Text(
                        report.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (report.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        report.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.mediumGrey),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd('tr_TR')
                          .add_Hm()
                          .format(report.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mediumGrey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.mediumGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportPhotoPreview extends StatelessWidget {
  const _ReportPhotoPreview({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        width: 76,
        height: 76,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.18)),
        ),
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.mediumGrey),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: _isInlineImage(urls.first)
          ? Image.memory(
              _decodeInlineImage(urls.first),
              width: 76,
              height: 76,
              fit: BoxFit.cover,
            )
          : CachedNetworkImage(
              imageUrl: urls.first,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 76,
                height: 76,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 76,
                height: 76,
                color: AppColors.lightGrey,
                child:
                    const Icon(Icons.broken_image, color: AppColors.mediumGrey),
              ),
            ),
    );
  }
}

bool _isInlineImage(String source) => source.startsWith('data:image/');

Uint8List _decodeInlineImage(String source) {
  final commaIndex = source.indexOf(',');
  final payload = commaIndex == -1 ? source : source.substring(commaIndex + 1);
  return base64Decode(payload);
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.name,
    required this.email,
    required this.photoUrl,
  });

  final String name;
  final String email;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppColors.red, AppColors.darkRed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.red.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55), width: 2),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl.isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl.isEmpty
                  ? const Icon(Icons.person, size: 38, color: AppColors.red)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.contains('privaterelay.appleid.com')) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Apple gizli e-posta kullanılıyor',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'ParkGözcü topluluk üyesi',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.red.withValues(alpha: 0.12),
            child: Icon(icon, color: AppColors.red, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }
}
