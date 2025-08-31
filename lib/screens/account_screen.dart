// lib/screens/account_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _avatarUrlController = TextEditingController(); // For avatar URL input
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentAvatarUrl; // To hold the current avatar URL for display

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  // Fetches the user's profile from Supabase
  Future<void> _fetchProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw 'User is not logged in.';
      }

      // Fetch the profile data for the current user
      final data = await supabase
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _fullNameController.text = data['full_name'] ?? '';
          _avatarUrlController.text = data['avatar_url'] ?? '';
          _currentAvatarUrl = data['avatar_url']; // Store for display
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Database error: ${e.message}';
          _isLoading = false;
        });
      }
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
          _isLoading = false;
        });
      }
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // Updates the user's profile in Supabase
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw 'User is not logged in.';
      }

      final newFullName = _fullNameController.text.trim();
      final newAvatarUrl = _avatarUrlController.text.trim();

      await supabase.from('profiles').update({
        'full_name': newFullName,
        'avatar_url': newAvatarUrl.isEmpty ? null : newAvatarUrl, // Set to null if empty
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _currentAvatarUrl = newAvatarUrl.isEmpty ? null : newAvatarUrl;
          _isLoading = false;
        });
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Database error: ${e.message}';
          _isLoading = false;
        });
      }
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: ${e.toString()}';
          _isLoading = false;
        });
      }
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  // Handles user logout
  Future<void> _signOut() async {
    if (!mounted) return;
    try {
      await supabase.auth.signOut();
      if (mounted) {
        // Navigate to the login screen and remove all previous routes
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You have been logged out.')),
        );
      }
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to sign out: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text('Retry', style: TextStyle(color: Colors.white)),
                onPressed: _fetchProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Display
              GestureDetector(
                onTap: () {
                  // In a real app, this would trigger an image picker
                  snackbarKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Tap to change avatar (manual URL input below).')),
                  );
                },
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: _currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty
                      ? NetworkImage(_currentAvatarUrl!)
                      : null,
                  child: (_currentAvatarUrl == null || _currentAvatarUrl!.isEmpty)
                      ? Icon(Icons.person, size: 60, color: Colors.blue.shade800)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // Full Name Input
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Avatar URL Input
              TextFormField(
                controller: _avatarUrlController,
                decoration: const InputDecoration(
                  labelText: 'Avatar URL',
                  hintText: 'Paste an image URL for your avatar (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateProfile,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Log Out', style: TextStyle(fontSize: 18, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
