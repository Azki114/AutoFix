// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and notifiers
import 'package:autofix/main.dart' as app_nav;
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // This future now only fetches role-specific data like reviews and details
  Future<Map<String, dynamic>>? _detailsFuture;
  final String? _currentUserId = supabase.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _detailsFuture = _fetchRoleSpecificDetails();
    }
  }

  // MODIFIED: This function now only fetches data NOT already in the global notifier
  Future<Map<String, dynamic>> _fetchRoleSpecificDetails() async {
    if (_currentUserId == null) throw 'User is not logged in.';
    if (userRole.value == null) throw 'User role not determined.';

    try {
      final role = userRole.value!;
      Map<String, dynamic> detailsData = {};

      if (role == 'driver') {
        final driverRes = await supabase
            .from('drivers')
            .select('*')
            .eq('user_id', _currentUserId)
            .single();
        detailsData['details'] = driverRes;
      } else if (role == 'mechanic') {
        final mechanicRes = await supabase
            .from('mechanics')
            .select('*')
            .eq('user_id', _currentUserId)
            .single();
        detailsData['details'] = mechanicRes;

        final reviewsRes = await supabase
            .from('reviews')
            .select('*, owner:profiles!owner_id(full_name)')
            .eq('mechanic_id', _currentUserId)
            .order('created_at', ascending: false);
        detailsData['reviews'] = reviewsRes;
      }
      return detailsData;
    } catch (e) {
      debugPrint("Error fetching role-specific details: $e");
      throw 'Failed to load profile details.';
    }
  }
  
  // This function is still used to refresh data after an action on this screen
  void _refreshScreen() {
    setState(() {
      _detailsFuture = _fetchRoleSpecificDetails();
    });
  }

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
        _refreshScreen();
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
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () async {
              // Navigate to Account screen and wait for it to pop
              await Navigator.pushNamed(context, '/account');
              // When we return, manually refresh the role-specific data
              _refreshScreen();
            },
          ),
        ],
      ),
      drawer: const app_nav.NavigationDrawer(),
      // NEW: This builder listens for changes to the user's basic profile info
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: userProfileNotifier,
        builder: (context, userProfile, child) {
          // This future builder now only fetches the role-specific details
          return FutureBuilder<Map<String, dynamic>>(
            future: _detailsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || userProfile == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Center(child: Text('Error: ${snapshot.error ?? "No data found."}'));
              }

              final data = snapshot.data!;
              final role = userRole.value;

              if (role == 'driver') {
                return _buildDriverProfile(userProfile, data);
              } else if (role == 'mechanic') {
                return _buildMechanicProfile(userProfile, data);
              } else {
                return const Center(child: Text('Unknown user role.'));
              }
            },
          );
        },
      ),
    );
  }

  // --- Profile Widgets ---

  Widget _buildDriverProfile(UserProfile userProfile, Map<String, dynamic> data) {
    final details = data['details'];
    if (details == null) return const Center(child: Text('Driver details not found.'));
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(userProfile.avatarUrl, userProfile.fullName ?? 'Driver', 'Vehicle Owner'),
        const Divider(height: 32),
        _buildInfoTile('Vehicle Type', details['vehicle_type']),
        _buildInfoTile('Maker', details['maker']),
        _buildInfoTile('Model', details['model']),
        _buildInfoTile('Year', details['year']),
        _buildInfoTile('License Plate', details['license_plate']),
      ],
    );
  }

  Widget _buildMechanicProfile(UserProfile userProfile, Map<String, dynamic> data) {
    final details = data['details'];
    if (details == null) return const Center(child: Text('Mechanic details not found.'));
    
    final reviews = (data['reviews'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final avgRating = (details['average_rating'] as num?)?.toDouble() ?? 0.0;
    final totalRatings = details['total_ratings'] as int? ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildProfileHeader(userProfile.avatarUrl, userProfile.fullName ?? 'Mechanic', 'Mechanic'),
        const SizedBox(height: 16),
        _buildRatingSummary(avgRating, totalRatings),
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
          ...reviews.map((review) => _buildReviewCard(review)),
      ],
    );
  }
  
  Widget _buildProfileHeader(String? avatarUrl, String name, String role) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40))
              : null,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(ownerName, style: const TextStyle(fontWeight: FontWeight.bold))),
                Row(
                  children: List.generate(5, (index) => Icon(
                    index < (review['rating'] ?? 0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 18,
                  )),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd().format(DateTime.parse(review['created_at'])),
              style: const TextStyle(color: Colors.grey, fontSize: 12)
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