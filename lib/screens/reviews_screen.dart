import 'package:flutter/material.dart';
import 'package:autofix/main.dart'; // For supabase instance

class ReviewsScreen extends StatefulWidget {
  final String mechanicId;
  final String shopName;

  const ReviewsScreen({
    super.key,
    required this.mechanicId,
    required this.shopName,
  });

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<Map<String, dynamic>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _fetchMechanicReviews();
  }

  Future<Map<String, dynamic>> _fetchMechanicReviews() async {
    try {
      // Fetch mechanic's average rating and total ratings in one query
      final mechanicDetails = await supabase
          .from('mechanics')
          .select('average_rating, total_ratings')
          .eq('user_id', widget.mechanicId)
          .single();

      // Fetch all reviews, joining with the profiles table to get the owner's name
      final reviewsList = await supabase
          .from('reviews')
          .select('*, owner:profiles!owner_id(full_name)')
          .eq('mechanic_id', widget.mechanicId)
          .order('created_at', ascending: false);

      return {
        'details': mechanicDetails,
        'reviews': reviewsList,
      };
    } catch (e) {
      debugPrint('Error fetching reviews: $e');
      throw Exception('Failed to load reviews.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Reviews for ${widget.shopName}"),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No review data found.'));
          }

          final details = snapshot.data!['details'];
          final reviews = (snapshot.data!['reviews'] as List).cast<Map<String, dynamic>>();
          final double avgRating = details['average_rating']?.toDouble() ?? 0.0;
          final int totalRatings = details['total_ratings'] ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildRatingSummary(avgRating, totalRatings),
              const Divider(height: 32),
              if (reviews.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('This mechanic has no reviews yet.'),
                  ),
                )
              else
                ...reviews.map((review) => _buildReviewCard(review)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRatingSummary(double avgRating, int totalRatings) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(
                  avgRating.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text('Average Rating'),
              ],
            ),
            Column(
              children: [
                Row(
                  children: List.generate(5, (index) => Icon(
                    index < avgRating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 28,
                  )),
                ),
                const SizedBox(height: 4),
                Text('Based on $totalRatings Reviews'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final ownerName = review['owner']?['full_name'] ?? 'Anonymous';
    final mechanicReply = review['mechanic_reply'] as String?;
    final createdAt = DateTime.parse(review['created_at']).toLocal();
    final formattedDate = "${createdAt.month}/${createdAt.day}/${createdAt.year}";

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(formattedDate, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (index) => Icon(
                index < review['rating'] ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 18,
              )),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 4),
                Text('Verified Service', style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            if (review['comment'] != null && review['comment'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review['comment']),
            ],
            if (mechanicReply != null && mechanicReply.isNotEmpty) ...[
              const Divider(height: 24),
              _buildMechanicReply(mechanicReply),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildMechanicReply(String reply) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mechanic\'s Reply:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(reply),
        ],
      ),
    );
  }
}
