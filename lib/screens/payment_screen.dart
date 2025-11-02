import 'package:flutter/material.dart';
import 'package:autofix/main.dart'; // For supabase instance and snackbarKey
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final String serviceRequestId;
  final double amount; // The amount to be paid

  const PaymentScreen({
    super.key,
    required this.serviceRequestId,
    required this.amount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;

  Future<void> _handleCashPayment() async {
    setState(() => _isProcessing = true);
    try {
      // 1. Record the cash transaction
      await supabase.from('transactions').insert({
        'service_request_id': widget.serviceRequestId,
        'amount': widget.amount,
        'payment_method': 'cash',
        'status': 'successful', // Cash is successful immediately
      });

      // 2. Update the service request as paid AND completed
      await supabase
          .from('service_requests')
          .update({
            'payment_status': 'paid',
            'status': 'completed' // <-- THIS IS THE FIX
            })
          .eq('id', widget.serviceRequestId);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Cash payment recorded successfully!'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
          content: Text('Error recording cash payment: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDigitalPayment(String method) async {
    setState(() => _isProcessing = true);
    try {
      // Call the Supabase Edge Function to create a payment source
      final response = await supabase.functions.invoke('create-payment-source',
          body: {
            'amount': (widget.amount * 100).toInt(), // PayMongo requires amount in centavos
            'serviceRequestId': widget.serviceRequestId,
            'paymentMethod': method, // 'gcash' or 'maya'
          });

      if (response.data != null && response.data['checkout_url'] != null) {
        final Uri checkoutUrl = Uri.parse(response.data['checkout_url']);
        if (await canLaunchUrl(checkoutUrl)) {
          // Redirect user to the payment app (GCash/Maya)
          await launchUrl(checkoutUrl, mode: LaunchMode.externalApplication);
          
          // NOTE: The user is now outside your app.
          // The database update for digital payments MUST be handled by your
          // Supabase webhook function ('payment-webhook-handler/index.ts').
          // You do NOT pop or return from this screen until the webhook confirms payment.
          // For now, we will just pop the screen for simplicity.
          if (mounted) {
            Navigator.of(context).pop();
          }

        } else {
          throw 'Could not launch payment URL';
        }
      } else {
        throw response.data?['error'] ?? 'Failed to create payment source.';
      }
    } catch (e) {
      if(mounted){
         snackbarKey.currentState?.showSnackBar(SnackBar(
        content: Text('Payment Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessing
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('Processing your request...'),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Amount Due',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${widget.amount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // --- Payment Options ---
                  ElevatedButton.icon(
                    icon: const Icon(Icons.money),
                    label: const Text('Pay with Cash'),
                    onPressed: _handleCashPayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.phone_android),
                    label: const Text('Pay with GCash'),
                    onPressed: () => _handleDigitalPayment('gcash'),
                     style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Pay with Maya'),
                    onPressed: () => _handleDigitalPayment('maya'),
                     style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}