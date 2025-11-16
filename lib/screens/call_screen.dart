// lib/call_screen.dart
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:autofix/main.dart'; // For userProfileNotifier

class CallScreen extends StatelessWidget {
  final String callID; // unique service_request_id or chat_id

  const CallScreen({
    super.key,
    required this.callID,
  });

  @override
  Widget build(BuildContext context) {
    // Read AppID and AppSign from your .env
    final int appID = int.tryParse(dotenv.env['ZEGO_APP_ID'] ?? '') ?? 0;
    final String appSign = dotenv.env['ZEGO_APP_SIGN'] ?? '';

    // Read current user info
    final String userID = userProfileNotifier.value?.id ?? 'user_id_error';
    final String userName = userProfileNotifier.value?.fullName ?? 'User';

    // Basic validation
    if (appID == 0 || appSign.isEmpty || userID == 'user_id_error') {
      return const Scaffold(
        body: Center(
          child: Text('Error: Call service not configured. Please restart.'),
        ),
      );
    }

    return ZegoUIKitPrebuiltCall(
      appID: appID,
      appSign: appSign,
      userID: userID,
      userName: userName,
      callID: callID,

      // Default one-on-one voice call configuration
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),

      // IMPORTANT: use the `events` parameter (not the config)
      // onCallEnd receives (ZegoCallEndEvent event, VoidCallback defaultAction)
      // The SDK's default behavior is to call defaultAction() to pop the page.
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
          // Optional: inspect event.reason or event.kickerUserID if needed
          debugPrint('Call ended. reason=${event.reason}, kicker=${event.kickerUserID}');

          // Perform any cleanup or logging here BEFORE navigation...
          // e.g. stop local recording, notify backend, etc.

          // Call the SDK's default action to return to previous page.
          // (If you omit this, the prebuilt page WILL NOT navigate away.)
          defaultAction.call();
        },
      ),
    );
  }
}
