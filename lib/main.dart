// lib/main.dart
import 'dart:async'; // Import for StreamSubscription

import 'package:autofix/screens/service_history_screen.dart'; // <-- IMPORT THE NEW SCREEN
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

// NEW: Create a global key for the Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


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
  final ValueNotifier<String?> _userRole = ValueNotifier<String?>(null);
  StreamSubscription? _requestStreamSubscription;
  StreamSubscription<AuthState>? _authSubscription;


  @override
  void initState() {
    super.initState();
    // REFACTORED: Use a single, reliable listener for all auth changes.
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      if (session == null) {
        _userRole.value = null;
        _stopListeningForRequests();
        // Use the global navigatorKey to navigate reliably without a context.
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        // When a user signs in or the initial session is loaded, fetch their role.
        _fetchUserRole(session.user.id);
      }
    });
  }
  
  @override
  void dispose() {
    _userRole.dispose();
    _authSubscription?.cancel();
    _requestStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole(String? userId) async {
    if (userId == null) {
      _userRole.value = null;
      _stopListeningForRequests();
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      if (response['role'] != null) {
        final role = response['role'] as String;
        _userRole.value = role;
        
        if (role == 'mechanic') {
          _listenForNewServiceRequests();
        } else {
          _stopListeningForRequests();
        }

      } else {
        _userRole.value = null;
        _stopListeningForRequests();
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Your profile\'s role could not be loaded. Please ensure your profile is complete.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      _userRole.value = null;
      _stopListeningForRequests();
      if(mounted){
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('An error occurred loading user data: ${e.toString()}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenForNewServiceRequests() {
    _requestStreamSubscription?.cancel();
    
    _requestStreamSubscription = supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .listen((data) {
      if (data.isNotEmpty) {
        debugPrint("New service request detected!");
        requestNotifier.show();
      }
    }, onError: (error) {
        debugPrint("Error listening to service requests: $error");
    });
  }

  void _stopListeningForRequests() {
    _requestStreamSubscription?.cancel();
    _requestStreamSubscription = null;
    requestNotifier.hide();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: snackbarKey,
      navigatorKey: navigatorKey, // Assign the global key for navigation
      title: 'AutoFix App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/ai_diagnosis': (context) => const AiDiagnosisScreen(),
        '/vehicle_owner_map': (context) => const VehicleOwnerMapScreen(),
        '/offline_guide': (context) => const OfflineGuideScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/terms_conditions': (context) => const TermsConditionsScreen(),
        '/chat_list': (context) => const ChatListScreen(),
        '/account': (context) => const AccountScreen(),
        '/mechanic_dashboard': (context) => const MechanicServiceRequestsScreen(),
        '/service_history': (context) => const ServiceHistoryScreen(), // <-- NEW ROUTE ADDED
      },
      home: const SplashScreen(), // Let SplashScreen handle initial auth check and redirect
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final bool isLoggedIn = user != null;

    final myAppState = context.findAncestorStateOfType<_MyAppState>();

    return ValueListenableBuilder<String?>(
      valueListenable: myAppState?._userRole ?? ValueNotifier<String?>(null),
      builder: (context, currentRole, child) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(233, 214, 251, 250),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 30,
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
                        'ID: ${user.id.substring(0, 8)}...',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.blue),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  if (currentRole == 'driver') {
                    Navigator.pushReplacementNamed(context, '/vehicle_owner_map');
                  } else if (currentRole == 'mechanic') {
                    Navigator.pushReplacementNamed(context, '/mechanic_dashboard');
                  } else {
                    Navigator.pushReplacementNamed(context, '/splash');
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
              // Conditional items based on role
              if (currentRole == 'driver') ...[
                 ListTile(
                  leading: const Icon(Icons.map, color: Colors.blue),
                  title: const Text('Find Mechanics'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/vehicle_owner_map');
                  },
                ),
                 ListTile( // <-- NEW NAVIGATION ITEM ADDED
                  leading: const Icon(Icons.history, color: Colors.blue),
                  title: const Text('Service History'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/service_history');
                  },
                ),
              ],
               if (currentRole == 'mechanic')
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
              const Divider(color: Colors.blueGrey),
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
                    Navigator.pop(context);
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

