import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client and snackbarKey
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/account_screen.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:autofix/screens/call_screen.dart'; // Import the call screen
import 'package:autofix/screens/chat_screen.dart'; // Import the chat screen

// --- HELPER WIDGETS (Unchanged) ---
class _EtaInputDialogContent extends StatefulWidget {
  const _EtaInputDialogContent();
  @override
  _EtaInputDialogContentState createState() => _EtaInputDialogContentState();
}
class _EtaInputDialogContentState extends State<_EtaInputDialogContent> {
  late final TextEditingController _etaController;
  @override
  void initState() {
    super.initState();
    _etaController = TextEditingController();
  }
  @override
  void dispose() {
    _etaController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter ETA'),
      content: TextField(
        controller: _etaController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'ETA (minutes)'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Accept'),
          onPressed: () {
            final input = int.tryParse(_etaController.text.trim());
            if (input != null && input > 0) {
              Navigator.of(context).pop(input);
            } else {
              snackbarKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid number.')));
            }
          },
        ),
      ],
    );
  }
}

class _PriceInputDialogContent extends StatefulWidget {
  const _PriceInputDialogContent();
  @override
  _PriceInputDialogContentState createState() =>
      _PriceInputDialogContentState();
}
class _PriceInputDialogContentState extends State<_PriceInputDialogContent> {
  late final TextEditingController _priceController;
  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController();
  }
  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Final Price'),
      content: TextField(
        controller: _priceController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration:
            const InputDecoration(labelText: 'Final Price (₱)', prefixText: '₱'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: const Text('Confirm'),
          onPressed: () {
            final input = double.tryParse(_priceController.text.trim());
            if (input != null && input >= 0) {
              Navigator.of(context).pop(input);
            } else {
              snackbarKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid price.')));
            }
          },
        ),
      ],
    );
  }
}
// --- END HELPER WIDGETS ---

class MechanicServiceRequestsScreen extends StatefulWidget {
  const MechanicServiceRequestsScreen({super.key});

  @override
  State<MechanicServiceRequestsScreen> createState() =>
      _MechanicServiceRequestsScreenState();
}

