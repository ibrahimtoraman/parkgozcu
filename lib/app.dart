import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/services/location_service.dart';
import 'core/services/notification_service.dart';
import 'core/navigation/app_shell_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_page.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/reports/data/report_repository.dart';
import 'features/reports/presentation/report_controller.dart';

class ParkGozcuApp extends StatelessWidget {
  const ParkGozcuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => AppShellController()),
        Provider(
          create: (_) => AuthRepository(
            auth: FirebaseAuth.instance,
            firestore: FirebaseFirestore.instance,
          ),
        ),
        Provider(
          create: (_) => ReportRepository(
            auth: FirebaseAuth.instance,
            firestore: FirebaseFirestore.instance,
            storage: FirebaseStorage.instance,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthController(
            repository: context.read<AuthRepository>(),
            notificationService: context.read<NotificationService>(),
          )..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (context) => ReportController(
            repository: context.read<ReportRepository>(),
            locationService: context.read<LocationService>(),
          )..loadInitialLocation(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ParkGözcü',
        theme: AppTheme.light,
        themeMode: ThemeMode.light,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.user == null) {
      return const LoginPage();
    }

    return const ProfileAwareShell();
  }
}
