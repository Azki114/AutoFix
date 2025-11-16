// lib/main.dart
import 'dart:async'; // Import for StreamSubscription

import 'package:autofix/screens/account_screen.dart';
import 'package:autofix/screens/ai_diagnosis_screen.dart';
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/login_screen.dart';
import 'package:autofix/screens/mechanic_dashboard_screen.dart';
import 'package:autofix/screens/mechanic_service_requests_screen.dart';
import 'package:autofix/screens/offline_guide_screen.dart';
import 'package:autofix/screens/profile_screen.dart';
import 'package:autofix/screens/register_screen.dart';
import 'package:autofix/screens/service_history_screen.dart';
import 'package:autofix/screens/settings_screen.dart';
import 'package:autofix/screens/splash_screen.dart';
import 'package:autofix/screens/terms_conditions_screen.dart';
import 'package:autofix/screens/vehicle_owner_map_screen.dart';
import 'package:autofix/services/notification_service.dart';
import 'package:autofix/services/request_notifier.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/screens/reset_password_screen.dart';
import 'package:autofix/screens/pending_verification_screen.dart';

class UserProfile {
  final String id;
  final String? fullName;
  final String? avatarUrl;

  UserProfile({required this.id, this.fullName, this.avatarUrl});
}

// Global Supabase client instance
late final SupabaseClient supabase;
final GlobalKey<ScaffoldMessengerState> snackbarKey =
    GlobalKey<ScaffoldMessengerState>();
final RequestNotifier requestNotifier = RequestNotifier();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<String?> userRole = ValueNotifier<String?>(null);

