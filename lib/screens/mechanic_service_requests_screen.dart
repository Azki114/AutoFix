import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client and snackbarKey
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart'; // Import geolocator for GPS
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/account_screen.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:autofix/screens/mechanic_map_screen.dart'; // Import the dedicated map screen

/// A screen for mechanics to view and manage service requests.
/// It displays pending requests and requests they have accepted in separate tabs.
class MechanicServiceRequestsScreen extends StatefulWidget {
  const MechanicServiceRequestsScreen({super.key});

  @override
  State<MechanicServiceRequestsScreen> createState() =>
      _MechanicServiceRequestsScreenState();
}

class _MechanicServiceRequestsScreenState
    extends State<MechanicServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final Future<void> _initializeFuture;
  String? _currentMechanicId;
  String? _mechanicFullName;
  Stream<List<Map<String, dynamic>>>? _pendingRequestsStream;
  Stream<List<Map<String, dynamic>>>? _acceptedRequestsStream;
  late final TabController _tabController;

  LatLng? _mechanicLocation;
  bool _isUpdatingLocation = false;
  StreamSubscription<Position>? _locationStreamSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeFuture = _initializeMechanic();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationStreamSubscription?.cancel();
    super.dispose();
  }

  /// Fetches initial mechanic data and sets up real-time streams.
  Future<void> _initializeMechanic() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      throw 'Mechanic not logged in.';
    }
    _currentMechanicId = user.id;
    
    // REVISION: Get the live location from the phone on startup and update the database.
    _mechanicLocation = await _updateAndGetLiveLocation();
    if (_mechanicLocation == null && mounted) {
       snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not get your location. Please enable location services and restart.'), backgroundColor: Colors.red));
    }

    final profile = await supabase.from('profiles').select('full_name, role').eq('id', _currentMechanicId!).single();
    if (profile['role'] != 'mechanic') {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      throw 'Unauthorized: Not a mechanic profile.';
    }

    _mechanicFullName = profile['full_name'];
    _initializeStreams();
  }
  
  /// REVISION: New function to get the phone's current GPS location and update Supabase.
  Future<LatLng?> _updateAndGetLiveLocation() async {
    if (!mounted) return null;
    setState(() => _isUpdatingLocation = true);

    try {
      // 1. Check and request location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied.';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      // 2. Get current position
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final currentLocation = LatLng(position.latitude, position.longitude);

      // 3. Update Supabase with the new location
      if (_currentMechanicId != null) {
        await supabase
          .from('mechanics')
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'last_seen': DateTime.now().toIso8601String(), // It's good practice to store a timestamp
          })
          .eq('user_id', _currentMechanicId!);
      }
      
      return currentLocation;
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Location Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
      return _mechanicLocation; // Return old location on error
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  /// Sets up the real-time streams for pending and accepted requests.
  void _initializeStreams() {
    _pendingRequestsStream = supabase.from('service_requests').stream(primaryKey: ['id']).eq('status', 'pending').order('created_at', ascending: false).asyncMap(_fetchProfilesForRequests);
    _acceptedRequestsStream = supabase.from('service_requests').stream(primaryKey: ['id']).eq('mechanic_id', _currentMechanicId!).order('accepted_at', ascending: false).map((requests) => requests.where((req) => req['status'] == 'accepted').toList()).asyncMap(_fetchProfilesForRequests);
  }

  /// Helper function to efficiently fetch profile information for a list of requests.
  Future<List<Map<String, dynamic>>> _fetchProfilesForRequests(List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) return [];
    final userIds = requests.map((req) => req['requester_id'] as String?).where((id) => id != null).toSet().toList();
    if (userIds.isEmpty) return requests;
    final profilesData = await supabase.from('profiles').select('id, full_name').inFilter('id', userIds);
    final profilesMap = {for (var p in profilesData) p['id']: p};
    return requests.map((req) => {...req, 'profiles': profilesMap[req['requester_id']] ?? {'full_name': 'Unknown Owner'}}).toList();
  }

  // --- Core Business Logic (Accept, Cancel, Complete) ---

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final mechanicId = _currentMechanicId;
    if (mechanicId == null) {
      if(mounted) snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Mechanic data not available.')));
      return;
    }
    final acceptedRequests = await supabase.from('service_requests').select('id').eq('mechanic_id', mechanicId).eq('status', 'accepted');
    if (acceptedRequests.isNotEmpty && mounted) {
      snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('You already have an active request.')));
      return;
    }
    final etaMinutes = await _showEtaInputDialog();
    if (etaMinutes == null) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'accepted',
        'mechanic_id': mechanicId,
        'accepted_at': DateTime.now().toIso8601String(),
        'eta_minutes': etaMinutes,
      }).eq('id', request['id']);
      if (mounted) snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Request accepted successfully!')));
    } on PostgrestException catch (e) {
      if (mounted) snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _cancelAcceptedRequest(Map<String, dynamic> request) async {
    final confirm = await _showConfirmationDialog(title: 'Cancel Service?', content: 'Are you sure you want to cancel this request?');
    if (!confirm) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled',
        'cancelled_by': _currentMechanicId,
        'cancelled_at': DateTime.now().toIso8601String(),
        'mechanic_id': null,
        'eta_minutes': null,
        'accepted_at': null,
      }).eq('id', request['id']);
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Service request cancelled.')));
      }
    } on PostgrestException catch (e) {
      if (mounted) snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  Future<void> _completeServiceRequest(Map<String, dynamic> request) async {
    final confirm = await _showConfirmationDialog(title: 'Complete Service?', content: 'Mark this request as completed?');
    if (!confirm) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'mechanic_id': null,
        'eta_minutes': null,
        'accepted_at': null,
      }).eq('id', request['id']);
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Service completed!')));
      }
    } on PostgrestException catch (e) {
      if (mounted) snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  /// REVISION: This function now calls the new database function to get the location
  /// as a simple text string, then parses it and navigates to the MechanicMapScreen.
  void _navigateToMapView(Map<String, dynamic> request) async {
    if (_mechanicLocation == null) {
      snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Your location is not available.')));
      return;
    }

    try {
      // Call the database function to get the location as a simple text string.
      final locationString = await supabase.rpc(
        'get_request_location_as_text',
        params: {'request_id_input': request['id']}
      ) as String;

      // Parse the string "POINT(longitude latitude)"
      final parts = locationString.substring(6, locationString.length - 1).split(' ');
      final lon = double.parse(parts[0]);
      final lat = double.parse(parts[1]);
      final requesterLocation = LatLng(lat, lon);

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MechanicMapScreen(
            mechanicLocation: _mechanicLocation!,
            requesterLocation: requesterLocation,
          ),
        ));
      }
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(SnackBar(content: Text('Failed to load map data: ${e.toString()}')));
    }
  }
  
  /// Shows a generic confirmation dialog.
  Future<bool> _showConfirmationDialog({required String title, required String content}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(child: const Text('No'), onPressed: () => Navigator.of(dialogContext).pop(false)),
              ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Yes')),
            ],
          ),
        ) ?? false;
  }

  /// Shows the dialog for entering ETA.
  Future<int?> _showEtaInputDialog() {
    final etaController = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter ETA'),
        content: TextField(
          controller: etaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'ETA (minutes)'),
        ),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
          ElevatedButton(
            child: const Text('Accept'),
            onPressed: () {
              final input = int.tryParse(etaController.text.trim());
              if (input != null && input > 0) {
                Navigator.of(dialogContext).pop(input);
              } else {
                snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Please enter a valid number.')));
              }
            },
          ),
        ],
      ),
    ).whenComplete(() => etaController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("Error initializing: ${snapshot.error}")));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Mechanic: ${_mechanicFullName ?? 'Requests'}'),
            backgroundColor: const Color.fromARGB(233, 214, 251, 250),
            centerTitle: true,
            elevation: 1,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Pending Requests', icon: Icon(Icons.access_time)),
                Tab(text: 'My Accepted Services', icon: Icon(Icons.build)),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.message), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatListScreen()))),
              IconButton(icon: const Icon(Icons.person), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountScreen()))),
            ],
          ),
          drawer: const app_nav.NavigationDrawer(),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PendingRequestsList(stream: _pendingRequestsStream!, onAccept: _acceptRequest),
              _AcceptedRequestsList(
                stream: _acceptedRequestsStream!,
                onCancel: _cancelAcceptedRequest,
                onComplete: _completeServiceRequest,
                onViewOnMap: _navigateToMapView,
              ),
            ],
          ),
          // REVISION: Add a FloatingActionButton to manually refresh the location.
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isUpdatingLocation ? null : () async {
              snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Updating your location...')));
              final newLocation = await _updateAndGetLiveLocation();
              if (mounted && newLocation != null) {
                setState(() {
                  _mechanicLocation = newLocation;
                });
                snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Location updated successfully!'), backgroundColor: Colors.green,));
              }
            },
            label: const Text('Refresh Location'),
            icon: _isUpdatingLocation 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                : const Icon(Icons.location_searching),
          ),
        );
      },
    );
  }
}

