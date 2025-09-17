import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and snackbarKey
import 'dart:async'; // For Future.delayed

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

  /// Determines the user's authentication state and role, then navigates
  /// to the appropriate screen.
  Future<void> _redirect() async {
    // A brief delay allows Supabase to initialize and load any existing session
    // from local storage, preventing a flicker to the login screen.
    await Future.delayed(const Duration(milliseconds: 500));

    // If the widget is no longer in the tree, we should not proceed.
    if (!mounted) return;

    final session = supabase.auth.currentSession;

    if (session == null) {
      // If there is no active session, navigate to the login screen.
      _navigateTo('/login');
      return;
    }

    // If a session exists, fetch the user's role to determine their home screen.
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .single();

      final String? role = response['role'] as String?;

      if (!mounted) return; // Check again after the async call.

      if (role == 'driver') {
        _navigateTo('/vehicle_owner_map');
      } else if (role == 'mechanic') {
        _navigateTo('/mechanic_dashboard');
      } else {
        // If the role is missing or unknown, the user's profile might be incomplete.
        // Navigate them to the profile screen to resolve it.
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Please complete your profile information.'),
            backgroundColor: Colors.orange,
          ),
        );
        _navigateTo('/profile');
      }
    } on PostgrestException catch (e) {
      // If there's an error fetching the profile (e.g., network issue),
      // it's safest to send the user back to the login screen.
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
      _navigateTo('/login');
    } catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      _navigateTo('/login');
    }
  }

  /// A helper function to safely navigate to a new screen, replacing the current one.
  void _navigateTo(String routeName) {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The UI remains a simple loading indicator.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading AutoFix...", style: TextStyle(fontSize: 18, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }
}

