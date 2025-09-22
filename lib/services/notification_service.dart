import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> initialize() async {
    // Request permission from the user to receive notifications
    await _fcm.requestPermission();

    // Get the unique FCM token for this device
    final String? fcmToken = await _fcm.getToken();
    debugPrint("---------- FCM Token: $fcmToken ----------");
    
    // Save the token to the user's profile
    if (fcmToken != null) {
      await saveTokenToDatabase(fcmToken);
    }
    
    // Listen for token refreshes and save the new token
    _fcm.onTokenRefresh.listen(saveTokenToDatabase);

    // TODO: Add handlers for when a notification is received
  }

  Future<void> saveTokenToDatabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint("Successfully saved FCM token to Supabase.");
    } catch (e) {
      debugPrint("Error saving FCM token: $e");
    }
  }
}