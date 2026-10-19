import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'screens/auth_screen.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const LockSyncApp());
}

class LockSyncApp extends StatelessWidget {
  const LockSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: AppTextStyles.fontSans,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.cyanAccent,
          surface: AppColors.cardBackground,
        ),
      ),
      home: const AuthScreen(),
    );
  }
}