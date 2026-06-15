import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/user_formatter.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../reports/presentation/report_controller.dart';
import '../domain/user_trust_profile.dart';
import 'widgets/user_trust_summary.dart';

class UserPublicProfilePage extends StatelessWidget {
  const UserPublicProfilePage({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ReportController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Profili'),
      ),
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
          const SizedBox(height: 16),
          StreamBuilder<UserTrustProfile>(
            stream: controller.watchUserTrustProfile(user.id),
            builder: (context, snapshot) {
              final profile = snapshot.data ?? UserTrustProfile.empty;
              return UserTrustSummary(profile: profile);
            },
          ),
        ],
      ),
    );
  }
}
