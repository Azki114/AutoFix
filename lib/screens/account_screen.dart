// lib/screens/account_screen.dart

import 'package:autofix/widgets/avatar.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase instance and snackbarKey

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController(); // Added for username
  final _newPasswordController = TextEditingController();

  String? _avatarUrl;
  bool _notificationsEnabled = true;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _getProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _getProfile() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      // Fetch all necessary fields. Add columns in Supabase if they don't exist.
      final data = await supabase.from('profiles') // The method 'PostgrestFilterBuilder<PostgrestList> Function([String])' is declared with 0 type parameters, but 1 type arguments are given.Try adjusting the number of type arguments.
          .select('full_name, username, avatar_url, notifications_enabled')
          .eq('id', userId)
          .single();

      _fullNameController.text = (data['full_name'] ?? '') as String;
      _usernameController.text = (data['username'] ?? '') as String;
      _avatarUrl = (data['avatar_url']) as String?;
      _notificationsEnabled = (data['notifications_enabled'] ?? true) as bool;

    } on PostgrestException catch (error) {
      _showErrorSnackBar(error.message);
    } catch (error) {
      _showErrorSnackBar('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _loading = true);
    final updates = {
      'id': supabase.auth.currentUser!.id,
      'full_name': _fullNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    try {
      await supabase.from('profiles').upsert(updates);
      _showSuccessSnackBar('Profile updated successfully!');
    } on PostgrestException catch (error) {
      _showErrorSnackBar(error.message);
    } catch (error) {
      _showErrorSnackBar('An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateNotificationSettings(bool value) async {
    setState(() => _notificationsEnabled = value);
    try {
      await supabase.from('profiles').update({
        'notifications_enabled': value,
      }).eq('id', supabase.auth.currentUser!.id);
      _showSuccessSnackBar('Notification settings updated.');
    } catch (e) {
      _showErrorSnackBar('Failed to update settings.');
      if (mounted) setState(() => _notificationsEnabled = !value); // Revert on failure
    }
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty) {
      _showErrorSnackBar('Password cannot be empty.');
      return;
    }
    setState(() => _loading = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
      _newPasswordController.clear();
      Navigator.of(context).pop(); // Close the dialog
      _showSuccessSnackBar('Password updated successfully.');
    } catch (e) {
      _showErrorSnackBar('Failed to update password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await supabase.functions.invoke('delete-user');
      // The auth listener in main.dart will handle navigation after sign out.
    } catch (e) {
      _showErrorSnackBar('Failed to delete account: ${e.toString()}');
    }
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: _changePassword, child: const Text('Save')),
        ],
      ),
    );
  }
  
  void _showDeleteConfirmationDialog() {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is irreversible. All your data will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    snackbarKey.currentState
        ?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showErrorSnackBar(String message) {
    snackbarKey.currentState
        ?.showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              children: [
                Avatar(
                  imageUrl: _avatarUrl,
                  onUpload: (imageUrl) async {
                    setState(() => _avatarUrl = imageUrl);
                    await supabase.from('profiles').upsert({'id': supabase.auth.currentUser!.id, 'avatar_url': imageUrl});
                    _showSuccessSnackBar('Avatar updated!');
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _updateProfile,
                  child: Text(_loading ? 'Saving...' : 'Update Profile'),
                ),
                const Divider(height: 40),
                const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                SwitchListTile.adaptive(
                  title: const Text('Enable Push Notifications'),
                  value: _notificationsEnabled,
                  onChanged: _updateNotificationSettings,
                ),
                const Divider(height: 20),
                const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  onTap: _showPasswordDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () async => await supabase.auth.signOut(),
                ),
                const Divider(height: 40),
                const Text('Danger Zone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                  onTap: _showDeleteConfirmationDialog,
                ),
              ],
            ),
    );
  }
}