// lib/screens/mechanic_service_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // For supabase client and snackbarKey
import 'package:flutter_map/flutter_map.dart'; // For displaying map
import 'package:latlong2/latlong.dart'; // For LatLng
import 'dart:async'; // For StreamSubscription
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding

// Correctly import ChatListScreen and AccountScreen
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/account_screen.dart';
import 'package:autofix/main.dart' as app_nav; // Import for NavigationDrawer

class MechanicServiceRequestsScreen extends StatefulWidget {
  const MechanicServiceRequestsScreen({super.key});

  @override
  State<MechanicServiceRequestsScreen> createState() => _MechanicServiceRequestsScreenState();
}

class _MechanicServiceRequestsScreenState extends State<MechanicServiceRequestsScreen> {
  String? _currentMechanicId;
  String? _mechanicFullName;
  Map<String, dynamic>? _mechanicProfile; // To store full mechanic profile for general data

  // Using Stream<List<Map<String, dynamic>>> for StreamBuilder
  Stream<List<Map<String, dynamic>>>? _pendingRequestsStream;
  Stream<List<Map<String, dynamic>>>? _acceptedRequestsStream;

  // Map state variables
  final MapController _mapController = MapController();
  LatLng? _requesterLocationForMap;
  LatLng? _mechanicLocationForMap;
  final Set<Marker> _markers = {};
  List<Polyline> _polylines = [];
  bool _isMapLoading = false;
  bool _isCalculatingRoute = false;

  Map<String, dynamic>? _detailedAcceptedRequest; // Holds the request currently shown on map