// --- UI Sub-Widgets ---

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList({required this.stream, required this.onAccept});
  final Stream<List<Map<String, dynamic>>> stream;
  final Function(Map<String, dynamic>) onAccept;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final requests = snapshot.data!;
        if (requests.isEmpty) return const Center(child: Text('No pending service requests.'));
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) => _RequestCard(request: requests[index], isPending: true, onAccept: onAccept),
        );
      },
    );
  }
}

class _AcceptedRequestsList extends StatelessWidget {
  const _AcceptedRequestsList({
    required this.stream,
    required this.onCancel,
    required this.onComplete,
    required this.onViewOnMap,
  });

  final Stream<List<Map<String, dynamic>>> stream;
  final Function(Map<String, dynamic>) onCancel;
  final Function(Map<String, dynamic>) onComplete;
  final Function(Map<String, dynamic>) onViewOnMap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final requests = snapshot.data!;
        if (requests.isEmpty) return const Center(child: Text('You have no active service requests.'));
        
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) => _RequestCard(
            request: requests[index],
            isPending: false,
            onCancel: onCancel,
            onComplete: onComplete,
            onViewOnMap: onViewOnMap,
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isPending,
    this.onAccept,
    this.onCancel,
    this.onComplete,
    this.onViewOnMap,
  });

  final Map<String, dynamic> request;
  final bool isPending;
  final Function(Map<String, dynamic>)? onAccept;
  final Function(Map<String, dynamic>)? onCancel;
  final Function(Map<String, dynamic>)? onComplete;
  final Function(Map<String, dynamic>)? onViewOnMap;

  @override
  Widget build(BuildContext context) {
    final requesterName = request['profiles']?['full_name'] ?? 'Unknown Owner';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request by: $requesterName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Status: ${request['status'].toString().toUpperCase()}'),
            if (request['requester_notes'] != null && request['requester_notes'].isNotEmpty)
              Text('Notes: ${request['requester_notes']}'),
            if (!isPending && request['status'] == 'accepted') ...[
              const SizedBox(height: 8),
              Text('ETA: ${request['eta_minutes']} minutes'),
              Text('Accepted At: ${DateTime.parse(request['accepted_at']).toLocal().toString().substring(0, 16)}'),
            ],
            const SizedBox(height: 16),
            if (isPending)
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton.icon(
                  onPressed: () => onAccept?.call(request),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Request'),
                ),
              )
            else if (request['status'] == 'accepted')
              Row(
                children: [
                  Expanded(child: ElevatedButton.icon(onPressed: () => onCancel?.call(request), icon: const Icon(Icons.cancel), label: const Text('Drop'))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(onPressed: () => onComplete?.call(request), icon: const Icon(Icons.done_all), label: const Text('Done'))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(onPressed: () => onViewOnMap?.call(request), icon: const Icon(Icons.map), label: const Text('Map'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

