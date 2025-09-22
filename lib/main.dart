// lib/main.dart
import 'dart:async'; // Import for StreamSubscription

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core

// --- App's screen imports ---
import 'package:autofix/screens/login_screen.dart';
import 'package:autofix/screens/register_screen.dart';
import 'package:autofix/screens/profile_screen.dart'; // User Profile Screen
import 'package:autofix/screens/splash_screen.dart'; // For initial loading/redirection
import 'package:autofix/screens/vehicle_owner_map_screen.dart'; // Driver's map
import 'package:autofix/screens/mechanic_service_requests_screen.dart'; // MECHANIC'S NEW DEDICATED SCREEN
import 'package:autofix/screens/chat_list_screen.dart'; // Import the new ChatListScreen

// --- Existing app screens ---
import 'package:autofix/screens/ai_diagnosis_screen.dart';
import 'package:autofix/screens/offline_guide_screen.dart';
import 'package:autofix/screens/settings_screen.dart';
import 'package:autofix/screens/terms_conditions_screen.dart';
import 'package:autofix/screens/account_screen.dart'; // Account screen from previous update

// --- App Services ---
import 'package:autofix/services/notification_service.dart';
import 'package:autofix/services/request_notifier.dart';


// Global Supabase client instance
late final SupabaseClient supabase;

// Define a global key for the Scaffold Messenger to show SnackBars from anywhere
final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();

// Create a single, globally accessible instance of the notifier
final RequestNotifier requestNotifier = RequestNotifier();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for async initialization

  // Load environment variables from the .env file.
  await dotenv.load(fileName: ".env");

  // Retrieve Supabase URL and Anon Key from environment variables.
  final String? supabaseUrl = dotenv.env['SUPABASE_URL'];
  final String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Check if the Supabase environment variables were successfully loaded.
  if (supabaseUrl == null || supabaseUrl.isEmpty || supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('Supabase environment variables are missing.');
  }

  // Initialize the Supabase client.
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  supabase = Supabase.instance.client; // Get the client instance after initialization

  // Initialize Firebase for push notifications
  await Firebase.initializeApp();
  // Initialize the notification service to handle FCM tokens and messages
  await NotificationService().initialize();


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
  StreamSubscription? _requestStreamSubscription;


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
        _stopListeningForRequests(); // Stop listening when user logs out
        // When signed out, automatically redirect to login if not already there
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } else if (event == AuthChangeEvent.initialSession) {
        // Handle initial session to set role if already logged in
        if (session != null) {
          _fetchUserRole(session.user.id);
        } else {
          _userRole.value = null;
        }
      }
    });

    if (supabase.auth.currentUser != null) {
      _fetchUserRole(supabase.auth.currentUser?.id);
    }
  }
  
  @override
  void dispose() {
    _userRole.dispose();
    _stopListeningForRequests();
    super.dispose();
  }


  // Function to fetch the user's role from the profiles table
  Future<void> _fetchUserRole(String? userId) async {
    if (userId == null) {
      _userRole.value = null; // No user, no role
      _stopListeningForRequests();
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single(); // Use single() to expect one row

      if (response['role'] != null) {
        final role = response['role'] as String;
        _userRole.value = role;
        
        // If the user is a mechanic, start listening for new service requests.
        if (role == 'mechanic') {
          _listenForNewServiceRequests();
        } else {
          _stopListeningForRequests(); // Ensure non-mechanics are not listening.
        }

      } else {
        _userRole.value = null; // Role is null, so reflect that
        _stopListeningForRequests();
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Your profile\'s role could not be loaded. Please ensure your profile is complete.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on PostgrestException catch (e) {
      _userRole.value = null; // Set null on error
      _stopListeningForRequests();
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('Error loading user data: ${e.message}. Please try refreshing or re-logging.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      _userRole.value = null; // Set null on error
      _stopListeningForRequests();
      snackbarKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred loading user data: ${e.toString()}. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to listen for new service requests for mechanics
  void _listenForNewServiceRequests() {
    // Cancel any existing subscription to prevent duplicates
    _requestStreamSubscription?.cancel();
    
    _requestStreamSubscription = supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending') // Only listen for new pending requests
        .listen((data) {
      if (data.isNotEmpty) {
        // A new request has appeared. Show the notification badge.
        debugPrint("New service request detected!");
        requestNotifier.show();
      }
    }, onError: (error) {
        debugPrint("Error listening to service requests: $error");
    });
  }

  // Function to stop the real-time listener
  void _stopListeningForRequests() {
    _requestStreamSubscription?.cancel();
    _requestStreamSubscription = null;
    requestNotifier.hide(); // Hide badge when not listening
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
        '/vehicle_owner_map': (context) => const VehicleOwnerMapScreen(), // Driver's map
        '/offline_guide': (context) => const OfflineGuideScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/terms_conditions': (context) => const TermsConditionsScreen(),
        '/chat_list': (context) => const ChatListScreen(), // Add the new chat list route
        '/account': (context) => const AccountScreen(), // Add account screen route
        '/mechanic_dashboard': (context) => const MechanicServiceRequestsScreen(), // NEW: Mechanic's Requests Screen
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
                    return const MechanicServiceRequestsScreen(); // Correctly redirect to mechanic's screen
                  } else {
                    // Fallback for unknown roles (shouldn't happen with proper registration)
                    return const Scaffold(body: Center(child: Text('Unknown User Role. Please contact support.')));
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

    // Use a ValueListenableBuilder to react to role changes and update drawer dynamically
    return ValueListenableBuilder<String?>(
      valueListenable: (context.findAncestorStateOfType<_MyAppState>()?._userRole ?? ValueNotifier<String?>(null)),
      builder: (context, currentRole, child) {
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
                      isLoggedIn ? (user.email ?? 'Logged In User') : 'Guest User',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isLoggedIn)
                      Text(
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
                  if (currentRole == 'driver') {
                    Navigator.pushReplacementNamed(context, '/vehicle_owner_map');
                  } else if (currentRole == 'mechanic') {
                    Navigator.pushReplacementNamed(context, '/mechanic_dashboard');
                  } else {
                    Navigator.pushReplacementNamed(context, '/'); // This will hit onGenerateRoute
                  }
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
              // Conditional Map/Dashboard item based on role
              if (currentRole == 'driver')
                ListTile(
                  leading: const Icon(Icons.map, color: Colors.blue),
                  title: const Text('Find Mechanics'), // Driver's map to find mechanics
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/vehicle_owner_map');
                  },
                )
              else if (currentRole == 'mechanic')
                ValueListenableBuilder<bool>(
                  valueListenable: requestNotifier,
                  builder: (context, hasNewRequest, child) {
                    return ListTile(
                      leading: const Icon(Icons.dashboard, color: Colors.blue),
                      title: const Text('Service Requests'),
                      trailing: hasNewRequest
                          ? const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Text('!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            )
                          : null,
                      onTap: () {
                        requestNotifier.hide();
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/mechanic_dashboard');
                      },
                    );
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
                leading: const Icon(Icons.chat, color: Colors.blue),
                title: const Text('Chats'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/chat_list');
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
              ListTile(
                leading: const Icon(Icons.assignment, color: Colors.blue),
                title: const Text('Terms & Conditions'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/terms_conditions');
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
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle, color: Colors.blue),
                  title: const Text('Account Details'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/account');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.pop(context); // Close the drawer
                    await supabase.auth.signOut();
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
      },
    );
  }
}