  @override
  void initState() {
    super.initState();
    _initializeMechanic();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Initializes the mechanic's data and sets up the streams for service requests.
  /// It fetches the current user, validates their role, retrieves their location,
  /// and then sets up real-time listeners for pending and accepted requests.
  Future<void> _initializeMechanic() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Mechanic not logged in.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    _currentMechanicId = user.id;

    if (_currentMechanicId == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Could not get mechanic ID. Please re-login.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    try {
      // Fetch profile and role
      final profile = await supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', _currentMechanicId!)
          .single();

      if (!mounted) return;

      if (profile['role'] != 'mechanic') {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Unauthorized: Not a mechanic profile.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Fetch mechanic-specific data (latitude, longitude)
      final mechanicData = await supabase
          .from('mechanics')
          .select('latitude, longitude')
          .eq('user_id', _currentMechanicId!)
          .single();

      if (!mounted) return;

      setState(() {
        _mechanicProfile = {
          ...profile,
          ...mechanicData,
        };
        _mechanicFullName = profile['full_name'];
        if (mechanicData['latitude'] != null && mechanicData['longitude'] != null) {
          _mechanicLocationForMap = LatLng(mechanicData['latitude'], mechanicData['longitude']);
        }

        // Setup real-time streams (using your correct pattern)
        _pendingRequestsStream = supabase
            .from('service_requests')
            .select() // Select all columns for the stream
            .eq('status', 'pending')
            .order('created_at', ascending: false)
            .asStream() // Convert the PostgrestFilterBuilder to a Stream
            .map((data) => data.cast<Map<String, dynamic>>().toList());


        _acceptedRequestsStream = supabase
            .from('service_requests')
            .select() // Select all columns for the stream
            .eq('mechanic_id', _currentMechanicId!)
            .eq('status', 'accepted')
            .order('accepted_at', ascending: false)
            .asStream() // Convert the PostgrestFilterBuilder to a Stream
            .map((data) => data.cast<Map<String, dynamic>>().toList());
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error fetching mechanic profile: ${e.message}')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  /// Handles accepting a service request.
  /// Prompts the mechanic for an ETA and updates the request status in Supabase.
  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final String? mechanicId = _currentMechanicId;

    if (mechanicId == null || _mechanicLocationForMap == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Mechanic ID or location not available. Cannot accept request.')),
        );
      }
      return;
    }

    // Check if the mechanic already has an accepted request
    final List<Map<String, dynamic>> acceptedRequests = await supabase
        .from('service_requests')
        .select('id')
        .eq('mechanic_id', mechanicId)
        .eq('status', 'accepted');

    if (acceptedRequests.isNotEmpty) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You already have an active accepted request. Complete or cancel it first.')),
        );
      }
      return;
    }

    int? etaMinutes = await _showEtaInputDialog();
    if (etaMinutes == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Acceptance cancelled. ETA not provided.')),
        );
      }
      return;
    }

    try {
      await supabase.from('service_requests').update({
        'status': 'accepted',
        'mechanic_id': mechanicId,
        'accepted_at': DateTime.now().toIso8601String(),
        'eta_minutes': etaMinutes,
      }).eq('id', request['id']);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Request accepted successfully! Owner will be notified.')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error accepting request: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    }
  }

  /// Handles canceling an already accepted service request.
  /// Prompts for confirmation and updates the request status to 'cancelled'.
  Future<void> _cancelAcceptedRequest(Map<String, dynamic> request) async {
    final String? mechanicId = _currentMechanicId;

    if (mechanicId == null) return;

    bool confirmCancel = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Service?'),
          content: const Text('Are you sure you want to cancel this accepted service request? The owner will be notified.'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmCancel) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled',
        'cancelled_by': mechanicId,
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': 'Mechanic cancelled service',
        'mechanic_id': null, // Clear mechanic assignment
        'eta_minutes': null,
        'accepted_at': null,
      }).eq('id', request['id']);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Service request cancelled. Owner notified.')),
        );
        // If the cancelled request was displayed on the map, clear the map
        if (_detailedAcceptedRequest?['id'] == request['id']) {
          setState(() {
            _detailedAcceptedRequest = null;
            _clearMap();
          });
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error cancelling request: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    }
  }

  /// Handles marking an accepted service request as completed.
  /// Prompts for confirmation and updates the request status to 'completed'.
  Future<void> _completeServiceRequest(Map<String, dynamic> request) async {
    final String? mechanicId = _currentMechanicId;

    if (mechanicId == null) return;

    bool confirmComplete = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Complete Service?'),
          content: const Text('Mark this service request as completed?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Yes, Complete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmComplete) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
        'mechanic_id': null, // Clear mechanic assignment
        'eta_minutes': null,
        'accepted_at': null,
      }).eq('id', request['id']);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Service request marked as completed.')),
        );
        // If the completed request was displayed on the map, clear the map
        if (_detailedAcceptedRequest?['id'] == request['id']) {
          setState(() {
            _detailedAcceptedRequest = null;
            _clearMap();
          });
        }
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error completing request: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    }
  }

  /// Shows a dialog to get the Estimated Time of Arrival (ETA) from the mechanic.
  Future<int?> _showEtaInputDialog() async {
    TextEditingController etaController = TextEditingController();
    int? eta;
    await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Acceptance & ETA'),
          content: TextField(
            controller: etaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Enter estimated arrival time in minutes',
              labelText: 'ETA (minutes)',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              child: const Text('Accept'),
              onPressed: () {
                final input = int.tryParse(etaController.text.trim());
                if (input != null && input > 0) {
                  eta = input;
                  Navigator.of(dialogContext).pop(eta);
                } else {
                  snackbarKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Please enter a valid positive number for ETA.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
    etaController.dispose();
    return eta;
  }

  // --- Map Utilities ---

  /// Clears all markers, polylines, and accepted request details from the map.
  void _clearMap() {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      _polylines.clear();
      _requesterLocationForMap = null;
      _detailedAcceptedRequest = null;
    });
  }

  /// Displays an accepted request on the map, including mechanic's and requester's locations,
  /// and calculates a route between them using OSRM.
  Future<void> _displayAcceptedRequestOnMap(Map<String, dynamic> request) async {
    if (!mounted || _mechanicLocationForMap == null) return;

    setState(() {
      _isMapLoading = true;
      _markers.clear();
      _polylines.clear();
      _detailedAcceptedRequest = request; // Set the request to be detailed
    });

    try {
      final String requesterLocationString = request['requester_location'];
      // Example: "POINT(121.0505 14.5819)" -> longitude latitude
      final parts = requesterLocationString.substring(6, requesterLocationString.length - 1).split(' ');
      final double lon = double.parse(parts[0]);
      final double lat = double.parse(parts[1]);
      _requesterLocationForMap = LatLng(lat, lon);

      _markers.add(
        Marker(
          key: const Key('requesterLocation'),
          point: _requesterLocationForMap!,
          width: 80,
          height: 80,
          child: const Icon(Icons.location_on, color: Colors.blue, size: 40),
        ),
      );
      _markers.add(
        Marker(
          key: const Key('mechanicCurrentLocation'),
          point: _mechanicLocationForMap!,
          width: 80,
          height: 80,
          child: const Icon(Icons.directions_car, color: Colors.green, size: 40),
        ),
      );

      // Fit map to show both mechanic and requester locations
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([_requesterLocationForMap!, _mechanicLocationForMap!]),
        padding: const EdgeInsets.all(80.0),
      ));

      await _getDirections(_mechanicLocationForMap!, _requesterLocationForMap!);
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to load map for request: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    }
  }

  /// Fetches directions between two LatLng points using the OSRM API
  /// and updates the map with a polyline representing the route.
  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isCalculatingRoute = true;
      _polylines.clear(); // Clear previous polylines
    });

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
          final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];

          List<LatLng> routePoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1], coord[0]); // OSRM returns [longitude, latitude]
          }).toList();

          if (mounted) {
            setState(() {
              _polylines = [
                Polyline(
                  points: routePoints,
                  color: Colors.green,
                  strokeWidth: 5.0,
                ),
              ];
            });
          }
        } else {
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('No route found.'), backgroundColor: Colors.orange),
          );
        }
      } else {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to fetch directions: ${response.reasonPhrase}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Error getting directions: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  // --- UI Widgets ---

  /// Builds a card for a service request, displaying details and action buttons.
  Widget _buildRequestCard(Map<String, dynamic> request, {required bool isPending}) {
    Future<String> getRequesterName(String userId) async {
      try {
        final profile = await supabase.from('profiles').select('full_name').eq('id', userId).single();
        return profile['full_name'] ?? 'Unknown User';
      } catch (e) {
        return 'Unknown User';
      }
    }

    return FutureBuilder<String>(
      future: getRequesterName(request['requester_id']),
      builder: (context, snapshot) {
        String requesterName = snapshot.data ?? 'Loading...';
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasError) {
          requesterName = 'Error User';
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request by: $requesterName',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Status: ${request['status'].toString().toUpperCase()}'),
                if (request['requester_notes'] != null && request['requester_notes'].isNotEmpty)
                  Text('Notes: ${request['requester_notes']}'),
                if (isPending)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptRequest(request),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Accept Request', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  )
                else if (request['status'] == 'accepted')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text('ETA: ${request['eta_minutes']} minutes'),
                      Text('Accepted At: ${DateTime.parse(request['accepted_at']).toLocal().toString().substring(0, 16)}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _cancelAcceptedRequest(request),
                            icon: const Icon(Icons.cancel, color: Colors.white),
                            label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _completeServiceRequest(request),
                            icon: const Icon(Icons.done_all, color: Colors.white),
                            label: const Text('Complete', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _displayAcceptedRequestOnMap(request),
                            icon: const Icon(Icons.map, color: Colors.white),
                            label: const Text('View on Map', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentMechanicId == null || _pendingRequestsStream == null || _acceptedRequestsStream == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Mechanic: ${_mechanicFullName ?? 'Requests'}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          backgroundColor: const Color.fromARGB(233, 214, 251, 250),
          centerTitle: true,
          elevation: 1,
          leading: Builder( // Add a Builder to provide a context for Scaffold.of
            builder: (BuildContext context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.blue), // Hamburger icon
                onPressed: () {
                  Scaffold.of(context).openDrawer(); // Open the drawer
                },
              );
            },
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending Requests', icon: Icon(Icons.access_time)),
              Tab(text: 'My Accepted Services', icon: Icon(Icons.build)),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.message, color: Colors.blue),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ChatListScreen()),
                );
              },
              tooltip: 'Chat List',
            ),
            IconButton(
              icon: const Icon(Icons.person, color: Colors.blue),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AccountScreen()),
                );
              },
              tooltip: 'Account',
            ),
          ],
        ),
        drawer: const app_nav.NavigationDrawer(), // Add the Drawer here
        body: TabBarView(
          children: [
            // Pending Requests Tab
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _pendingRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No pending service requests.'));
                }
                final pendingRequests = snapshot.data!;
                return ListView.builder(
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    return _buildRequestCard(pendingRequests[index], isPending: true);
                  },
                );
              },
            ),

            // My Accepted Services Tab
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _acceptedRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('You have no active accepted service requests.'));
                }
                final acceptedRequests = snapshot.data!;
                return Stack(
                  children: [
                    ListView.builder(
                      itemCount: acceptedRequests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(acceptedRequests[index], isPending: false);
                      },
                    ),
                    // Map overlay for the currently viewed accepted request
                    if (_detailedAcceptedRequest != null && _requesterLocationForMap != null && _mechanicLocationForMap != null)
                      Positioned.fill(
                        child: Card(
                          margin: const EdgeInsets.all(16.0),
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Routing to Request #${_detailedAcceptedRequest!['id'].toString().substring(0, 8)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: _clearMap, // Close map view
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _isMapLoading || _isCalculatingRoute
                                    ? const Center(child: CircularProgressIndicator())
                                    : FlutterMap(
                                        mapController: _mapController,
                                        options: MapOptions(
                                          initialCameraFit: CameraFit.bounds(
                                            bounds: LatLngBounds.fromPoints([_requesterLocationForMap!, _mechanicLocationForMap!]),
                                            padding: const EdgeInsets.all(80.0),
                                          ),
                                          // interactionFlags: InteractiveFlag.all, // Removed direct interactionFlags as it caused an error. Handled by initialCameraFit for now.
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                                            userAgentPackageName: 'com.autofix.app',
                                          ),
                                          MarkerLayer(markers: _markers.toList()),
                                          PolylineLayer(polylines: _polylines),
                                        ],
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _cancelAcceptedRequest(_detailedAcceptedRequest!),
                                      icon: const Icon(Icons.cancel, color: Colors.white),
                                      label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _completeServiceRequest(_detailedAcceptedRequest!),
                                      icon: const Icon(Icons.done_all, color: Colors.white),
                                      label: const Text('Complete', style: TextStyle(color: Colors.white)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
