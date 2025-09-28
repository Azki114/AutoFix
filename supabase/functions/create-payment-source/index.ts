import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.42.0';
import * as crypto from "https://deno.land/std@0.177.0/crypto/mod.ts";

serve(async (req) => {
  const supabaseAdmin = createClient(
    Deno.env.get('PROJECT_URL')!,
    Deno.env.get('SERVICE_ROLE_KEY')!
  );

  try {
    // 1. Verify the webhook signature to ensure it's from PayMongo
    const signature = req.headers.get('paymongo-signature-v1');
    const requestBody = await req.text(); // Read body as text for signature check
    const webhookSecretKey = Deno.env.get('PAYMONGO_WEBHOOK_SECRET');

    if (!signature || !webhookSecretKey) {
      throw new Error("Webhook signature or secret key is missing.");
    }
    
    // The signature is a comma-separated string: "t=<timestamp>,v1=<signature>"
    const elements = signature.split(',');
    const timestamp = elements.find(e => e.startsWith('t='))?.split('=')[1];
    const signatureHash = elements.find(e => e.startsWith('v1='))?.split('=')[1];

    if (!timestamp || !signatureHash) {
      throw new Error("Invalid signature format.");
    }
    
    const dataToSign = `${timestamp}.${requestBody}`;
    const hmac = await crypto.subtle.importKey(
        "raw",
        new TextEncoder().encode(webhookSecretKey),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["sign"]
    );
    const signedData = await crypto.subtle.sign("HMAC", hmac, new TextEncoder().encode(dataToSign));
    const computedHash = Array.from(new Uint8Array(signedData)).map(b => b.toString(16).padStart(2, '0')).join('');

    if (computedHash !== signatureHash) {
      throw new Error("Webhook signature mismatch. Request is not from PayMongo.");
    }

    // 2. Process the event if signature is valid
    const payload = JSON.parse(requestBody);
    const eventType = payload.data.attributes.type;

    if (eventType === 'source.chargeable') {
      const source = payload.data.attributes.data;
      const serviceRequestId = source.attributes.metadata.service_request_id;
      const amount = source.attributes.amount / 100; // Convert back to pesos
      const paymentMethod = source.attributes.type;
      const gatewayRefId = source.id;

      // 3. Update your database
      // a. Insert a transaction record
      const { error: tranError } = await supabaseAdmin.from('transactions').insert({
        service_request_id: serviceRequestId,
        amount: amount,
        payment_method: paymentMethod,
        status: 'successful',
        gateway_reference_id: gatewayRefId,
      });

      if (tranError) throw tranError;

      // b. Update the service request to 'paid'
      const { error: reqError } = await supabaseAdmin
        .from('service_requests')
        .update({ payment_status: 'paid' })
        .eq('id', serviceRequestId);

      if (reqError) throw reqError;
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error("Webhook processing error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
