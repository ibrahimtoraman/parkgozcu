import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/user_formatter.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../reports/presentation/report_controller.dart';
import '../data/profile_repository.dart';

class UserPublicProfilePage extends StatelessWidget {
  const UserPublicProfilePage({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final reports = context.read<ReportController>();
    final profileRepo = context.read<ProfileRepository>();
    final currentUserId = auth.user?.id;
    final isOwnProfile = currentUserId == user.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı Profili')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFE8F0FF),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name.characters.first.toUpperCase()
                          : 'P',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatUserTag(user.id),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StreamBuilder<int>(
                  stream: reports.watchUserReportCount(user.id),
                  builder: (context, snapshot) {
                    return _StatCard(
                      label: 'Bildirim',
                      value: '${snapshot.data ?? 0}',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<int>(
                  stream: reports.watchVerifiedUserReportCount(user.id),
                  builder: (context, snapshot) {
                    return _StatCard(
                      label: 'Doğrulanan',
                      value: '${snapshot.data ?? 0}',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<int>(
                  stream: profileRepo.watchAppreciationCount(user.id),
                  builder: (context, snapshot) {
                    return _StatCard(
                      label: 'Değer',
                      value: '${snapshot.data ?? 0}',
                    );
                  },
                ),
              ),
            ],
          ),
          if (!isOwnProfile && currentUserId != null) ...[
            const SizedBox(height: 16),
            StreamBuilder<bool>(
              stream: profileRepo.watchHasGivenAppreciation(
                targetUserId: user.id,
                giverUserId: currentUserId,
              ),
              builder: (context, snapshot) {
                final alreadyGiven = snapshot.data ?? false;
                return FilledButton.icon(
                  onPressed: alreadyGiven
                      ? null
                      : () => _giveAppreciation(context),
                  icon: Icon(alreadyGiven ? Icons.favorite : Icons.favorite_border),
                  label: Text(
                    alreadyGiven ? 'Değer verdin' : 'Kişiye değer ver',
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _giveAppreciation(BuildContext context) async {
    final profileRepo = context.read<ProfileRepository>();
    try {
      await profileRepo.giveAppreciation(user.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Değerin iletildi.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem yapılamadı: $error')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.red,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
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
