import 'package:flutter/material.dart';
import 'package:healthsecure/core/theme/app_theme.dart';
import 'package:healthsecure/core/constants/app_constants.dart';
import 'package:healthsecure/features/auth/presentation/pages/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HealthSecureApp());
}

class HealthSecureApp extends StatelessWidget {
  const HealthSecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, 
      home: const LoginPage(),
    );
  }
}