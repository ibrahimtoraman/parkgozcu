import 'package:flutter/material.dart';

enum UserBadgeType {
  trustedUser,
  activeContributor,
  communityLeader,
}

class UserBadge {
  const UserBadge({
    required this.type,
    required this.label,
    required this.emoji,
    required this.color,
    required this.description,
  });

  final UserBadgeType type;
  final String label;
  final String emoji;
  final Color color;
  final String description;
}

class UserTrustProfile {
  const UserTrustProfile({
    required this.totalReports,
    required this.verifiedReportCount,
    required this.totalVerificationsReceived,
    required this.falseFlaggedReports,
    required this.score,
    required this.verificationRate,
    required this.communityRating,
    required this.badges,
  });

  final int totalReports;
  final int verifiedReportCount;
  final int totalVerificationsReceived;
  final int falseFlaggedReports;
  final int score;
  final double verificationRate;
  final double communityRating;
  final List<UserBadge> badges;

  static const empty = UserTrustProfile(
    totalReports: 0,
    verifiedReportCount: 0,
    totalVerificationsReceived: 0,
    falseFlaggedReports: 0,
    score: 0,
    verificationRate: 0,
    communityRating: 0,
    badges: [],
  );

  factory UserTrustProfile.fromData({
    required int totalReports,
    required int verifiedReportCount,
    required int totalVerificationsReceived,
    required int falseFlaggedReports,
    required int score,
  }) {
    final verificationRate =
        totalReports == 0 ? 0.0 : verifiedReportCount / totalReports;
    final falseRate =
        totalReports == 0 ? 0.0 : falseFlaggedReports / totalReports;
    final communityRating = totalReports == 0
        ? 0.0
        : (3.4 + (verificationRate * 1.6) - (falseRate * 1.2))
            .clamp(1.0, 5.0);

    final badges = <UserBadge>[];
    if (verificationRate >= 0.9 && totalReports >= 50) {
      badges.add(
        const UserBadge(
          type: UserBadgeType.trustedUser,
          label: 'Güvenilir Kullanıcı',
          emoji: '🟢',
          color: Color(0xFF2E7D32),
          description: 'Doğrulama oranı %90+ ve en az 50 bildirim',
        ),
      );
    }
    if (totalVerificationsReceived >= 100) {
      badges.add(
        const UserBadge(
          type: UserBadgeType.activeContributor,
          label: 'Aktif Katılımcı',
          emoji: '🔵',
          color: Color(0xFF1565C0),
          description: '100+ doğrulama almış bildirim',
        ),
      );
    }
    if (score >= 500) {
      badges.add(
        const UserBadge(
          type: UserBadgeType.communityLeader,
          label: 'Topluluk Lideri',
          emoji: '🟣',
          color: Color(0xFF6A1B9A),
          description: '500+ topluluk puanı',
        ),
      );
    }

    return UserTrustProfile(
      totalReports: totalReports,
      verifiedReportCount: verifiedReportCount,
      totalVerificationsReceived: totalVerificationsReceived,
      falseFlaggedReports: falseFlaggedReports,
      score: score,
      verificationRate: verificationRate,
      communityRating: communityRating,
      badges: badges,
    );
  }
}
