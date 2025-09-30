// lib/screens/mechanic_reviews_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client
import 'package:intl/intl.dart'; // For date formatting

class MechanicReviewsScreen extends StatefulWidget {
  const MechanicReviewsScreen({super.key});

  @override
  State<MechanicReviewsScreen> createState() => _MechanicReviewsScreenState();
}

class _MechanicReviewsScreenState extends State<MechanicReviewsScreen> {
  late final Future<List<Map<String, dynamic>>> _reviewsFuture;
  final String? _currentUserId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _fetchReviews();
  }

  Future<List<Map<String, dynamic>>> _fetchReviews() async {
    if (_currentUserId == null) {
      return [];
    }
    try {
      final response = await supabase
          .from('reviews')
          .select('*, owner:profiles!owner_id(full_name)')
          .eq('mechanic_id', _currentUserId!)
          .order('created_at', ascending: false);
      return response;
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      return [];
    }
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 20,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reviews'),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load reviews.'));
          }
          final reviews = snapshot.data!;
          if (reviews.isEmpty) {
            return const Center(child: Text('You have not received any reviews yet.'));
          }

          return ListView.builder(
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final ownerName = review['owner']?['full_name'] ?? 'Anonymous';
              final rating = review['rating'] as int;
              final comment = review['comment'] as String?;
              final createdAt = DateTime.parse(review['created_at']);
              final formattedDate = DateFormat.yMMMd().format(createdAt);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ownerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildStarRating(rating),
                      if (comment != null && comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(comment),
                      ]
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