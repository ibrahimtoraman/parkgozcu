import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/user_formatter.dart';
import '../../../core/widgets/edge_swipe_back.dart';
import '../../reports/presentation/report_controller.dart';

class UserPublicProfilePage extends StatelessWidget {
  const UserPublicProfilePage({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final reports = context.read<ReportController>();

    return EdgeSwipeBack(
      child: Scaffold(
        appBar: AppBar(title: const Text('Kullanıcı Profili')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [AppColors.red, AppColors.darkRed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Text(
                      userName.isNotEmpty
                          ? userName.characters.first.toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Kullanıcı No: ${formatUserNumber(userId)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<int>(
                    stream: reports.watchUserReportCount(userId),
                    builder: (context, snapshot) {
                      return _ProfileMetricCard(
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
                    stream: reports.watchVerifiedUserReportCount(userId),
                    builder: (context, snapshot) {
                      return _ProfileMetricCard(
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
                    stream: reports.watchFalseFlaggedUserReportCount(userId),
                    builder: (context, snapshot) {
                      return _ProfileMetricCard(
                        title: 'Yanlış bilgi',
                        value: '${snapshot.data ?? 0}',
                        icon: Icons.report,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(userId)
                  .snapshots(),
              builder: (context, snapshot) {
                final score = snapshot.data?.data()?['score'] as int? ?? 0;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.red.withValues(alpha: 0.14),
                      child: const Icon(Icons.star, color: AppColors.red),
                    ),
                    title: const Text(
                      'Topluluk puanı',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Doğrulanan katkılar ve bildirimlerle artar.',
                    ),
                    trailing: Text(
                      '$score',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.red,
                          ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  const _ProfileMetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: AppColors.red, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mediumGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
