// @deno-types="https://esm.sh/v135/@supabase/functions-js@2.4.1/src/edge-runtime.d.ts"

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.42.0';
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9.9.0';

// Define the structure of the incoming webhook payload from Supabase
interface ServiceRequest {
  id: string;
  status: string;
  requester_id: string;
  mechanic_id: string | null;
  cancelled_by: string | null;
}

// Define the structure for the FCM v1 API payload
interface FcmPayload {
  message: {
    token: string;
    notification: {
      title: string;
      body: string;
    };
    data?: { [key: string]: string };
  };
}

serve(async (req: Request) => { // Added type 'Request' to req parameter
  try {
    const payload: { record: ServiceRequest; old_record: ServiceRequest } = await req.json();
    const { record: updatedRequest, old_record: oldRequest } = payload;

    // --- Core Logic: Only act on a cancellation ---
    if (updatedRequest.status !== 'cancelled' || oldRequest.status === 'cancelled') {
      return new Response(JSON.stringify({ message: "Not a cancellation event or already processed." }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // Determine who cancelled and who needs to be notified
    const cancellerId = updatedRequest.cancelled_by;
    let recipientId: string | null = null;
    
    // If the requester cancelled, notify the mechanic.
    if (cancellerId === updatedRequest.requester_id && updatedRequest.mechanic_id) {
      recipientId = updatedRequest.mechanic_id;
    } 
    // If the mechanic cancelled, notify the requester.
    else if (cancellerId === updatedRequest.mechanic_id) {
      recipientId = updatedRequest.requester_id;
    }

    if (!recipientId) {
      return new Response(JSON.stringify({ message: "No recipient found for notification." }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // --- Supabase and FCM Setup ---
    const supabaseAdmin = createClient(
      Deno.env.get('PROJECT_URL')!,
      Deno.env.get('SERVICE_ROLE_KEY')!
    );

    const serviceAccountJson = Deno.env.get('FCM_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      throw new Error("FCM service account JSON is not set in Supabase secrets.");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);

    // --- Fetch Recipient's FCM Token ---
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('fcm_token')
      .eq('id', recipientId)
      .single();

    if (profileError || !profile || !profile.fcm_token) {
      throw new Error(`Could not find FCM token for user ${recipientId}. Error: ${profileError?.message}`);
    }

    const fcmToken = profile.fcm_token;

    // --- Authenticate with Google and Get Access Token ---
    const auth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });

    const accessToken = await auth.getAccessToken();

    // --- Send the Notification using FCM v1 API ---
    const fcmApiUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    const notificationPayload: FcmPayload = {
      message: {
        token: fcmToken,
        notification: {
          title: 'Service Request Cancelled',
          body: 'Your service request has been cancelled. Please check the app for details.',
        },
        data: {
          requestId: updatedRequest.id,
        },
      },
    };

    const response = await fetch(fcmApiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify(notificationPayload),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(`FCM request failed with status ${response.status}: ${errorBody}`);
    }

    return new Response(JSON.stringify({ message: "Notification sent successfully." }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error("Error processing notification:", error);
    // Safely handle the error type
    const errorMessage = error instanceof Error ? error.message : "An unknown error occurred.";
    return new Response(JSON.stringify({ error: errorMessage }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

