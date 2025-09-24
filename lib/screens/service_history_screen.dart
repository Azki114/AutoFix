import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase instance and snackbarKey

class ServiceHistoryScreen extends StatefulWidget {
  const ServiceHistoryScreen({super.key});

  @override
  State<ServiceHistoryScreen> createState() => _ServiceHistoryScreenState();
}

class _ServiceHistoryScreenState extends State<ServiceHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _requestsFuture;
  final String? _currentUserId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _requestsFuture = _fetchServiceHistory();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchServiceHistory() async {
    try {
      // CORRECTED QUERY: Uses the proper foreign key relationship for reviews.
      final response = await supabase
          .from('service_requests')
          .select('*, mechanic:profiles!mechanic_id(full_name), reviews!service_request_id(*)')
          .eq('requester_id', _currentUserId!)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      debugPrint("Error fetching service history: $e");
      return [];
    }
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
        // Refresh the list to show "Review Submitted"
        setState(() {
          _requestsFuture = _fetchServiceHistory();
        });
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
                left: 16, right: 16, top: 16,
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
                  Text('Your rating:', style: Theme.of(context).textTheme.titleMedium),
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
                      onPressed: _rating > 0 ? () {
                        Navigator.of(context).pop(); // Close the modal
                        _submitReview(
                          rating: _rating,
                          comment: _commentController.text,
                          serviceRequestId: request['id'],
                          mechanicId: request['mechanic_id'],
                        );
                      } : null,
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return const Center(child: Text('You have no service history yet.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final status = request['status'];
              // CORRECTED: Key for mechanic's profile data
              final mechanicName = request['mechanic']?['full_name'] ?? 'N/A';
              // CORRECTED: Key for the joined reviews data
              final bool hasReview = (request['reviews'] as List?)?.isNotEmpty ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mechanic: $mechanicName', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Status: $status', style: TextStyle(color: status == 'completed' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                      if (request['requester_notes'] != null) Text('Notes: ${request['requester_notes']}'),
                      const SizedBox(height: 16),
                      if (status == 'completed' && !hasReview)
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
                          child: Text('Review Submitted ✔', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

