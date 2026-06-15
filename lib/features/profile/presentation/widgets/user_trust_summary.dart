import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/user_trust_profile.dart';

class UserTrustSummary extends StatelessWidget {
  const UserTrustSummary({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final UserTrustProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (profile.totalReports == 0 && profile.score == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            compact
                ? 'Henüz topluluk istatistiği oluşmadı.'
                : 'Bu kullanıcı henüz topluluk istatistiği oluşturmamış.',
            style: const TextStyle(color: AppColors.mediumGrey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryLine(
                  icon: Icons.star_rounded,
                  iconColor: Colors.amber.shade700,
                  text:
                      '⭐ ${profile.communityRating.toStringAsFixed(1)} Puan',
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  icon: Icons.verified_rounded,
                  iconColor: AppColors.red,
                  text:
                      '✅ ${profile.totalVerificationsReceived} Doğrulanmış Bildirim',
                ),
                if (profile.totalReports > 0) ...[
                  const SizedBox(height: 10),
                  _SummaryLine(
                    icon: Icons.analytics_outlined,
                    iconColor: AppColors.mediumGrey,
                    text:
                        'Doğrulama oranı %${(profile.verificationRate * 100).round()}',
                  ),
                ],
              ],
            ),
          ),
        ),
        if (profile.badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...profile.badges.map(
            (badge) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BadgeCard(badge: badge),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.lightGrey,
                child: Icon(Icons.military_tech_outlined,
                    color: AppColors.mediumGrey),
              ),
              title: const Text('Henüz rozet yok'),
              subtitle: const Text(
                'Güvenilir Kullanıcı, Aktif Katılımcı ve Topluluk Lideri rozetleri burada görünür.',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge});

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: badge.color.withValues(alpha: 0.14),
          child: Text(badge.emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          '🏅 ${badge.label}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: badge.color,
          ),
        ),
        subtitle: Text(badge.description),
      ),
    );
  }
}