final ValueNotifier<UserProfile?> userProfileNotifier =
    ValueNotifier<UserProfile?>(null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final String? supabaseUrl = dotenv.env['SUPABASE_URL'];
  final String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    throw Exception('Supabase environment variables are missing.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  supabase =
      Supabase.instance.client;

  await Firebase.initializeApp();
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription? _requestStreamSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      final Session? session = data.session;
      final AuthChangeEvent event = data.event; 

      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/reset-password', (route) => false);
      } else if (session == null) {
        userRole.value = null;
        userProfileNotifier.value = null; 
        _stopListeningForRequests();

        // Zego uninit removed

        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (event == AuthChangeEvent.signedIn) {
        // This is a new sign-up OR login.
        // Add a small delay to win the race condition against the register screen.
        Future.delayed(const Duration(milliseconds: 1000), () {
          // Check if user is still logged in after the delay, just in case
          if (supabase.auth.currentUser != null) {
            _fetchUserData(session.user.id);
          }
        });
      } else if (event == AuthChangeEvent.initialSession) {
         // App is starting, user is already logged in. No delay needed.
        _fetchUserData(session.user.id);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _requestStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData(String? userId) async {
    if (userId == null) {
      userRole.value = null;
      userProfileNotifier.value = null;
      _stopListeningForRequests();
      return;
    }
    try {
      final response = await supabase
          .from('profiles')
          .select('role, full_name, avatar_url, is_verified')
          .eq('id', userId)
          .maybeSingle(); 

      if (response == null) {
        // This means the profile is still being created (the 1-sec delay wasn't enough).
        // Log them out and ask them to log in again.
        await supabase.auth.signOut();
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('Registration is processing. Please log in.'),
            backgroundColor: Colors.orange,
          ),
        );
        return; // Stop here.
      }
      
      userProfileNotifier.value = UserProfile(
        id: userId,
        fullName: response['full_name'],
        avatarUrl: response['avatar_url'],
      );

      final bool isVerified = response['is_verified'] ?? false;
      
      if (!isVerified) {
        // User is logged in BUT NOT VERIFIED. Send them to the "Holding Room".
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/pending-verification', (route) => false);
        return; // Stop here. Do not proceed.
      }
      
      // Zego init() block removed from here
      
      if (response['role'] != null) {
        final role = response['role'] as String;
        userRole.value = role;
        if (role == 'mechanic') {
          _listenForNewServiceRequests(userId);
        } else {
          _stopListeningForRequests();
        }

        if (role == 'driver') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/vehicle_owner_map', (route) => false);
        } else if (role == 'mechanic') {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/mechanic_dashboard', (route) => false);
        } else {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        }

      } else {
        userRole.value = null;
        _stopListeningForRequests();
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text(
                'Your profile\'s role could not be loaded. Please ensure your profile is complete.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      userRole.value = null;
      userProfileNotifier.value = null;
      _stopListeningForRequests();
      if (mounted) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _listenForNewServiceRequests(String userId) {
    _requestStreamSubscription?.cancel();
    _requestStreamSubscription = supabase
        .from('service_requests')
        .stream(primaryKey: ['id']) 
        .listen((data) {
      
      final myPendingRequests = data.where((req) => 
          req['status'] == 'pending' && 
          req['mechanic_id'] == userId
      ).toList();

      if (myPendingRequests.isNotEmpty) {
        debugPrint("New service request detected for this mechanic!");
        requestNotifier.show();
      } else {
        requestNotifier.hide();
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
      navigatorKey: navigatorKey,
      title: 'AutoFix App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // --- Zego Builder has been REMOVED ---
      
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
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
        '/mechanic_dashboard': (context) => const MechanicDashboardScreen(),
        '/mechanic_service_requests': (context) =>
            const MechanicServiceRequestsScreen(),
        '/service_history': (context) => const ServiceHistoryScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/pending-verification': (context) => const PendingVerificationScreen(),
      },
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final bool isLoggedIn = user != null;

    return ValueListenableBuilder<String?>(
      valueListenable: userRole,
      builder: (context, currentRole, child) {
        return ValueListenableBuilder<UserProfile?>(
          valueListenable: userProfileNotifier,
          builder: (context, profile, child) {
            return Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  DrawerHeader(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: const AssetImage('assets/drawer_background.png'), 
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: (profile?.avatarUrl != null &&
                                  profile!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: (profile?.avatarUrl == null ||
                                  profile!.avatarUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.blue)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLoggedIn
                              ? (profile?.fullName ?? user.email ?? 'User')
                              : 'Guest User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: <Shadow>[
                              Shadow(
                                offset: Offset(1.0, 1.0),
                                blurRadius: 3.0,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ],
                          ),
                        ),
                        if (isLoggedIn)
                          Text(
                            'ID: ${user.id.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              shadows: <Shadow>[
                                Shadow(
                                  offset: Offset(1.0, 1.0),
                                  blurRadius: 3.0,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ],
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
                        Navigator.pushReplacementNamed(
                            context, '/vehicle_owner_map');
                      } else if (currentRole == 'mechanic') {
                        Navigator.pushReplacementNamed(
                            context, '/mechanic_dashboard');
                      } else {
                        // This case handles unverified users
                        Navigator.pushReplacementNamed(context, '/splash');
                      }
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.support_agent, color: Colors.blue),
                    title: const Text('AI Diagnosis Chatbot'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/ai_diagnosis');
                    },
                  ),
                  if (currentRole == 'driver') ...[
                    ListTile(
                      leading: const Icon(Icons.map, color: Colors.blue),
                      title: const Text('Find Mechanics'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                            context, '/vehicle_owner_map');
                      },
                    ),
                    ListTile(
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
                          leading:
                              const Icon(Icons.dashboard, color: Colors.blue),
                          title: const Text('Service Requests'),
                          trailing: hasNewRequest
                              ? const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.red,
                                  child: Text('!',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold)),
                                )
                              : null,
                          onTap: () {
                            requestNotifier.hide();
                            Navigator.pop(context);
                            Navigator.pushNamed(
                                context, '/mechanic_service_requests');
                          },
                        );
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.menu_book, color: Colors.blue),
                    title: const Text('Offline Repair Guide'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                          context, '/offline_guide');
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
                    leading:
                        const Icon(Icons.assignment, color: Colors.blue),
                    title: const Text('Terms & Conditions'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(
                          context, '/terms_conditions');
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
                      leading: const Icon(Icons.app_registration,
                          color: Colors.blue),
                      title: const Text('Register Account'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(
                            context, '/register');
                      },
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue),
                      title: const Text('Profile'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/profile');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.account_circle,
                          color: Colors.blue),
                      title: const Text('Account Settings'),
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

                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (route) => false);

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
      },
    );
  }
}