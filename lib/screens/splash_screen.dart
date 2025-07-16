// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Give the Flutter rendering pipeline a moment to build the widget
    // before attempting navigation. This prevents errors like "setState() called in initState()"
    await Future.delayed(Duration.zero);
    if (!mounted) {
      return; // Ensure the widget is still in the tree
    }

    final session = supabase.auth.currentSession;
    if (session == null) {
      // No active session found, redirect to the login screen
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // An active session exists, redirect to the main application route ('/')
      // The '/' route in main.dart will then handle redirection based on user role.
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple loading indicator displayed while checking session
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
