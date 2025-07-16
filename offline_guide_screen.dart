// lib/screens/offline_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as myapp; // Import main.dart with a prefix

class OfflineGuideScreen extends StatelessWidget {
  const OfflineGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Guide',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 80, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Offline Repair Guides & Manuals Here!',
              style: TextStyle(fontSize: 20, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
      drawer: const myapp.NavigationDrawer(), // Add the drawer here
    );
  }
}