class _MechanicServiceRequestsScreenState
    extends State<MechanicServiceRequestsScreen>
    with SingleTickerProviderStateMixin {
  late Future<void> _initializeFuture;
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

  Future<void> _initializeMechanic() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      throw 'Mechanic not logged in.';
    }
    _currentMechanicId = user.id;

    _mechanicLocation = await _updateAndGetLiveLocation();
    if (_mechanicLocation == null && mounted) {
      snackbarKey.currentState?.showSnackBar(const SnackBar(
          content: Text(
              'Could not get your location. Please enable location services and restart.'),
          backgroundColor: Colors.red));
    }

    final profile = await supabase
        .from('profiles')
        .select('full_name, role')
        .eq('id', _currentMechanicId!)
        .single();
    if (profile['role'] != 'mechanic') {
      Future.delayed(Duration.zero, () {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      });
      throw 'Unauthorized: Not a mechanic profile.';
    }

    _mechanicFullName = profile['full_name'];
    _initializeStreams();
  }

  Future<void> _refreshData() async {
    snackbarKey.currentState
        ?.showSnackBar(const SnackBar(content: Text('Refreshing data...'), duration: Duration(seconds: 1),));
    await _initializeMechanic();
    if (mounted) {
      setState(() {});
    }
  }

  Future<LatLng?> _updateAndGetLiveLocation() async {
    if (!mounted) return null;
    setState(() => _isUpdatingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

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

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final currentLocation = LatLng(position.latitude, position.longitude);

      if (_currentMechanicId != null) {
        await supabase.from('mechanics').update({
          'live_latitude': position.latitude,
          'live_longitude': position.longitude,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('user_id', _currentMechanicId!);
      }
      return currentLocation;
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Location Error: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
      return _mechanicLocation;
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  void _initializeStreams() {
    final serviceRequestsStream =
        supabase.from('service_requests').stream(primaryKey: ['id']);

    _pendingRequestsStream = serviceRequestsStream.map((requests) {
      final pending = requests.where((req) => 
        req['status'] == 'pending' &&
        req['mechanic_id'] == _currentMechanicId
      ).toList();
      
      pending.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });
      return pending;
    }).asyncMap(_fetchProfilesForRequests);

    _acceptedRequestsStream = serviceRequestsStream.map((requests) {
      final accepted = requests
          .where((req) =>
              req['mechanic_id'] == _currentMechanicId &&
              req['status'] == 'accepted')
          .toList();
      accepted.sort((a, b) {
        final dateA = a['accepted_at'] != null
            ? DateTime.parse(a['accepted_at'])
            : DateTime(1970);
        final dateB = b['accepted_at'] != null
            ? DateTime.parse(b['accepted_at'])
            : DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return accepted;
    }).asyncMap(_fetchProfilesForRequests);
  }


  Future<List<Map<String, dynamic>>> _fetchProfilesForRequests(
      List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) return [];
    final userIds = requests
        .map((req) => req['requester_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();
    if (userIds.isEmpty) return requests;
    final profilesData =
        await supabase.from('profiles').select('id, full_name').inFilter('id', userIds);
    final profilesMap = {for (var p in profilesData) p['id']: p};
    return requests
        .map((req) => {
              ...req,
              'profiles':
                  profilesMap[req['requester_id']] ?? {'full_name': 'Unknown Owner'}
            })
        .toList();
  }

  // --- Core Business Logic (Accept, Cancel, Complete) ---

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final mechanicId = _currentMechanicId;
    if (mechanicId == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Mechanic data not available.')));
      }
      return;
    }
    final acceptedRequests = await supabase
        .from('service_requests')
        .select('id')
        .eq('mechanic_id', mechanicId)
        .eq('status', 'accepted');
    if (acceptedRequests.isNotEmpty && mounted) {
      snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You already have an active request.')));
      return;
    }
    final etaMinutes = await _showEtaInputDialog();
    if (etaMinutes == null || !mounted) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'accepted',
        'mechanic_id': mechanicId,
        'accepted_at': DateTime.now().toIso8601String(),
        'eta_minutes': etaMinutes,
      }).eq('id', request['id']);
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Request accepted successfully!')));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState
            ?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _cancelRequest(Map<String, dynamic> request) async {
    final confirm = await _showConfirmationDialog(
        title: 'Cancel Service?',
        content: 'Are you sure you want to cancel this request?');
    if (!confirm || !mounted) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled_by_mechanic',
        'cancelled_by': _currentMechanicId,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('id', request['id']);
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Service request cancelled.')));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState
            ?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _completeServiceRequest(Map<String, dynamic> request) async {
    final price = await _showPriceInputDialog();
    if (price == null || !mounted) return;

    final confirm = await _showConfirmationDialog(
        title: 'Complete Service?',
        content:
            'Mark this request as completed for ₱${price.toStringAsFixed(2)}?');
    if (!confirm || !mounted) return;
    
    final requestId = request['id'] as String;
    await _updateDatabaseAfterCompletion(price, requestId);
  }

  Future<void> _updateDatabaseAfterCompletion(
      double price, String requestId) async {
    if (!mounted) return;
    try {
      await supabase.from('service_requests').update({
        'status': 'awaiting_payment',
        'final_price': price,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(
            content: Text('Service completed! Waiting for payment.')));
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState
            ?.showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  void _navigateToMapView(Map<String, dynamic> request) async {
    if (_mechanicLocation == null) {
      _showSnackBar('Your location is not available.');
      return;
    }
    try {
      final locationString = await supabase.rpc(
        'get_request_location_as_text',
        params: {'request_id_input': request['id']},
      ) as String;
      final parts =
          locationString.substring(6, locationString.length - 1).split(' ');
      final lon = double.parse(parts[0]);
      final lat = double.parse(parts[1]);
      final requesterLocation = LatLng(lat, lon);

      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => MechanicMapScreen(
            initialMechanicLocation: _mechanicLocation!,
            requesterLocation: requesterLocation,
          ),
        ));
      }
    } catch (e) {
      _showSnackBar('Failed to load map data: ${e.toString()}');
    }
  }

  // --- NEW: Function to navigate to the call screen ---
  void _navigateToCall(Map<String, dynamic> request) {
    if (_currentMechanicId == null) {
      _showSnackBar('Cannot initiate call. Mechanic ID is missing.');
      return;
    }
    final requesterId = request['requester_id'] as String?;
    if (requesterId == null) {
      _showSnackBar('Cannot initiate call. Requester ID is missing.');
      return;
    }
    
    // Create a unique, consistent Call ID (which is the Chat ID)
    final mechanicId = _currentMechanicId!;
    final callID = (requesterId.compareTo(mechanicId) < 0)
        ? '${requesterId}_${mechanicId}'
        : '${mechanicId}_${requesterId}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          callID: callID,
        ),
      ),
    );
  }
  
  // --- *** THIS IS THE CORRECTED FUNCTION *** ---
  Future<void> _navigateToChat(Map<String, dynamic> request) async {
    if (_currentMechanicId == null) {
      _showSnackBar('Cannot start chat. Mechanic ID is missing.');
      return;
    }
    // The driver is the requester
    final driverId = request['requester_id'] as String?;
    final driverName = request['profiles']?['full_name'] as String?;
    
    if (driverId == null || driverName == null) {
      _showSnackBar('Cannot start chat. Requester (Driver) data is missing.');
      return;
    }

    final mechanicId = _currentMechanicId!;

    try {
      // 1. Check if a chat already exists between these two users
      // We check for both (mechanic=A, driver=B) OR (mechanic=B, driver=A)
      // This logic assumes your table has columns 'mechanic_id' and 'driver_id'
      final response = await supabase
          .from('chats')
          .select('id')
          .or('and(mechanic_id.eq.$mechanicId,driver_id.eq.$driverId),and(mechanic_id.eq.$driverId,driver_id.eq.$mechanicId)')
          .maybeSingle(); // Use .maybeSingle() to get one row or null

      String chatId;

      if (response != null && response['id'] != null) {
        // 2. A chat already exists. Use its ID.
        chatId = response['id'];
      } else {
        // 3. No chat exists. Create a new one.
        // We let Supabase generate the 'id' (UUID) automatically.
        // We MUST provide both driver_id and mechanic_id to satisfy the NOT NULL constraint.
        final newChat = await supabase
            .from('chats')
            .insert({
              'mechanic_id': mechanicId,
              'driver_id': driverId, // Use the correct column name from your error
              'last_message_content': 'Chat initiated...'
            })
            .select('id') // Ask Supabase to return the 'id' of the new row
            .single();
        
        chatId = newChat['id'];
      }

      // 4. Navigate to the chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatPartnerName: driverName, // The chat partner is the driver
              currentUserId: mechanicId,   // The current user is the mechanic
              chatPartnerId: driverId,     // The chat partner ID is the driver's ID
            ),
          ),
        );
      }

    } catch (e) {
      _showSnackBar('Error initializing chat: ${e.toString()}');
    }
  }
  
  void _showSnackBar(String message) {
    snackbarKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<bool> _showConfirmationDialog(
      {required String title, required String content}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                  child: const Text('No'),
                  onPressed: () => Navigator.of(dialogContext).pop(false)),
              ElevatedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Yes')),
            ],
          ),
        ) ??
        false;
  }

  Future<int?> _showEtaInputDialog() {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => const _EtaInputDialogContent(),
    );
  }

  Future<double?> _showPriceInputDialog() {
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => const _PriceInputDialogContent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text("Error initializing: ${snapshot.error}")));
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
              IconButton(
                  icon: const Icon(Icons.message),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ChatListScreen()))),
              IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AccountScreen()))),
            ],
          ),
          drawer: const app_nav.NavigationDrawer(),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PendingRequestsList(
                stream: _pendingRequestsStream!,
                onAccept: _acceptRequest,
                onCancel: _cancelRequest,
                onViewOnMap: _navigateToMapView,
                onRefresh: _refreshData,
                onChat: _navigateToChat,
              ),
              _AcceptedRequestsList(
                stream: _acceptedRequestsStream!,
                onCancel: _cancelRequest,
                onComplete: _completeServiceRequest,
                onViewOnMap: _navigateToMapView,
                onRefresh: _refreshData,
                onCall: _navigateToCall,
                onChat: _navigateToChat,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isUpdatingLocation ? null : _refreshData,
            label: const Text('Refresh'),
            icon: _isUpdatingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.0))
                : const Icon(Icons.refresh),
          ),
        );
      },
    );
  }
}

