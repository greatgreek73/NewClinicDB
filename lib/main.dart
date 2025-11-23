import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'pages/add_patient_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/patient_details_page.dart';
import 'pages/search_page.dart';
import 'theme/app_colors.dart';
import 'theme/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(kClinicOverlayStyle);

  String? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (error, stack) {
    firebaseInitError = error.toString();
    // Keep running the app even if Firebase fails to init so we don't get a black screen.
    // ignore: avoid_print
    print('Firebase init failed: $error\n$stack');
  }

  runApp(MyApp(firebaseInitError: firebaseInitError));
}

class MyApp extends StatelessWidget {
  final String? firebaseInitError;

  const MyApp({Key? key, this.firebaseInitError}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (firebaseInitError != null) {
      return MaterialApp(
        title: 'Dental Clinic Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.bg,
          fontFamily: 'Inter',
        ),
        home: _FirebaseErrorScreen(message: firebaseInitError!),
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
      },
      home: const ClinicDashboardPage(),
    );
  }
}

class _FirebaseErrorScreen extends StatelessWidget {
  final String message;

  const _FirebaseErrorScreen({required this.message});

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
                'Firebase setup error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The app could not connect to Firebase. Please check google-services files, SHA-1/Apple Team IDs, and Play Services availability.\n\nDetails:\n$message',
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


