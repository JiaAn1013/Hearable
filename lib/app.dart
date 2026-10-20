import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/forgot_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/alerts/alert_coordinator.dart';

class HearAbleApp extends StatelessWidget {
  const HearAbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AlertCoordinator.navigatorKey,
      title: 'HearAble',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AuthGate.routeName,
      routes: {
        AuthGate.routeName: (_) => const AuthGate(),
        WelcomeScreen.routeName: (_) => const WelcomeScreen(),
        SignupScreen.routeName: (_) => const SignupScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
      },
    );
  }
}