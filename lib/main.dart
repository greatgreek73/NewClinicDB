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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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


