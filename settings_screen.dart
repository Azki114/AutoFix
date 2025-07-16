// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app; // Import main.dart with a prefix to access NavigationDrawer

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'App Settings and Preferences Here!',
              style: TextStyle(fontSize: 20, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
      drawer: const app.NavigationDrawer(), // Add the drawer here
    );
  }
}