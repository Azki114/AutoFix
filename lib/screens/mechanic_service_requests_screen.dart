import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client and snackbarKey
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart'; // Import geolocator for GPS
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/account_screen.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- HELPER WIDGETS FOR DIALOGS TO FIX CONTROLLER ERROR ---

/// Manages the state for the ETA input dialog's content.
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

/// Manages the state for the Price input dialog's content.
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

  /// Gets the phone's current GPS location and updates Supabase.
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
      return _mechanicLocation; // Return old location on error
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  /// Sets up the real-time streams for pending and accepted requests.
  void _initializeStreams() {
    // This stream fetches all changes from the 'service_requests' table.
    final serviceRequestsStream =
        supabase.from('service_requests').stream(primaryKey: ['id']);

    // This stream takes the raw data, then filters and sorts it in the app.
    _pendingRequestsStream = serviceRequestsStream.map((requests) {
      // Filter for 'pending' requests.
      final pending =
          requests.where((req) => req['status'] == 'pending').toList();
      // Sort by creation date, newest first.
      pending.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });
      return pending;
    }).asyncMap(_fetchProfilesForRequests);

    // This stream does the same for the mechanic's accepted requests.
    _acceptedRequestsStream = serviceRequestsStream.map((requests) {
      // Filter for requests accepted by the current mechanic.
      final accepted = requests
          .where((req) =>
              req['mechanic_id'] == _currentMechanicId &&
              req['status'] == 'accepted')
          .toList();
      // Sort by acceptance date, newest first.
      accepted.sort((a, b) {
        final dateA =
            a['accepted_at'] != null ? DateTime.parse(a['accepted_at']) : DateTime(1970);
        final dateB =
            b['accepted_at'] != null ? DateTime.parse(b['accepted_at']) : DateTime(1970);
        return dateB.compareTo(dateA);
      });
      return accepted;
    }).asyncMap(_fetchProfilesForRequests);
  }


  /// Helper function to efficiently fetch profile information for a list of requests.
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
    
    // The request ID is a UUID String, not an integer. No need to parse it.
    final requestId = request['id'] as String;
    await _updateDatabaseAfterCompletion(price, requestId);
  }

  Future<void> _updateDatabaseAfterCompletion(
      double price, String requestId) async { // The ID parameter is now a String.
    if (!mounted) return;

    try {
      await supabase.from('service_requests').update({
        // Change status to 'awaiting_payment'.
        // This allows the customer's app to show a "Pay Now" button.
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
      snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Your location is not available.')));
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
      snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to load map data: ${e.toString()}')));
    }
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
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatListScreen()))),
              IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AccountScreen()))),
            ],
          ),
          drawer: const app_nav.NavigationDrawer(),
          body: TabBarView(
            controller: _tabController,
            children: [
              _PendingRequestsList(
                  stream: _pendingRequestsStream!,
                  onAccept: _acceptRequest,
                  onCancel: _cancelRequest),
              _AcceptedRequestsList(
                stream: _acceptedRequestsStream!,
                onCancel: _cancelRequest,
                onComplete: _completeServiceRequest,
                onViewOnMap: _navigateToMapView,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _isUpdatingLocation
                ? null
                : () async {
                    snackbarKey.currentState?.showSnackBar(
                        const SnackBar(content: Text('Updating your location...')));
                    final newLocation = await _updateAndGetLiveLocation();
                    if (mounted && newLocation != null) {
                      setState(() {
                        _mechanicLocation = newLocation;
                      });
                      snackbarKey.currentState?.showSnackBar(const SnackBar(
                        content: Text('Location updated successfully!'),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
            label: const Text('Refresh Location'),
            icon: _isUpdatingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.0))
                : const Icon(Icons.location_searching),
          ),
        );
      },
    );
  }
}

// --- UI Sub-Widgets ---

class _PendingRequestsList extends StatelessWidget {
  const _PendingRequestsList(
      {required this.stream, required this.onAccept, required this.onCancel});
  final Stream<List<Map<String, dynamic>>> stream;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onCancel;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('No pending service requests.'));
        }
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) => _RequestCard(
            request: requests[index],
            isPending: true,
            onAccept: onAccept,
            onCancel: onCancel,
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('You have no active service requests.'));
        }

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
            const SizedBox(height: 16),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => onCancel?.call(request),
                    child: const Text('Cancel Request',
                        style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => onAccept?.call(request),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept Request'),
                  ),
                ],
              )
            else if (request['status'] == 'accepted')
              Row(
                children: [
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () => onCancel?.call(request),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () => onComplete?.call(request),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Done'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: ElevatedButton.icon(
                          onPressed: () => onViewOnMap?.call(request),
                          icon: const Icon(Icons.map),
                          label: const Text('Map'))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- NEW MECHANIC MAP SCREEN WIDGET ---

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