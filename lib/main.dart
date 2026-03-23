import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_route_observer.dart';
import 'pages/add_patient_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/patient_3d_graph_page.dart';
import 'pages/patient_details_page.dart';
import 'pages/schedule_page.dart';
import 'pages/search_page.dart';
import 'pages/stats_page.dart';
import 'pages/waiting_room_page.dart';
import 'pages/waiting_room_reason_settings_page.dart';
import 'supabase_config.dart';
import 'theme/app_colors.dart';
import 'theme/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(kClinicOverlayStyle);

  String? supabaseInitError;
  final supabaseUrl = SupabaseConfig.url.trim();
  final supabaseAnonKey = SupabaseConfig.anonKey.trim();

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    supabaseInitError =
        'Missing Supabase credentials. Set --dart-define values or fill lib/supabase_config.local.dart.';
  } else {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    } catch (error, stack) {
      supabaseInitError = error.toString();
      // ignore: avoid_print
      print('Supabase init failed: $error\n$stack');
    }
  }

  runApp(MyApp(supabaseInitError: supabaseInitError));
}

class MyApp extends StatelessWidget {
  final String? supabaseInitError;

  const MyApp({Key? key, this.supabaseInitError}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (supabaseInitError != null) {
      return MaterialApp(
        title: 'Dental Clinic Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          fontFamily: 'Inter',
        ),
        home: _SupabaseErrorScreen(message: supabaseInitError!),
      );
    }

    return MaterialApp(
      title: 'Dental Clinic Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        // Заработает, если подключишь Inter в pubspec.yaml
        fontFamily: 'Inter',
      ),
      routes: {
        SearchPage.routeName: (context) => const SearchPage(),
        AddPatientPage.routeName: (context) => const AddPatientPage(),
        PatientDetailsPage.routeName: (context) => const PatientDetailsPage(),
        Patient3DGraphPage.routeName: (context) => const Patient3DGraphPage(),
        SchedulePage.routeName: (context) => const SchedulePage(),
        StatsPage.routeName: (context) => const StatsPage(),
        WaitingRoomPage.routeName: (context) => const WaitingRoomPage(),
        WaitingRoomReasonSettingsPage.routeName:
            (context) => const WaitingRoomReasonSettingsPage(),
      },
      navigatorObservers: [appRouteObserver],
      home: const ClinicDashboardPage(),
    );
  }
}

class _SupabaseErrorScreen extends StatelessWidget {
  final String message;

  const _SupabaseErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: AppColors.accent, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Supabase setup error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The app could not connect to Supabase. Configure --dart-define SUPABASE_URL/SUPABASE_ANON_KEY or fill lib/supabase_config.local.dart.\n\nDetails:\n$message',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textMuted.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
