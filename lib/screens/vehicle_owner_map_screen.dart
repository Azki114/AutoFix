// lib/screens/vehicle_owner_map_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:autofix/screens/chat_screen.dart';
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/account_screen.dart';
import 'dart:async';

class VehicleOwnerMapScreen extends StatefulWidget {
  const VehicleOwnerMapScreen({super.key});

  @override
  State<VehicleOwnerMapScreen> createState() => _VehicleOwnerMapScreenState();
}

class _VehicleOwnerMapScreenState extends State<VehicleOwnerMapScreen> {
  // Map and Location State
  static const LatLng _kDefaultManila = LatLng(14.5995, 120.9842);
  LatLng _currentMapCenter = _kDefaultManila;
  final MapController _mapController = MapController();
  List<Marker> _availableMechanicMarkers = [];
  List<Polyline> _routePolylines = [];
  LatLng? _userCurrentLocation;

  // Loading and Error State
  bool _isLoadingMechanics = true;
  String? _errorMessage;
  bool _isFetchingUserLocation = false;
  bool _isCalculatingRoute = false;

  // User and Service Request State
  String? _currentUserId;
  Map<String, dynamic>? _activeServiceRequest;

  // Subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _serviceRequestSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _mechanicLocationSubscription;

  // --- NEW STATE FOR TRACKING A SINGLE MECHANIC ---
  LatLng? _mechanicShopLocation; // Static shop location
  LatLng? _mechanicLiveLocation; // Dynamic live location

  @override
  void initState() {
    super.initState();
    _initializeUserAndLocation();
  }

