// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:autofix/screens/login_screen.dart'; // Import LoginScreen class

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
      // Redirect to login if no user is authenticated
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Fetch the user's profile from the 'profiles' table
      final response = await supabase
          .from('profiles')
          .select('*') // Select all columns for the profile
          .eq('id', user.id) // Filter by the authenticated user's ID
          .single(); // Expect only one row

      setState(() {
        _profileData = response;
        _isLoading = false;
      });
    } on PostgrestException catch (e) {
      print('Error fetching profile: ${e.message}');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to load profile: ${e.message}')),
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Unexpected error fetching profile: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
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
        // Clear navigation stack and go to login screen after logout
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false, // Remove all routes from the stack
        );
      }
    } on AuthException catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.message}')),
      );
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('An unexpected error occurred during logout: ${e.toString()}')),
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
      drawer: const app_nav.NavigationDrawer(), // Attach the NavigationDrawer
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner
          : _profileData == null // If profile data is null after loading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Profile data not found or could not be loaded.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Retry Load Profile', style: TextStyle(color: Colors.white)),
                        onPressed: _fetchProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Logout', style: TextStyle(color: Colors.white)),
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                      // Add more fields here if they are part of the 'profiles' table
                      // For example, if you moved base_rate or service_radius to profiles
                      // _buildProfileField('Service Radius (km)', _profileData!['service_radius_km']?.toString() ?? 'N/A'),
                      // _buildProfileField('Base Rate (₱)', _profileData!['base_rate_php']?.toString() ?? 'N/A'),

                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text('Edit Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                        onPressed: () {
                          // TODO: Implement profile editing logic here.
                          // You would navigate to a new screen or show a dialog
                          // for editing, then refresh this screen after saving.
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
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Logout', style: TextStyle(fontSize: 18, color: Colors.white)),
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  // Helper widget to display a single profile field
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
          const Divider(), // Visual separator
        ],
      ),
    );
  }
}
