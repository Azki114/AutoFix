// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and snackbarKey
import 'dart:async'; // Import StreamSubscription

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // A subscription to listen to authentication state changes.
  late final StreamSubscription<AuthState> _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _redirect();
  }

  @override
  void dispose() {
    _authStateSubscription.cancel(); // Cancel the subscription when the widget is disposed
    super.dispose();
  }

  Future<void> _redirect() async {
    // Wait for the UI to be built to ensure Navigator context is available
    await Future.delayed(Duration.zero);

    if (!mounted) return; // Ensure the widget is still mounted

    // Subscribe to authentication state changes to react in real-time
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (!mounted) return; // Ensure the widget is still mounted before performing UI operations

      // Handle different authentication events
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) {
        // If there's a session, try to fetch the user's role
        if (session != null) {
          _fetchAndNavigateUserRole(session.user.id);
        } else {
          // No session found, redirect to login
          _navigateToLogin();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        // If signed out, always redirect to login
        _navigateToLogin();
      }
      // For other events (e.g., password recovered, user updated),
      // we don't need explicit navigation here as _fetchAndNavigateUserRole
      // or subsequent screens will handle the state.
    });

    // Also perform an immediate check for the current user in case the listener
    // doesn't fire immediately on hot restart or first launch after a quick close.
    // This handles the initial state without waiting for the first auth event.
    if (supabase.auth.currentUser == null) {
      _navigateToLogin();
    } else {
      _fetchAndNavigateUserRole(supabase.auth.currentUser!.id);
    }
  }

  // Fetches the user's role and navigates to the appropriate screen
  Future<void> _fetchAndNavigateUserRole(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      final String? role = response['role'] as String?;

      if (!mounted) return; // Check again before navigating

      if (role == 'driver') {
        Navigator.of(context).pushReplacementNamed('/vehicle_owner_map');
      } else if (role == 'mechanic') {
        Navigator.of(context).pushReplacementNamed('/mechanic_dashboard');
      } else {
        // If role is null or unknown, assume incomplete profile or unassigned,
        // navigate to profile to complete or re-login if necessary.
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Your user role could not be determined. Please complete your profile.'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/profile');
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.message}. Please re-login.'),
          backgroundColor: Colors.red,
        ),
      );
      _navigateToLogin(); // Redirect to login on error
    } catch (e) {
      if (!mounted) return;
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}. Please re-login.'),
          backgroundColor: Colors.red,
        ),
      );
      _navigateToLogin(); // Redirect to login on error
    }
  }

  // Helper to navigate to the login screen
  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display a simple loading indicator while the redirection logic runs
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
