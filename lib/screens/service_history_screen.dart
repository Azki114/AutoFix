import 'package:autofix/screens/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase instance and snackbarKey

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  late final Stream<List<Map<String, dynamic>>> _requestsStream;
  final String? _currentUserId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _requestsStream = supabase
          .from('service_requests')
          .stream(primaryKey: ['id'])
          .eq('requester_id', _currentUserId!)
          .order('created_at', ascending: false)
          .map((maps) => maps
              .map((map) => map as Map<String, dynamic>)
              .toList());
    }
  }
  
  // This function is now responsible for fetching the extra 'mechanic' and 'reviews' data
  // for a list of requests that come from the stream.
  Future<List<Map<String, dynamic>>> _fetchDetailsForRequests(
      List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) return [];

    // Extract unique mechanic and request IDs to fetch related data in batches
    final requestIds = requests.map((req) => req['id'] as String).toSet().toList();
    final mechanicIds = requests
        .map((req) => req['mechanic_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();

    if (requestIds.isEmpty) return requests;
    
    // Fetch profiles for all mechanics in one go
    final profilesData = mechanicIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await supabase
            .from('profiles')
            .select('id, full_name')
            .inFilter('id', mechanicIds);
    final profilesMap = {for (var p in profilesData) p['id']: p};

    // Fetch reviews for all requests in one go
    final reviewsData = await supabase
        .from('reviews')
        .select('service_request_id')
        .inFilter('service_request_id', requestIds);
    final reviewsMap = {
      for (var r in reviewsData) r['service_request_id']: true
    };
    
    // Combine the original request data with the fetched details
    return requests.map((req) {
      return {
        ...req,
        'mechanic': profilesMap[req['mechanic_id']],
        'has_review': reviewsMap.containsKey(req['id'])
      };
    }).toList();
  }


  Future<void> _submitReview({
    required int rating,
    required String? comment,
    required String serviceRequestId,
    required String mechanicId,
  }) async {
    if (_currentUserId == null) return;
    try {
      await supabase.from('reviews').insert({
        'service_request_id': serviceRequestId,
        'mechanic_id': mechanicId,
        'owner_id': _currentUserId,
        'rating': rating,
        'comment': comment,
      });

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Thank you for your feedback!'),
          backgroundColor: Colors.green,
        ));
        // No need to call setState, StreamBuilder will update automatically
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
          content: Text('Error submitting review: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showReviewDialog(Map<String, dynamic> request) {
    int _rating = 0;
    final _commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate Your Service with ${request['mechanic']?['full_name'] ?? 'the mechanic'}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  Text('Your rating:',
                      style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () {
                          setModalState(() {
                            _rating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Add a public comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _rating > 0
                          ? () {
                              Navigator.of(context).pop(); // Close the modal
                              _submitReview(
                                rating: _rating,
                                comment: _commentController.text,
                                serviceRequestId: request['id'],
                                mechanicId: request['mechanic_id'],
                              );
                            }
                          : null,
                      child: const Text('Submit Review'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My Service History')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _requestsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(
                child: Text('You have no service history yet.'));
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchDetailsForRequests(requests),
            builder: (context, detailsSnapshot) {
              if (!detailsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final detailedRequests = detailsSnapshot.data!;

              return ListView.builder(
                itemCount: detailedRequests.length,
                itemBuilder: (context, index) {
                  final request = detailedRequests[index];
                  final status = request['status'];
                  final paymentStatus = request['payment_status'] ?? 'unpaid';
                  final mechanicName = request['mechanic']?['full_name'] ?? 'N/A';
                  final bool hasReview = request['has_review'] ?? false;
                  final finalPrice = request['final_price'] ?? 0.0;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mechanic: $mechanicName',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('Status: $status',
                              style: TextStyle(
                                  color: status == 'completed'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.bold)),
                          if(finalPrice > 0) 
                            Text('Amount: ₱${(finalPrice as num).toStringAsFixed(2)}', 
                              style: Theme.of(context).textTheme.titleMedium),
                          if (request['requester_notes'] != null)
                            Text('Notes: ${request['requester_notes']}'),
                          const SizedBox(height: 16),
                          
                          // --- ACTION BUTTONS LOGIC ---
                          if (status == 'awaiting_payment')
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final result =
                                      await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PaymentScreen(
                                        serviceRequestId: request['id'],
                                        amount: (finalPrice as num).toDouble(),
                                      ),
                                    ),
                                  );
                                  // The stream will handle the UI update automatically
                                  // if payment is successful.
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Pay Now'),
                              ),
                            )
                          else if (status == 'completed' &&
                              paymentStatus == 'paid' &&
                              !hasReview)
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () => _showReviewDialog(request),
                                child: const Text('Leave a Review'),
                              ),
                            )
                          else if (status == 'completed' && hasReview)
                             const Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Paid & Reviewed',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                  SizedBox(width: 4),
                                  Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                ],
                              ),
                            )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}