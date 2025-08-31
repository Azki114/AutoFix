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
  static const LatLng _kDefaultManila = LatLng(14.5995, 120.9842);
  LatLng _currentMapCenter = _kDefaultManila;
  final MapController _mapController = MapController();
  final Set<Marker> _allMapMarkers = {};
  bool _isLoadingMechanics = true;
  String? _errorMessage;
  LatLng? _userCurrentLocation;
  bool _isFetchingUserLocation = false;
  List<Polyline> _routePolylines = [];
  bool _isCalculatingRoute = false;
  String? _currentUserId;
  Map<String, dynamic>? _activeServiceRequest;
  StreamSubscription<List<Map<String, dynamic>>>? _serviceRequestSubscription;

  @override
  void initState() {
    super.initState();
    _initializeUserAndLocation();
    _fetchMechanics();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _serviceRequestSubscription?.cancel(); // Cancel the subscription
    super.dispose();
  }

  Future<void> _initializeUserAndLocation() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) { // Check mounted before showing SnackBar and navigating
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('User not logged in.')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }
    _currentUserId = user.id;
    await _getCurrentLocation();
    // After _getCurrentLocation, check mounted again before proceeding
    if (!mounted) return;
    _listenForActiveServiceRequests();
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
        if (!mounted) return;

        if (permission == LocationPermission.denied) {
          if (mounted) { // Check mounted before SnackBar
            snackbarKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
            setState(() {
              _isFetchingUserLocation = false;
            });
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
          );
          setState(() {
            _isFetchingUserLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;

      setState(() {
        _userCurrentLocation = LatLng(position.latitude, position.longitude);
        _currentMapCenter = _userCurrentLocation!;

        _allMapMarkers.add(
          Marker(
            key: const Key('userLocation'),
            point: _userCurrentLocation!,
            width: 80,
            height: 80,
            child: const Icon(
              Icons.my_location,
              color: Colors.blue,
              size: 40,
            ),
          ),
        );

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _mapController.move(_userCurrentLocation!, 14.0);
          }
        });

        _isFetchingUserLocation = false;
      });
    } catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to get current location: ${e.toString()}')),
        );
        setState(() {
          _isFetchingUserLocation = false;
        });
      }
    }
  }

  void _listenForActiveServiceRequests() {
    final String? userId = _currentUserId;
    if (userId == null) {
      return;
    }

    // Cancel existing subscription if any to prevent multiple listeners
    _serviceRequestSubscription?.cancel();

    _serviceRequestSubscription = supabase
        .from('service_requests')
        .stream(primaryKey: ['id'])
        .eq('requester_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .listen((data) async {
      if (!mounted) return; // Crucial check in listener callbacks

      setState(() {
        if (data.isNotEmpty) {
          final request = data.first;
          if (request['status'] == 'pending' || request['status'] == 'accepted') {
            _activeServiceRequest = request;
          } else {
            _activeServiceRequest = null;
          }
        } else {
          _activeServiceRequest = null;
        }
      });
      await _updateMarkersBasedOnServiceRequest();
    }, onError: (error) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error updating service request status: ${error.toString()}')),
        );
      }
    });
  }

  Future<void> _updateMarkersBasedOnServiceRequest() async {
    _allMapMarkers.removeWhere((marker) => marker.key == const Key('activeMechanicLocation'));
    _routePolylines.clear();

    if (_activeServiceRequest != null && _activeServiceRequest!['status'] == 'accepted' && _activeServiceRequest!['mechanic_id'] != null) {
      final String mechanicId = _activeServiceRequest!['mechanic_id'];
      try {
        final mechanicData = await supabase
            .from('mechanics')
            .select('latitude, longitude, profiles(full_name)')
            .eq('user_id', mechanicId)
            .single();

        if (!mounted) return; // Check mounted after async call

        final double? lat = mechanicData['latitude'];
        final double? lng = mechanicData['longitude'];
        final String? mechanicName = mechanicData['profiles']['full_name'];

        if (lat != null && lng != null) {
          final mechanicLocation = LatLng(lat, lng);
          if (mounted) {
            setState(() {
              _allMapMarkers.add(
                Marker(
                  key: const Key('activeMechanicLocation'),
                  point: mechanicLocation,
                  width: 80,
                  height: 80,
                  child: Icon(
                    Icons.directions_car_filled,
                    color: Colors.orange,
                    size: 40,
                    semanticLabel: 'Active Mechanic: $mechanicName',
                  ),
                ),
              );
              if (_userCurrentLocation != null) {
                _mapController.fitCamera(CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints([_userCurrentLocation!, mechanicLocation]),
                  padding: const EdgeInsets.all(80.0),
                ));
                _getDirections(_userCurrentLocation!, mechanicLocation);
              } else {
                _mapController.move(mechanicLocation, 15.0);
              }
            });
          }
        }
      } on PostgrestException catch (e) {
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('Error fetching active mechanic: ${e.message}'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('Unexpected error fetching active mechanic: ${e.toString()}'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _fetchMechanics() async {
    if (!mounted) return;

    setState(() {
      _isLoadingMechanics = true;
      _errorMessage = null;
      _allMapMarkers.removeWhere((marker) => marker.key != const Key('userLocation') && marker.key != const Key('activeMechanicLocation'));
    });

    try {
      final List<Map<String, dynamic>> mechanicsData = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)');

      if (!mounted) return; // Check mounted after async call

      for (var mechanic in mechanicsData) {
        final double? lat = mechanic['latitude'];
        final double? lng = mechanic['longitude'];
        final String? mechanicIdRaw = mechanic['user_id']?.toString();

        if (lat == null || lng == null || mechanicIdRaw == null || mechanicIdRaw.isEmpty) {
          continue;
        }

        final String mechanicId = mechanicIdRaw;

        final String shopName = (mechanic['shop_name']?.toString() ??
            (mechanic['profiles'] is Map<String, dynamic>
                ? mechanic['profiles']['full_name']?.toString()
                : null)) ?? 'Unknown Shop';

        final String businessAddress = mechanic['business_address']?.toString() ?? 'Address not available';
        final String specialtiesString = (mechanic['specialties']?.toString().isNotEmpty == true)
            ? mechanic['specialties'].toString()
            : 'No specialties listed';
        final String certificationsString = (mechanic['certifications']?.toString().isNotEmpty == true)
            ? mechanic['certifications'].toString()
            : 'No certifications listed';
        final String yearsExperience = mechanic['years_experience']?.toString() ?? 'N/A';
        final String baseRatePhp = mechanic['base_rate_php']?.toString() ?? 'N/A';
        final String pricingUnit = mechanic['pricing_unit']?.toString() ?? 'N/A';
        final String minimumChargePhp = mechanic['minimum_charge_php']?.toString() ?? 'N/A';
        final String serviceRadiusKm = mechanic['service_radius_km']?.toString() ?? 'N/A';

        if (mounted) { // Check mounted before setState (implicit by adding to set which rebuilds)
          _allMapMarkers.add(
            Marker(
              key: Key('mechanic_$mechanicId'),
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  _showMechanicDetails(
                    context,
                    mechanicId,
                    shopName,
                    LatLng(lat, lng),
                    businessAddress,
                    specialtiesString,
                    certificationsString,
                    yearsExperience,
                    baseRatePhp,
                    pricingUnit,
                    minimumChargePhp,
                    serviceRadiusKm,
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
        }
      }

      if (mounted) { // Check mounted before setState
        setState(() {
          _isLoadingMechanics = false;
          if (_allMapMarkers.length <= ((_userCurrentLocation != null ? 1 : 0) + (_activeServiceRequest != null ? 1 : 0))) {
            _errorMessage = 'No mechanics found or loaded. Check your database IDs (should be user_id).';
          } else {
            _errorMessage = null;
          }
        });
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Database error: ${e.message}';
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoadingMechanics = false;
        });
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
        );
        setState(() {
          _isLoadingMechanics = false;
        });
      }
    }
  }

  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isCalculatingRoute = true;
      _routePolylines.clear();
    });

    final String osrmApiUrl =
        'http://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(osrmApiUrl));
      if (!mounted) return; // Check mounted after async call

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];

          List<LatLng> routePoints = coordinates.map<LatLng>((coord) {
            return LatLng(coord[1], coord[0]);
          }).toList();

          if (mounted) { // Check mounted before setState
            setState(() {
              _routePolylines = [
                Polyline(
                  points: routePoints,
                  color: Colors.blueAccent,
                  strokeWidth: 5.0,
                ),
              ];
              _mapController.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routePoints),
                padding: const EdgeInsets.all(50.0),
              ));
            });
          }
        } else {
          if (mounted) { // Check mounted before SnackBar
            snackbarKey.currentState?.showSnackBar(
              const SnackBar(content: Text('No route found.'), backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('Failed to fetch directions: ${response.reasonPhrase}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error getting directions: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) { // Check mounted before setState in finally block
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  Future<void> _findOrCreateChat(BuildContext context, String mechanicId, String mechanicName) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You must be logged in to start a chat.'), backgroundColor: Colors.red),
        );
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

      if (!mounted) return; // Check mounted after async call

      String chatId;
      if (existingChats.isNotEmpty) {
        chatId = existingChats.first['id'] as String;
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('Resuming chat with $mechanicName')),
          );
        }
      } else {
        final newChat = await supabase.from('chats').insert({
          'driver_id': driverId,
          'mechanic_id': mechanicId,
          'status': 'active',
        }).select('id').single();

        if (!mounted) return; // Check mounted after async call

        chatId = newChat['id'] as String;
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            SnackBar(content: Text('New chat started with $mechanicName!')),
          );
        }
      }

      if (mounted) { // Final check before navigation
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        Navigator.push(
          // ignore: use_build_context_synchronously
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
    } on PostgrestException catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to start chat: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Failed to start chat: ${e.toString()}'), backgroundColor: Colors.red),
        );
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
      String serviceRadius,
      ) {
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
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Get Directions'),
              onPressed: () {
                Navigator.of(context).pop();
                if (_userCurrentLocation != null) {
                  _getDirections(_userCurrentLocation!, mechanicLocation);
                } else {
                  if (mounted) { // Check mounted before SnackBar
                    snackbarKey.currentState?.showSnackBar(
                      const SnackBar(content: Text('Cannot get directions: Your current location is not available.'), backgroundColor: Colors.orange),
                    );
                  }
                }
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Chat with Mechanic'),
              onPressed: () {
                _findOrCreateChat(context, mechanicId, shopName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestService() async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User must not dismiss manually
      builder: (dialogContext) => const Center(child: CircularProgressIndicator()),
    );

    if (_userCurrentLocation == null || _currentUserId == null) {
      if (mounted) { // Check mounted before dismissing dialog and showing SnackBar
        Navigator.of(context).pop(); // Dismiss loading dialog
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Could not get your current location or user ID. Please ensure location services are enabled.')),
        );
      }
      return;
    }

    if (_activeServiceRequest != null) {
      if (mounted) { // Check mounted before dismissing dialog and showing SnackBar
        Navigator.of(context).pop(); // Dismiss loading dialog
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('You already have an active service request.')),
        );
      }
      return;
    }

    try {
      String? notes = await _showNotesDialog();
      if (!mounted) { // Check mounted after dialog, before pop and further async work
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // Dismiss dialog if we somehow became unmounted here
        return;
      }

      if (notes == null) { // User cancelled the notes dialog
        Navigator.of(context).pop(); // Dismiss loading dialog
        if (mounted) { // Check mounted before SnackBar
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Service request cancelled by user.')),
          );
        }
        return;
      }

      final newRequest = await supabase.from('service_requests').insert({
        'requester_id': _currentUserId,
        'requester_location': 'POINT(${_userCurrentLocation!.longitude} ${_userCurrentLocation!.latitude})',
        'requester_notes': notes,
        'status': 'pending',
      }).select().single();

      if (!mounted) { // Crucial check after the Supabase call
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(); // Dismiss loading dialog even if unmounted
        return;
      }

      // If still mounted, update state and show success
      setState(() {
        _activeServiceRequest = newRequest;
      });
      Navigator.of(context).pop(); // Dismiss loading dialog
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Service request sent! Waiting for a mechanic.')),
      );
    } on PostgrestException catch (e) {
      if (mounted) { // Check mounted before dismissing dialog and SnackBar
        Navigator.of(context).pop(); // Dismiss loading dialog
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error sending service request: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) { // Check mounted before dismissing dialog and SnackBar
        Navigator.of(context).pop(); // Dismiss loading dialog
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    }
  }


  Future<String?> _showNotesDialog() async {
    String? notes;
    TextEditingController notesController = TextEditingController();
    await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Request Service'),
          content: TextField(
            controller: notesController,
            decoration: const InputDecoration(
              hintText: 'Describe your vehicle issue (optional)',
            ),
            maxLines: 3,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
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
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('No active service request to cancel.')),
        );
      }
      return;
    }

    bool confirmCancel = await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Request?'),
          content: const Text('Are you sure you want to cancel your service request?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            ElevatedButton(
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmCancel) {
      return;
    }

    try {
      await supabase.from('service_requests').update({
        'status': 'cancelled',
        'cancelled_by': _currentUserId,
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancel_reason': 'Cancelled by vehicle owner',
      }).eq('id', _activeServiceRequest!['id']);

      if (mounted) { // Crucial check after Supabase call
        setState(() {
          _activeServiceRequest = null;
          _allMapMarkers.removeWhere((marker) => marker.key == const Key('activeMechanicLocation'));
          _routePolylines.clear();
        });
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Service request cancelled successfully.')),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error cancelling service request: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) { // Check mounted before SnackBar
        snackbarKey.currentState?.showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
        );
      }
    }
  }

  Future<String> _getMechanicName(String? mechanicId) async {
    if (mechanicId == null) return 'N/A';
    try {
      final profile = await supabase.from('profiles').select('full_name').eq('id', mechanicId).single();
      if (!mounted) return 'N/A'; // Check mounted after async call
      return profile['full_name'] ?? 'Unknown Mechanic';
    } catch (e) {
      print('Error fetching mechanic name: $e');
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
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'Service Request Status: ${_activeServiceRequest!['status'].toString().toUpperCase()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Mechanic: Loading...', style: TextStyle(fontSize: 14, color: Colors.grey));
                    }
                    if (snapshot.hasError) {
                      return const Text('Mechanic: Error', style: TextStyle(fontSize: 14, color: Colors.red));
                    }
                    return Text(
                      'Mechanic: ${snapshot.data ?? 'N/A'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    );
                  },
                ),
              ] else if (_activeServiceRequest!['status'] == 'pending') ...[
                const SizedBox(height: 10),
                const Text(
                  'Waiting for a mechanic to accept...',
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Dismiss the bottom sheet first
                    _cancelServiceRequest();
                  },
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
        title: const Text('Vehicle Owner Map',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu, color: Colors.blue),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
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
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              );
            },
            tooltip: 'Chat List',
          ),
          IconButton(
            key: const ValueKey('accountButton'),
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
                _fetchMechanics();
                _getCurrentLocation();
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
                if (mounted) {
                  _currentMapCenter = pos.center;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.autofix.app',
              ),
              MarkerLayer(
                markers: _allMapMarkers.toList(),
              ),
              PolylineLayer(
                polylines: _routePolylines,
              ),
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
              if (mounted) {
                _mapController.move(
                  _userCurrentLocation ?? _kDefaultManila,
                  14.0,
                );
                setState(() {
                  _routePolylines.clear();
                  _allMapMarkers.removeWhere((marker) => marker.key == const Key('activeMechanicLocation'));
                });
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
                  setState(() {
                    _routePolylines.clear();
                  });
                  snackbarKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Route cleared.')),
                  );
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
