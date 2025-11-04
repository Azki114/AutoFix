import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:autofix/main.dart'; // For userProfileNotifier

class CallScreen extends StatelessWidget {
  final String callID; // This will be the unique service_request_id or chat_id
  
  const CallScreen({
    super.key,
    required this.callID,
  });

  @override
  Widget build(BuildContext context) {
    // Read the AppID and AppSign from your .env file
    final int appID = int.tryParse(dotenv.env['ZEGO_APP_ID'] ?? '') ?? 0;
    final String appSign = dotenv.env['ZEGO_APP_SIGN'] ?? '';
    
    // Get the current user's ID and Name from your global notifiers
    final String userID = userProfileNotifier.value?.id ?? 'user_id_error';
    final String userName = userProfileNotifier.value?.fullName ?? 'User';

    // This check is important in case the notifiers haven't loaded
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
      
      // Use the default one-on-one voice call config (this API version doesn't expose an `onHangUp` named parameter)..
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
    ); 
  }
}