  @override
  void dispose() {
    _serviceRequestSubscription?.cancel();
    _mechanicLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeUserAndLocation() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    _currentUserId = user.id;
    await _getCurrentLocation();
    if (!mounted) return;

    _listenForActiveServiceRequests();
    if (_activeServiceRequest == null) {
      _fetchMechanics();
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isFetchingUserLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted || permission == LocationPermission.denied) {
          if (mounted) {
            snackbarKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
            setState(() => _isFetchingUserLocation = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(
                content: Text(
                    'Location permissions are permanently denied, we cannot request permissions.')),
          );
          setState(() => _isFetchingUserLocation = false);
        }
        return;
      }

      Position position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;

      setState(() {
        _userCurrentLocation = LatLng(position.latitude, position.longitude);
        _currentMapCenter = _userCurrentLocation!;
        _isFetchingUserLocation = false;
      });

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _mapController.move(_userCurrentLocation!, 14.0);
      });
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
        setState(() => _isFetchingUserLocation = false);
      }
    }
  }

  void _listenForActiveServiceRequests() {
    if (_currentUserId == null) return;

    _serviceRequestSubscription?.cancel();
    _serviceRequestSubscription = supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', _currentUserId!)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) {
      if (!mounted) return;

      final previousRequestStatus = _activeServiceRequest?['status'];
      Map<String, dynamic>? newActiveRequest;

      if (data.isNotEmpty) {
        final request = data.first;
        if (request['status'] == 'pending' || request['status'] == 'accepted') {
          newActiveRequest = request;
        }
      }

      setState(() {
        _activeServiceRequest = newActiveRequest;
      });

      final newRequestStatus = _activeServiceRequest?['status'];
      final mechanicId = _activeServiceRequest?['mechanic_id'];

      if (newRequestStatus == 'accepted' &&
          previousRequestStatus != 'accepted' &&
          mechanicId != null) {
        _startTrackingMechanic(mechanicId);
      } else if (newRequestStatus != 'accepted' &&
          previousRequestStatus == 'accepted') {
        _stopTrackingMechanic();
      }
    }, onError: (error) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
              content: Text('Error with service request stream: $error')),
        );
      }
    });
  }

  Future<void> _startTrackingMechanic(String mechanicId) async {
    _mechanicLocationSubscription?.cancel();
    if (!mounted) return;

    try {
      final mechanicData = await supabase
          .from('mechanics')
          .select(
              'latitude, longitude, live_latitude, live_longitude, user_id')
          .eq('user_id', mechanicId)
          .single();

      if (!mounted) return;

      final dynamic shopLat = mechanicData['latitude'];
      final dynamic shopLng = mechanicData['longitude'];
      final dynamic liveLat = mechanicData['live_latitude'];
      final dynamic liveLng = mechanicData['live_longitude'];

      if (shopLat is num && shopLng is num && liveLat is num && liveLng is num) {
        setState(() {
          _availableMechanicMarkers.clear();
          _mechanicShopLocation = LatLng(shopLat.toDouble(), shopLng.toDouble());
          _mechanicLiveLocation = LatLng(liveLat.toDouble(), liveLng.toDouble());
        });
      } else {
        debugPrint(
            "Error: Mechanic with ID $mechanicId has invalid or null location data. "
            "ShopLat: $shopLat, ShopLng: $shopLng, LiveLat: $liveLat, LiveLng: $liveLng");
        if (mounted) {
          snackbarKey.currentState?.showSnackBar(const SnackBar(
            content: Text("Could not display mechanic's location. Data is incomplete."),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      _mechanicLocationSubscription = supabase
          .from('mechanics')
          .stream(primaryKey: ['user_id'])
          .eq('user_id', mechanicId)
          .listen((data) {
        if (mounted && data.isNotEmpty) {
          final newLocationData = data.first;
          final dynamic newLiveLat = newLocationData['live_latitude'];
          final dynamic newLiveLng = newLocationData['live_longitude'];

          if (newLiveLat is num && newLiveLng is num) {
            final newLocation =
                LatLng(newLiveLat.toDouble(), newLiveLng.toDouble());
            setState(() {
              _mechanicLiveLocation = newLocation;
            });

            if (_userCurrentLocation != null) {
              _getDirections(_userCurrentLocation!, newLocation);
            }
          } else {
            debugPrint(
                "Received invalid live location update for mechanic ID $mechanicId. Lat: $newLiveLat, Lng: $newLiveLng");
          }
        }
      });
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Error fetching mechanic data: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _stopTrackingMechanic() {
    _mechanicLocationSubscription?.cancel();
    _mechanicLocationSubscription = null;
    if (mounted) {
      setState(() {
        _mechanicShopLocation = null;
        _mechanicLiveLocation = null;
        _routePolylines.clear();
      });
      _fetchMechanics();
    }
  }

  Future<void> _fetchMechanics() async {
    if (!mounted) return;
    setState(() {
      _isLoadingMechanics = true;
      _errorMessage = null;
      _availableMechanicMarkers.clear();
    });

    try {
      final List<Map<String, dynamic>> mechanicsData =
          await supabase.from('mechanics').select('*, profiles!inner(full_name)');

      if (!mounted) return;
      
      final markers = <Marker>[];
      for (var mechanic in mechanicsData) {
        final dynamic lat = mechanic['latitude'];
        final dynamic lng = mechanic['longitude'];
        final String? mechanicId = mechanic['user_id']?.toString();

        if (lat is num && lng is num && mechanicId != null) {
          final String shopName = mechanic['shop_name']?.toString() ??
              mechanic['profiles']['full_name']?.toString() ??
              'Unknown Shop';
          markers.add(
            Marker(
              key: Key('mechanic_$mechanicId'),
              point: LatLng(lat.toDouble(), lng.toDouble()),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  _showMechanicDetails(
                    context,
                    mechanicId,
                    shopName,
                    LatLng(lat.toDouble(), lng.toDouble()),
                    mechanic['business_address']?.toString() ?? 'N/A',
                    mechanic['specialties']?.toString() ?? 'N/A',
                    mechanic['certifications']?.toString() ?? 'N/A',
                    mechanic['years_experience']?.toString() ?? 'N/A',
                    mechanic['base_rate_php']?.toString() ?? 'N/A',
                    mechanic['pricing_unit']?.toString() ?? 'N/A',
                    mechanic['minimum_charge_php']?.toString() ?? 'N/A',
                    mechanic['service_radius_km']?.toString() ?? 'N/A',
                  );
                },
                child: const Icon(
                  Icons.build_circle,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          );
        } else {
            debugPrint( "Skipping mechanic with ID ${mechanic['user_id']} due to invalid location data.");
        }
      }

      setState(() {
        _availableMechanicMarkers = markers;
        _isLoadingMechanics = false;
        if (_availableMechanicMarkers.isEmpty) {
          _errorMessage = 'No mechanics found.';
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching mechanics: $e';
          _isLoadingMechanics = false;
        });
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Marker> _buildMapMarkers() {
    final List<Marker> markers = [];
    if (_userCurrentLocation != null) {
      markers.add(Marker(
        key: const Key('userLocation'),
        point: _userCurrentLocation!,
        width: 80,
        height: 80,
        child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
      ));
    }

    if (_activeServiceRequest != null && _activeServiceRequest!['status'] == 'accepted') {
        if(_mechanicShopLocation != null) {
             markers.add(Marker(
                key: const Key('mechanicShop'),
                point: _mechanicShopLocation!,
                width: 80,
                height: 80,
                child: const Icon(Icons.store, color: Colors.red, size: 40),
             ));
        }
        if(_mechanicLiveLocation != null) {
            markers.add(Marker(
                key: const Key('mechanicLive'),
                point: _mechanicLiveLocation!,
                width: 80,
                height: 80,
                child: const Icon(Icons.directions_car_filled, color: Colors.orange, size: 40),
            ));
        }
    } else {
      markers.addAll(_availableMechanicMarkers);
    }
    
    return markers;
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isCalculatingRoute = true;
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
              _mapController.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routePoints),
                padding: const EdgeInsets.all(50.0),
              ));
            });
          }
        } else {
          if (mounted) {
            snackbarKey.currentState?.showSnackBar(const SnackBar(
                content: Text('No route found.'),
                backgroundColor: Colors.orange));
          }
        }
      } else {
        if (mounted) {
          snackbarKey.currentState?.showSnackBar(SnackBar(
              content: Text('Failed to fetch directions: ${response.reasonPhrase}'),
              backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Error getting directions: $e'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  Future<void> _findOrCreateChat(
      BuildContext context, String mechanicId, String mechanicName) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(
            content: Text('You must be logged in to start a chat.'),
            backgroundColor: Colors.red));
      }
      return;
    }
    final driverId = currentUser.id;
    try {
      final existingChats = await supabase
          .from('chats')
          .select('id')
          .eq('driver_id', driverId)
          .eq('mechanic_id', mechanicId)
          .limit(1);
      if (!mounted) return;
      String chatId;
      if (existingChats.isNotEmpty) {
        chatId = existingChats.first['id'] as String;
        if (mounted) {
          snackbarKey.currentState
              ?.showSnackBar(SnackBar(content: Text('Resuming chat with $mechanicName')));
        }
      } else {
        final newChat = await supabase.from('chats').insert({
          'driver_id': driverId,
          'mechanic_id': mechanicId,
          'status': 'active',
        }).select('id').single();
        if (!mounted) return;
        chatId = newChat['id'] as String;
        if (mounted) {
          snackbarKey.currentState?.showSnackBar(
              SnackBar(content: Text('New chat started with $mechanicName!')));
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatPartnerName: mechanicName,
              currentUserId: driverId,
              chatPartnerId: mechanicId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showMechanicDetails(
      BuildContext context,
      String mechanicId,
      String shopName,
      LatLng mechanicLocation,
      String address,
      String specialties,
      String certifications,
      String yearsExperience,
      String baseRate,
      String pricingUnit,
      String minimumCharge,
      String serviceRadius) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Address: $address'),
                Text('Specialties: $specialties'),
                Text('Certifications: $certifications'),
                Text('Years Experience: $yearsExperience'),
                Text('Base Rate: ₱$baseRate per $pricingUnit'),
                Text('Minimum Charge: ₱$minimumCharge'),
                Text('Service Radius: $serviceRadius km'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Get Directions'),
              onPressed: () {
                Navigator.of(context).pop();
                if (_userCurrentLocation != null) {
                  _getDirections(_userCurrentLocation!, mechanicLocation);
                } else if (mounted) {
                  snackbarKey.currentState?.showSnackBar(const SnackBar(
                      content: Text('Cannot get directions: Your current location is not available.'),
                      backgroundColor: Colors.orange));
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () {
                Navigator.of(context).pop();
                _requestService();
              },
              child: const Text('REQUEST SERVICE'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Chat with Mechanic'),
              onPressed: () => _findOrCreateChat(context, mechanicId, shopName),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestService() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    if (_userCurrentLocation == null || _currentUserId == null) {
      if (mounted) {
        Navigator.of(context).pop();
        snackbarKey.currentState?.showSnackBar(const SnackBar(
            content: Text(
                'Could not get your current location or user ID. Please ensure location services are enabled.')));
      }
      return;
    }

    if (_activeServiceRequest != null) {
      if (mounted) {
        Navigator.of(context).pop();
        snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('You already have an active service request.')));
      }
      return;
    }

    try {
      String? notes = await _showNotesDialog();
      if (!mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }
      
      if (notes == null) {
        Navigator.of(context).pop();
        if (mounted) {
          snackbarKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Service request cancelled by user.')));
        }
        return;
      }

      final newRequest = await supabase.from('service_requests').insert({
        'requester_id': _currentUserId,
        'requester_location':
            'POINT(${_userCurrentLocation!.longitude} ${_userCurrentLocation!.latitude})',
        'requester_notes': notes,
        'status': 'pending',
      }).select().single();

      if (!mounted) {
         Navigator.of(context, rootNavigator: true).pop();
         return;
      }
      
      setState(() => _activeServiceRequest = newRequest);
      Navigator.of(context).pop();
      snackbarKey.currentState?.showSnackBar(const SnackBar(
          content: Text('Service request sent! Waiting for a mechanic.')));
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Error sending service request: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _showNotesDialog() async {
    final notesController = TextEditingController();
    String? notes;
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Request Service'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(
                hintText: 'Describe your vehicle issue (optional)'),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                notes = null;
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Send Request'),
              onPressed: () {
                notes = notesController.text.trim();
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
    notesController.dispose();
    return notes;
  }

  Future<void> _cancelServiceRequest() async {
    if (_activeServiceRequest == null) {
      if (mounted) {
        snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('No active service request to cancel.')));
      }
      return;
    }

    bool confirmCancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Request?'),
          content: const Text('Are you sure you want to cancel your service request?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmCancel || !mounted) return;

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled',
        'cancelled_by': _currentUserId,
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': 'Cancelled by vehicle owner',
      }).eq('id', _activeServiceRequest!['id']);

      if (mounted) {
        snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Service request cancelled successfully.')));
        _stopTrackingMechanic();
      }
    } catch (e) {
       if (mounted) {
        snackbarKey.currentState?.showSnackBar(SnackBar(
            content: Text('Error cancelling service request: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<String> _getMechanicName(String? mechanicId) async {
    if (mechanicId == null) return 'N/A';
    try {
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', mechanicId)
          .single();
      if (!mounted) return 'N/A';
      return profile['full_name'] ?? 'Unknown Mechanic';
    } catch (e) {
      return 'Unknown Mechanic';
    }
  }

  void _showServiceRequestStatusSheet() {
    if (_activeServiceRequest == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 5, margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
              Text(
                'Service Request Status: ${_activeServiceRequest!['status'].toString().toUpperCase()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              if (_activeServiceRequest!['status'] == 'accepted') ...[
                const SizedBox(height: 10),
                Text(
                  'Mechanic ETA: ${_activeServiceRequest!['eta_minutes'] ?? 'N/A'} minutes',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                FutureBuilder<String>(
                  future: _getMechanicName(_activeServiceRequest!['mechanic_id']),
                  builder: (context, snapshot) {
                    return Text(
                      'Mechanic: ${snapshot.data ?? 'Loading...'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    );
                  },
                ),
              ] else if (_activeServiceRequest!['status'] == 'pending') ...[
                const SizedBox(height: 10),
                const Text('Waiting for a mechanic to accept...', style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _cancelServiceRequest();
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Map', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
        leading: Builder(builder: (BuildContext context) {
          return IconButton(
            icon: const Icon(Icons.menu, color: Colors.blue),
            onPressed: () => Scaffold.of(context).openDrawer(),
          );
        }),
        actions: [
          if (_activeServiceRequest != null)
            IconButton(
              key: const ValueKey('activeServiceIndicator'),
              icon: const Icon(Icons.info, color: Colors.green),
              onPressed: _showServiceRequestStatusSheet,
              tooltip: 'Active Request: ${_activeServiceRequest!['status'].toString().toUpperCase()}',
            ),
          IconButton(
            key: const ValueKey('chatListButton'),
            icon: const Icon(Icons.message, color: Colors.blue),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ChatListScreen())),
            tooltip: 'Chat List',
          ),
          IconButton(
            key: const ValueKey('accountButton'),
            icon: const Icon(Icons.person, color: Colors.blue),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AccountScreen())),
            tooltip: 'Account',
          ),
        ],
      ),
      drawer: const app_nav.NavigationDrawer(),
      body: _isLoadingMechanics || _isFetchingUserLocation
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Retry', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          _initializeUserAndLocation();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentMapCenter,
                        initialZoom: 12.0,
                        minZoom: 2.0,
                        maxZoom: 18.0,
                        onPositionChanged: (pos, hasGesture) {
                          if (mounted) _currentMapCenter = pos.center!;
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                          userAgentPackageName: 'com.autofix.app',
                        ),
                        PolylineLayer(polylines: _routePolylines),
                        MarkerLayer(markers: _buildMapMarkers()),
                      ],
                    ),
                    if (_isCalculatingRoute)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                      ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'recenterMap',
            onPressed: () {
              if (mounted && _userCurrentLocation != null) {
                _mapController.move(_userCurrentLocation!, 14.0);
              }
            },
            backgroundColor: Colors.blue,
            child: _isFetchingUserLocation
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 10),
          if (_routePolylines.isNotEmpty)
            FloatingActionButton(
              heroTag: 'clearRoute',
              onPressed: () {
                if (mounted) {
                  setState(() => _routePolylines.clear());
                  snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Route cleared.')));
                }
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.clear, color: Colors.white),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

