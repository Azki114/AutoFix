import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  // This is needed if you're calling this function from a browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { amount, serviceRequestId, paymentMethod } = await req.json();
    const paymongoSecretKey = Deno.env.get('PAYMONGO_SECRET_KEY');

    if (!paymongoSecretKey) {
      throw new Error("PayMongo secret key is not configured.");
    }
    
    // Use your app's deep link for the redirect URL
    const redirectUrl = `yourapp://payment/callback`; 

    const options = {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': `Basic ${btoa(paymongoSecretKey + ":")}`
      },
      body: JSON.stringify({
        data: {
          attributes: {
            amount: amount,
            redirect: {
              success: `${redirectUrl}?status=success&request_id=${serviceRequestId}`,
              failed: `${redirectUrl}?status=failed&request_id=${serviceRequestId}`
            },
            type: paymentMethod, // 'gcash' or 'maya'
            currency: 'PHP',
            metadata: {
              service_request_id: serviceRequestId,
            }
          }
        }
      })
    };

    const response = await fetch('https://api.paymongo.com/v1/sources', options);
    const responseData = await response.json();

    if (!response.ok) {
        throw new Error(responseData.errors?.[0]?.detail ?? 'Unknown error from PayMongo');
    }

    return new Response(
      JSON.stringify({ checkout_url: responseData.data.attributes.redirect.checkout_url }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
