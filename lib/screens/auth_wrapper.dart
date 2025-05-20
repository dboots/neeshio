import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Show loading screen while checking authentication status
    if (authService.isLoading) {
      return const SplashScreen();
    }

    // If authenticated, show home screen, otherwise show login screen
    return authService.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
  }
}