// --- UI Sub-Widgets ---

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList({
    required this.stream,
    required this.onAccept,
    required this.onCancel,
    required this.onViewOnMap,
    required this.onRefresh,
    required this.onChat,
  });
  final Stream<List<Map<String, dynamic>>> stream;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onCancel;
  final Function(Map<String, dynamic>) onViewOnMap;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>) onChat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView( 
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height / 3),
                const Center(child: Text('No pending service requests.\nPull down to refresh.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              isPending: true,
              onAccept: onAccept,
              onCancel: onCancel,
              onViewOnMap: onViewOnMap,
              onChat: onChat,
            ),
          ),
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
    required this.onRefresh,
    required this.onCall,
    required this.onChat,
  });

  final Stream<List<Map<String, dynamic>>> stream;
  final Function(Map<String, dynamic>) onCancel;
  final Function(Map<String, dynamic>) onComplete;
  final Function(Map<String, dynamic>) onViewOnMap;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>) onCall;
  final Function(Map<String, dynamic>) onChat;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView( 
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height / 3),
                const Center(child: Text('You have no active service requests.\nPull down to refresh.')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: requests.length,
            itemBuilder: (context, index) => _RequestCard(
              request: requests[index],
              isPending: false,
              onCancel: onCancel,
              onComplete: onComplete,
              onViewOnMap: onViewOnMap,
              onCall: onCall,
              onChat: onChat,
            ),
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
    this.onCall,
    this.onChat,
  });

  final Map<String, dynamic> request;
  final bool isPending;
  final Function(Map<String, dynamic>)? onAccept;
  final Function(Map<String, dynamic>)? onCancel;
  final Function(Map<String, dynamic>)? onComplete;
  final Function(Map<String, dynamic>)? onViewOnMap;
  final Function(Map<String, dynamic>)? onCall;
  final Function(Map<String, dynamic>)? onChat;

  @override
  Widget build(BuildContext context) {
    final requesterName =
        request['profiles']?['full_name'] ?? 'Unknown Owner';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Request by: $requesterName',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Status: ${request['status'].toString().toUpperCase()}'),
            if (request['requester_notes'] != null &&
                request['requester_notes'].isNotEmpty)
              Text('Notes: ${request['requester_notes']}'),
            if (!isPending && request['status'] == 'accepted') ...[
              const SizedBox(height: 8),
              Text('ETA: ${request['eta_minutes']} minutes'),
              Text(
                  'Accepted At: ${DateTime.parse(request['accepted_at']).toLocal().toString().substring(0, 16)}'),
            ],
            const SizedBox(height: 12),
            if (isPending)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  TextButton.icon(
                    onPressed: () => onCancel?.call(request),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => onViewOnMap?.call(request),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Map'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => onAccept?.call(request),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Accept'),
                  ),
                ],
              )
            else if (request['status'] == 'accepted')
              Wrap( 
                alignment: WrapAlignment.end,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  TextButton.icon(
                    onPressed: () => onCancel?.call(request),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  TextButton.icon(
                    onPressed: () => onViewOnMap?.call(request),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navigate'),
                  ),
                  TextButton.icon(
                    onPressed: () => onChat?.call(request),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                  ),
                  TextButton.icon(
                    onPressed: () => onCall?.call(request),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Call'),
                    style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => onComplete?.call(request),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text('Done'),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}

// --- MechanicMapScreen (Unchanged) ---
class MechanicMapScreen extends StatefulWidget {
  final LatLng initialMechanicLocation;
  final LatLng requesterLocation;

  const MechanicMapScreen({
    super.key,
    required this.initialMechanicLocation,
    required this.requesterLocation,
  });

  @override
  State<MechanicMapScreen> createState() => _MechanicMapScreenState();
}
class _MechanicMapScreenState extends State<MechanicMapScreen> {
  final MapController _mapController = MapController();
  late LatLng _currentMechanicLocation;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<Polyline> _routePolylines = [];
  bool _isCalculatingRoute = false;

  @override
  void initState() {
    super.initState();
    _currentMechanicLocation = widget.initialMechanicLocation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getDirections(_currentMechanicLocation, widget.requesterLocation);
        _startLocationUpdates();
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      if (mounted) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentMechanicLocation = newLocation;
        });
      }
    });
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() => _isCalculatingRoute = true);

    final String osrmApiUrl =
        'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmApiUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates =
              data['routes'][0]['geometry']['coordinates'];
          List<LatLng> routePoints = coordinates
              .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
              .toList();

          if (mounted) {
            setState(() {
              _routePolylines = [
                Polyline(
                    points: routePoints,
                    color: Colors.blueAccent,
                    strokeWidth: 5.0)
              ];
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(routePoints),
                  padding: const EdgeInsets.all(80.0),
                ),
              );
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting directions: $e");
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Navigation'),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMechanicLocation,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.autofix.app',
              ),
              PolylineLayer(polylines: _routePolylines),
              MarkerLayer(
                markers: [
                  Marker(
                    key: const Key('requesterLocation'),
                    point: widget.requesterLocation,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: "Vehicle Owner's Location",
                      child: Icon(Icons.person_pin_circle,
                          color: Colors.red, size: 45),
                    ),
                  ),
                  Marker(
                    key: const Key('mechanicLiveLocation'),
                    point: _currentMechanicLocation,
                    width: 80,
                    height: 80,
                    child: const Tooltip(
                      message: "My Location",
                      child: Icon(Icons.directions_car,
                          color: Colors.blue, size: 40),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isCalculatingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}