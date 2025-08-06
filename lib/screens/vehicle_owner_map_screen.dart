// lib/screens/vehicle_owner_map_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng for flutter_map
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:geolocator/geolocator.dart'; // For fetching user's current location

class VehicleOwnerMapScreen extends StatefulWidget {
  const VehicleOwnerMapScreen({super.key});

  @override
  State<VehicleOwnerMapScreen> createState() => _VehicleOwnerMapScreenState();
}

class _VehicleOwnerMapScreenState extends State<VehicleOwnerMapScreen> {
  static const LatLng _kDefaultManila = LatLng(14.5995, 120.9842);
  LatLng _currentMapCenter = _kDefaultManila;

  final MapController _mapController = MapController();

  List<Marker> _mechanicMarkers = [];
  bool _isLoadingMechanics = true;
  String? _errorMessage;

  LatLng? _userCurrentLocation;
  bool _isFetchingUserLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchMechanics();
    // Delay getting current location until after the first frame,
    // ensuring FlutterMap has been rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose(); // Dispose the controller when the widget is removed
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingUserLocation = true;
    });
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          setState(() {
            _isFetchingUserLocation = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
        );
        setState(() {
          _isFetchingUserLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userCurrentLocation = LatLng(position.latitude, position.longitude);
        _currentMapCenter = _userCurrentLocation!; // Center map on user's location
        // Move map directly as addPostFrameCallback ensures it's rendered
        _mapController.move(_userCurrentLocation!, 14.0);
        _isFetchingUserLocation = false;
      });
    } catch (e) {
      print('Error getting user location: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to get current location: ${e.toString()}')),
      );
      setState(() {
        _isFetchingUserLocation = false;
      });
    }
  }

  Future<void> _fetchMechanics() async {
    setState(() {
      _isLoadingMechanics = true;
      _errorMessage = null;
      _mechanicMarkers.clear();
    });

    try {
      final List<Map<String, dynamic>> mechanicsData = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)');

      List<Marker> newMarkers = [];

      if (_userCurrentLocation != null) {
        newMarkers.add(
          Marker(
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
      }

      for (var mechanic in mechanicsData) {
        final double? lat = mechanic['latitude'];
        final double? lng = mechanic['longitude'];
        final String? shopName = mechanic['shop_name'] ?? mechanic['profiles']['full_name'] ?? 'Unknown Shop';
        final String? businessAddress = mechanic['business_address'] ?? 'Address not available';
        final String specialtiesString = mechanic['specialties'] != null && (mechanic['specialties'] as String).isNotEmpty
            ? mechanic['specialties'] as String
            : 'No specialties listed';

        final String certificationsString = mechanic['certifications'] != null && (mechanic['certifications'] as String).isNotEmpty
            ? mechanic['certifications'] as String
            : 'No certifications listed';


        if (lat != null && lng != null) {
          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () {
                  _showMechanicDetails(
                    context,
                    shopName!,
                    businessAddress!,
                    specialtiesString,
                    certificationsString,
                    mechanic['years_experience']?.toString() ?? 'N/A',
                    mechanic['base_rate_php']?.toString() ?? 'N/A',
                    mechanic['pricing_unit'] ?? 'N/A',
                    mechanic['minimum_charge_php']?.toString() ?? 'N/A',
                    mechanic['service_radius_km']?.toString() ?? 'N/A',
                  );
                },
                child: const Icon(
                  Icons.build_circle, // Icon for a mechanic
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ),
          );
        }
      }

      setState(() {
        _mechanicMarkers = newMarkers;
        _isLoadingMechanics = false;
      });
    } on PostgrestException catch (e) {
      _errorMessage = 'Database error: ${e.message}';
      print('Error fetching mechanics: ${e.message}');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoadingMechanics = false;
      });
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      print('Unexpected error fetching mechanics: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoadingMechanics = false;
      });
    }
  }

  void _showMechanicDetails(
    BuildContext context,
    String shopName,
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
              child: const Text('Request Service'),
              onPressed: () {
                Navigator.of(context).pop();
                snackbarKey.currentState?.showSnackBar(
                  const SnackBar(content: Text('Service request functionality coming soon!')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanics Near You',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
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
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentMapCenter,
                    initialZoom: 12.0,
                    minZoom: 2.0,
                    maxZoom: 18.0,
                    onPositionChanged: (pos, hasGesture) {
                      _currentMapCenter = pos.center; // Removed unnecessary null check
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.autofix.app',
                    ),
                    MarkerLayer(
                      markers: _mechanicMarkers,
                    ),
                  ],
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'recenterMap',
            onPressed: () {
              _mapController.move(
                _userCurrentLocation ?? _kDefaultManila,
                14.0,
              );
            },
            backgroundColor: Colors.blue,
            child: _isFetchingUserLocation
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 10),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
