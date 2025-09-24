import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  final String? _currentUserId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _profileFuture = _fetchUserProfile();
    }
  }

  Future<Map<String, dynamic>> _fetchUserProfile() async {
    if (_currentUserId == null) throw 'User is not logged in.';

    try {
      // Fetch the basic profile to determine the role
      final profileRes = await supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', _currentUserId!)
          .single();

      final String role = profileRes['role'];
      Map<String, dynamic> userProfileData = {'profile': profileRes};

      // Based on the role, fetch role-specific data
      if (role == 'driver') {
        final driverRes = await supabase
            .from('drivers')
            .select('*')
            .eq('user_id', _currentUserId!)
            .single();
        userProfileData['details'] = driverRes;
      } else if (role == 'mechanic') {
        final mechanicRes = await supabase
            .from('mechanics')
            .select('*')
            .eq('user_id', _currentUserId!)
            .single();
        userProfileData['details'] = mechanicRes;

        // NEW: Fetch all reviews for this mechanic
        final reviewsRes = await supabase
            .from('reviews')
            .select('*, owner:profiles!owner_id(full_name)')
            .eq('mechanic_id', _currentUserId!)
            .order('created_at', ascending: false);
        userProfileData['reviews'] = reviewsRes;
      }

      return userProfileData;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      throw 'Failed to load profile data.';
    }
  }
  
  // NEW: Function for a mechanic to add a reply to a review
  Future<void> _addMechanicReply(String reviewId, String replyText) async {
    try {
      await supabase
        .from('reviews')
        .update({'mechanic_reply': replyText})
        .eq('id', reviewId);
      
      if(mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(
          content: Text("Your reply has been posted."),
          backgroundColor: Colors.green,
        ));
        // Refresh the profile to show the new reply
        setState(() {
          _profileFuture = _fetchUserProfile();
        });
      }

    } catch (e) {
      if (mounted) {
         snackbarKey.currentState?.showSnackBar(SnackBar(
          content: Text("Error posting reply: ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // NEW: Dialog for submitting a mechanic's reply
  void _showReplyDialog(String reviewId) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reply to Review'),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(
              labelText: 'Your public reply',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (replyController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  _addMechanicReply(reviewId, replyController.text.trim());
                }
              },
              child: const Text('Submit Reply'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text("Please log in to view your profile.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _profileFuture = _fetchUserProfile();
              });
            },
          ),
        ],
      ),
      drawer: const app_nav.NavigationDrawer(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Error: ${snapshot.error ?? "No data found."}'));
          }

          final data = snapshot.data!;
          final role = data['profile']['role'];

          if (role == 'driver') {
            return _buildDriverProfile(data);
          } else if (role == 'mechanic') {
            return _buildMechanicProfile(data);
          } else {
            return const Center(child: Text('Unknown user role.'));
          }
        },
      ),
    );
  }

  // --- Profile Widgets ---

  Widget _buildDriverProfile(Map<String, dynamic> data) {
    final profile = data['profile'];
    final details = data['details'];
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(profile['full_name'], 'Vehicle Owner'),
        const Divider(height: 32),
        _buildInfoTile('Vehicle Type', details['vehicle_type']),
        _buildInfoTile('Maker', details['maker']),
        _buildInfoTile('Model', details['model']),
        _buildInfoTile('Year', details['year']),
        _buildInfoTile('License Plate', details['license_plate']),
      ],
    );
  }

  Widget _buildMechanicProfile(Map<String, dynamic> data) {
    final profile = data['profile'];
    final details = data['details'];
    final reviews = (data['reviews'] as List).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(profile['full_name'], 'Mechanic'),
        const SizedBox(height: 16),
        _buildRatingSummary(
          details['average_rating']?.toDouble() ?? 0.0,
          details['total_ratings'] ?? 0,
        ),
        const Divider(height: 32),
        _buildInfoTile('Shop Name', details['shop_name']),
        _buildInfoTile('Business Address', details['business_address']),
        _buildInfoTile('Specialties', details['specialties']),
        _buildInfoTile('Certifications', details['certifications']),
        const Divider(height: 32),
        Text('Customer Reviews', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (reviews.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('You have no reviews yet.'),
          ))
        else
          ...reviews.map((review) => _buildReviewCard(review)).toList(),
      ],
    );
  }
  
  Widget _buildProfileHeader(String name, String role) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40)),
        ),
        const SizedBox(height: 16),
        Text(name, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        Text(role, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
      ],
    );
  }
  
  Widget _buildRatingSummary(double avgRating, int totalRatings) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text(avgRating.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineMedium),
                const Text('Average Rating'),
              ],
            ),
            Column(
              children: [
                Row(
                  children: List.generate(5, (index) => Icon(
                    index < avgRating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  )),
                ),
                Text('$totalRatings Reviews'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, dynamic value) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value?.toString() ?? 'N/A'),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final ownerName = review['owner']?['full_name'] ?? 'Anonymous';
    final mechanicReply = review['mechanic_reply'] as String?;

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
                Row(
                  children: List.generate(5, (index) => Icon(
                    index < review['rating'] ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
            const Divider(height: 24),
            if (mechanicReply != null && mechanicReply.isNotEmpty)
              _buildMechanicReply(mechanicReply)
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showReplyDialog(review['id']),
                  child: const Text('Reply to this review'),
                ),
              ),
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
          Text('Your Reply:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 4),
          Text(reply),
        ],
      ),
    );
  }
}

