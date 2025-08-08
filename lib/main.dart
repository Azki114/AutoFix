// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv

// --- app's screen imports ---
import 'package:autofix/screens/login_screen.dart';
import 'package:autofix/screens/register_screen.dart';
import 'package:autofix/screens/profile_screen.dart'; // User Profile Screen
import 'package:autofix/screens/splash_screen.dart'; // For initial loading/redirection
import 'package:autofix/screens/vehicle_owner_map_screen.dart'; // Driver's map
import 'package:autofix/screens/mechanic_dashboard_screen.dart'; // Mechanic's dedicated screen

// --- Existing app screens ---
import 'package:autofix/screens/ai_diagnosis_screen.dart';
import 'package:autofix/screens/offline_guide_screen.dart';
import 'package:autofix/screens/settings_screen.dart';
import 'package:autofix/screens/terms_conditions_screen.dart';

// Global Supabase client instance
late final SupabaseClient supabase;

// Define a global key for the Scaffold Messenger to show SnackBars from anywhere
final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async initialization

  // Load environment variables from the .env file.
  await dotenv.load(fileName: ".env");

  // Retrieve Supabase URL and Anon Key from environment variables.
  final String? supabaseUrl = dotenv.env['SUPABASE_URL'];
  final String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Check if the Supabase environment variables were successfully loaded.
  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    print('Error: Supabase URL or Anon Key not found in .env file. Please check your .env and pubspec.yaml assets.');
    throw Exception('Supabase environment variables are missing.');
  }

  // Initialize the Supabase client.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    
  );
  supabase = Supabase.instance.client; // Get the client instance after initialization

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Define a value notifier to hold the user's role
  // This allows different parts of the app to react to role changes
  final ValueNotifier<String?> _userRole = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      // Handle different authentication events
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.userUpdated) {
        // 'session' is guaranteed non-null here due to AuthChangeEvent.signedIn/userUpdated
        _fetchUserRole(session!.user.id);
      } else if (event == AuthChangeEvent.signedOut) {
        _userRole.value = null; // Clear role on sign out
      }
    });

    // On initial app start, check if a session exists and fetch role
    _fetchUserRole(supabase.auth.currentUser?.id);
  }

  // Function to fetch the user's role from the profiles table
  Future<void> _fetchUserRole(String? userId) async {
    if (userId == null) {
      _userRole.value = null; // No user, no role
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single(); // Use single() to expect one row

      // If response is received and 'role' is not null
      if (response['role'] != null) {
        _userRole.value = response['role'] as String;
        print('DEBUG: User role fetched: ${_userRole.value}');
      } else {
        // If profile found but 'role' column is null (should ideally not happen with proper registration)
        print('User profile found for ID: $userId, but role is null. Not signing out.');
        _userRole.value = null; // Role is null, so reflect that
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Your profile\'s role could not be loaded. Please ensure your profile is complete.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on PostgrestException catch (e) {
      print('ERROR: PostgrestException during role fetch: ${e.message}');
      _userRole.value = null; // Set null on error
      // IMPORTANT: Removed direct supabase.auth.signOut() here to prevent race condition with registration.
      // The system will eventually redirect to login if role remains null or user attempts restricted actions.
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.message}. Please try refreshing or re-logging.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('ERROR: Unexpected error during role fetch: $e');
      _userRole.value = null; // Set null on error
      // IMPORTANT: Removed direct supabase.auth.signOut() here.
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred loading user data: ${e.toString()}. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: snackbarKey, // Assign the global key for snackbars
      title: 'AutoFix App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Define initial routes. SplashScreen handles initial routing based on auth state.
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(), // User Profile Screen

        // Existing routes:
        '/ai_diagnosis': (context) => const AiDiagnosisScreen(),
        '/mechanic_map': (context) => const VehicleOwnerMapScreen(), // This is the driver's map
        '/offline_guide': (context) => const OfflineGuideScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/terms_conditions': (context) => const TermsConditionsScreen(),
      },
      // Use onGenerateRoute for dynamic routing based on user state
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) {
            return ValueListenableBuilder<String?>(
              valueListenable: _userRole,
              builder: (context, role, child) {
                // If no user is authenticated, always go to login
                if (supabase.auth.currentUser == null) {
                  return const LoginScreen();
                } else {
                  // If user is authenticated but role is still null (loading or error)
                  if (role == null) {
                    // This state should now be very brief, as _fetchUserRole will eventually resolve
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (role == 'driver') {
                    // Navigate to the Vehicle Owner's Map Screen for drivers
                    return const VehicleOwnerMapScreen();
                  } else if (role == 'mechanic') {
                    // Navigate to the Mechanic's Dashboard for mechanics
                    return const MechanicDashboardScreen();
                  } else {
                    // Fallback for unknown roles (shouldn't happen with proper registration)
                    return const Text('Unknown User Role. Please contact support.');
                  }
                }
              },
            );
          });
        }
        // Let other named routes be handled by the routes map
        return null;
      },
    );
  }
}


// NavigationDrawer widget, used across multiple screens for consistent navigation.
class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final bool isLoggedIn = user != null;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero, // Remove default ListView padding
        children: <Widget>[
          // Custom Drawer Header with app branding and user info
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color.fromARGB(233, 214, 251, 250),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30, // Adjust size as needed
                  backgroundColor: Colors.white,
                  child: Icon(
                    isLoggedIn ? Icons.person_rounded : Icons.person_outline,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Removed '!' as 'user' is guaranteed non-null if 'isLoggedIn' is true
                  isLoggedIn ? (user.email ?? 'Logged In User') : 'Guest User', 
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoggedIn) // Removed '&& user.id != null' as it's redundant
                  Text(
                    // Removed '!' as 'user' is guaranteed non-null here due to 'isLoggedIn' check
                    'ID: ${user.id.substring(0, 8)}...', // Display truncated ID for debugging
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Navigation ListTiles for different app sections
          ListTile(
            leading: const Icon(Icons.home, color: Colors.blue),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context); // Close the drawer
              Navigator.pushReplacementNamed(context, '/'); // Go to role-based home
            },
          ),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.blue),
            title: const Text('AI Diagnosis Chatbot'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/ai_diagnosis');
            },
          ),
          ListTile(
            leading: const Icon(Icons.map, color: Colors.blue),
            title: const Text('Mechanic Map'), // This will be the Driver's map
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/mechanic_map'); // Route to VehicleOwnerMapScreen
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.blue),
            title: const Text('Offline Repair Guide'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/offline_guide');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.blue),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/settings');
            },
          ),
          const Divider(color: Colors.blueGrey), // Divider for visual separation

          // Conditional authentication-related navigation
          if (!isLoggedIn) ...[
            ListTile(
              leading: const Icon(Icons.login, color: Colors.blue),
              title: const Text('Login'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            ListTile(
              leading: const Icon(Icons.app_registration, color: Colors.blue),
              title: const Text('Register Account'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/register');
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blue),
              title: const Text('Profile Settings'),
              onTap: () {
                Navigator.pop(context);
                // Use pushNamed here so ProfileScreen can be popped to return to home
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context); // Close the drawer
                await supabase.auth.signOut();
                // After logout, the onAuthStateChange listener will handle redirection to /login
                snackbarKey.currentState?.showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
