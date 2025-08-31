// lib/screens/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:autofix/screens/chat_screen.dart'; // NEW: Import the ChatScreen

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  User? _currentUser;
  String? _currentUserRole; // To store 'driver' or 'mechanic'
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserDataAndChats();
  }

  Future<void> _loadUserDataAndChats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = supabase.auth.currentUser;
      if (_currentUser == null) {
        throw Exception('User is not authenticated.');
      }

      // Fetch the user's role from the profiles table
      final List<Map<String, dynamic>> profileData = await supabase
          .from('profiles')
          .select('role')
          .eq('id', _currentUser!.id)
          .limit(1);

      if (profileData.isEmpty) {
        throw Exception('User profile not found.');
      }
      _currentUserRole = profileData.first['role'] as String?;

      if (_currentUserRole == null) {
        throw Exception('User role not found in profile.');
      }

      // Now fetch chats based on the user's role
      List<Map<String, dynamic>> fetchedChats = [];
      if (_currentUserRole == 'driver') {
        fetchedChats = await supabase
            .from('chats')
            .select('*, mechanic_profile:mechanic_id(full_name)') // Fetch mechanic's name
            .eq('driver_id', _currentUser!.id)
            .order('last_message_at', ascending: false);
      } else if (_currentUserRole == 'mechanic') {
        fetchedChats = await supabase
            .from('chats')
            .select('*, driver_profile:driver_id(full_name)') // Fetch driver's name
            .eq('mechanic_id', _currentUser!.id)
            .order('last_message_at', ascending: false);
      } else {
        throw Exception('Unknown user role: $_currentUserRole');
      }

      if (mounted) {
        setState(() {
          _chats = fetchedChats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load chats: ${e.toString()}';
          _isLoading = false;
        });
      }
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error: ${_errorMessage ?? "Unknown error"}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Chats',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Retry', style: TextStyle(color: Colors.white)),
                        onPressed: _loadUserDataAndChats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : _chats.isEmpty
                  ? const Center(
                      child: Text('No active chats found.', style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                    )
                  : ListView.builder(
                      itemCount: _chats.length,
                      itemBuilder: (context, index) {
                        final chat = _chats[index];
                        String chatPartnerName = 'Unknown User';
                        if (_currentUserRole == 'driver') {
                          // For a driver, the partner is the mechanic
                          chatPartnerName = chat['mechanic_profile']['full_name'] ?? 'Unknown Mechanic';
                        } else if (_currentUserRole == 'mechanic') {
                          // For a mechanic, the partner is the driver
                          chatPartnerName = chat['driver_profile']['full_name'] ?? 'Unknown Driver';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            title: Text(
                              chatPartnerName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('Status: ${chat['status']}'),
                            trailing: Text(
                              _formatDate(chat['last_message_at']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            onTap: () {
                              // Navigate to individual chat screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: chat['id'],
                                    chatPartnerName: chatPartnerName,
                                    currentUserId: _currentUser!.id, // Pass current user ID
                                    chatPartnerId: _currentUserRole == 'driver' ? chat['mechanic_id'] : chat['driver_id'], // Pass partner ID
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement logic to start a new chat, e.g., select a mechanic/driver
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Start new chat functionality coming soon!')),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add_comment, color: Colors.white),
      ),
    );
  }

  String _formatDate(String isoDateString) {
    try {
      final DateTime dateTime = DateTime.parse(isoDateString);
      return '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }
}
