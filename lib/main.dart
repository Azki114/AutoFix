// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv

// --- app's screen imports ---
import 'package:autofix/screens/login_screen.dart';
import 'package:autofix/screens/register_screen.dart';
import 'package:autofix/screens/profile_screen.dart'; // NEW: User Profile Screen
import 'package:autofix/screens/splash_screen.dart'; // NEW: For initial loading/redirection
// Renaming this to VehicleOwnerMapScreen will be handled in its file, but for imports, keep current
import 'package:autofix/screens/mechanic_map_screen.dart'; // This will eventually be the driver's map
import 'package:autofix/screens/mechanic_dashboard_screen.dart'; // NEW: Mechanic's dedicated screen

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
    authFlowType: AuthFlowType.pkce, // Recommended for Flutter apps
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
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedUp) {
        _fetchUserRole(session?.user?.id); // Fetch role when user signs in/up
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

      if (response != null && response['role'] != null) {
        _userRole.value = response['role'] as String;
      } else {
        _userRole.value = null; // Profile found but no role, or no profile.
        // This might happen if profiles table insert failed after auth.signUp
        // Consider prompting the user to complete their profile or re-register.
        print('User profile or role not found for user ID: $userId');
      }
    } catch (e) {
      print('Error fetching user role: $e');
      _userRole.value = null; // Set null on error
      // Show a general error message if profile data can't be fetched
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.toString()}'),
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
        '/mechanic_map': (context) => const MechanicMapScreen(), // Will be driver's map
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
                if (supabase.auth.currentUser == null) {
                  // If not logged in, go to login screen
                  return const LoginScreen();
                } else {
                  // If logged in, but role is still null (fetching or not found), show loading or a generic screen
                  if (role == null) {
                    return const Scaffold(
                      body: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (role == 'driver') {
                    // Navigate to the Vehicle Owner's Map Screen for drivers
                    return const MechanicMapScreen(); // Renamed to VehicleOwnerMapScreen in its file
                  } else if (role == 'mechanic') {
                    // Navigate to the Mechanic's Dashboard for mechanics
                    return const MechanicDashboardScreen();
                  } else {
                    // Fallback for unknown roles (shouldn't happen with proper setup)
                    return const Text('Unknown User Role');
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


// --- Placeholder Screens (will be implemented in separate files) ---

// lib/screens/splash_screen.dart
// A simple splash screen to determine initial routing
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
    await Future.delayed(Duration.zero); // Allow widget to build
    if (!mounted) {
      return;
    }
    final session = supabase.auth.currentSession;
    if (session == null) {
      // No session, go to login
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Session exists, go to the main app route which handles role-based redirection
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// lib/screens/profile_screen.dart (Initial Placeholder)
// This screen will display user profile and include a logout button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('No authenticated user found.')),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('*') // Select all columns for the profile
          .eq('id', user.id)
          .single();

      setState(() {
        _profileData = response;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching profile: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to load profile data: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        // Clear navigation stack and go to login
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const NavigationDrawer(), // Attach the NavigationDrawer
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Profile data not found.'),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchProfile,
                        child: const Text('Retry Load Profile'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.blue,
                          child: Icon(
                            _profileData!['role'] == 'driver' ? Icons.directions_car : Icons.build,
                            size: 70,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildProfileField('Full Name', _profileData!['full_name'] ?? 'N/A'),
                      _buildProfileField('Email', _profileData!['email'] ?? 'N/A'),
                      _buildProfileField('Phone Number', _profileData!['phone_number'] ?? 'N/A'),
                      _buildProfileField('Role', _profileData!['role'] ?? 'N/A'),
                      // Add more profile fields as needed
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Implement profile editing logic here
                          snackbarKey.currentState?.showSnackBar(
                            const SnackBar(content: Text('Edit Profile functionality coming soon!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Edit Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Logout', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
          ),
          const Divider(),
        ],
      ),
    );
  }
}

// lib/screens/vehicle_owner_map_screen.dart (Initial Placeholder)
// This will be the main screen for vehicle owners showing mechanics on a map.
class VehicleOwnerMapScreen extends StatelessWidget {
  const VehicleOwnerMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanics Near You',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const NavigationDrawer(), // Attach the NavigationDrawer
      body: const Center(
        child: Text(
          'Map with Mechanic Locations will go here for Vehicle Owners!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.blueGrey),
        ),
      ),
    );
  }
}

// lib/screens/mechanic_dashboard_screen.dart (Initial Placeholder)
// This will be the main screen for mechanics.
class MechanicDashboardScreen extends StatelessWidget {
  const MechanicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const NavigationDrawer(), // Attach the NavigationDrawer
      body: const Center(
        child: Text(
          'Welcome, Mechanic! Your dashboard will be here.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.blueGrey),
        ),
      ),
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
                  isLoggedIn ? (user?.email ?? 'Logged In User') : 'Guest User',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isLoggedIn && user?.id != null)
                  Text(
                    'ID: ${user!.id.substring(0, 8)}...', // Display truncated ID for debugging
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
            title: const Text('Mechanic Map'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/mechanic_map');
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
            // The logout button is primarily on the Profile screen, but can be added here too.
            // ListTile(
            //   leading: const Icon(Icons.logout, color: Colors.blue),
            //   title: const Text('Logout'),
            //   onTap: () async {
            //     try {
            //       await supabase.auth.signOut();
            //       if (context.mounted) {
            //         Navigator.pushAndRemoveUntil(
            //           context,
            //           MaterialPageRoute(builder: (context) => const LoginScreen()),
            //           (Route<dynamic> route) => false,
            //         );
            //       }
            //     } catch (e) {
            //       snackbarKey.currentState?.showSnackBar(
            //         SnackBar(content: Text('Error logging out: ${e.toString()}')),
            //       );
            //     }
            //   },
            // ),
          ],
        ],
      ),
    );
  }
}
