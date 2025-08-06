// lib/screens/vehicle_owner_map_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng for flutter_map
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:geolocator/geolocator.dart'; // For fetching user's current location

class VehicleOwnerMapScreen extends StatefulWidget { // Renamed class here
  const VehicleOwnerMapScreen({super.key});

  @override
  State<VehicleOwnerMapScreen> createState() => _VehicleOwnerMapScreenState();
}

class _VehicleOwnerMapScreenState extends State<VehicleOwnerMapScreen> {
  // Initial camera position for Manila, Philippines (example coordinates)
  static const LatLng _kDefaultManila = LatLng(14.5995, 120.9842);
  LatLng _currentMapCenter = _kDefaultManila; // Tracks the center of the map view

  // MapController for controlling the map programmatically
  final MapController _mapController = MapController();

  // List to store map markers (flutter_map uses a list of Marker widgets)
  List<Marker> _mechanicMarkers = [];
  bool _isLoadingMechanics = true;
  String? _errorMessage;

  // User's current location
  LatLng? _userCurrentLocation;
  bool _isFetchingUserLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchMechanics(); // Fetch mechanics when the screen initializes
    _getCurrentLocation(); // Attempt to get user's current location
  }

  // Function to get the user's current location
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
        _mapController.move(_userCurrentLocation!, 14.0); // Move map to user's location
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

  // Function to fetch mechanic data from Supabase
  Future<void> _fetchMechanics() async {
    setState(() {
      _isLoadingMechanics = true;
      _errorMessage = null;
      _mechanicMarkers.clear(); // Clear existing markers
    });

    try {
      // Fetch mechanics data. Join with profiles to get full_name
      // The schema shows 'shop_name' directly in 'mechanics' table, and 'full_name' in 'profiles'.
      final List<Map<String, dynamic>> mechanicsData = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)'); // Use !inner to ensure profile exists

      List<Marker> newMarkers = [];

      // Add user's current location marker if available
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
        // Prioritize shop_name from mechanics table, fallback to full_name from profiles
        final String? shopName = mechanic['shop_name'] ?? mechanic['profiles']['full_name'] ?? 'Unknown Shop';
        final String? businessAddress = mechanic['business_address'] ?? 'Address not available';
        // Certifications and specialties are stored as text (comma-separated)
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

  // Function to show mechanic details in an AlertDialog
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
                // Add more details as needed
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
            // You can add a "Contact Mechanic" or "Request Service" button here
            TextButton(
              child: const Text('Request Service'),
              onPressed: () {
                // TODO: Implement service request logic
                Navigator.of(context).pop(); // Close dialog
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
      drawer: const app_nav.NavigationDrawer(), // Your NavigationDrawer
      body: _isLoadingMechanics || _isFetchingUserLocation
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner
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
                  mapController: _mapController, // Assign the controller
                  options: MapOptions(
                    initialCenter: _currentMapCenter, // Center the map on user's location or default
                    initialZoom: 12.0, // Initial zoom level
                    minZoom: 2.0, // Minimum zoom level
                    maxZoom: 18.0, // Maximum zoom level
                    onPositionChanged: (pos, hasGesture) {
                      // Update current map center when user drags the map
                      // Removed unnecessary null check for pos.center
                      if (pos.center != _currentMapCenter) { // Only update if center actually changed
                        _currentMapCenter = pos.center;
                      }
                    },
                  ),
                  children: [
                    // OpenStreetMap Tile Layer
                    TileLayer(
                      urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                      // It's good practice to provide a user agent
                      userAgentPackageName: 'com.autofix.app', // Replace with your actual package name
                    ),
                    // Add Marker Layer to display custom markers
                    MarkerLayer(
                      markers: _mechanicMarkers, // Pass the list of markers
                    ),
                    // You can add more layers here, e.g., PolygonLayer, PolylineLayer
                  ],
                ),
      // Optional: FloatingActionButton to recenter map or add new features
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'recenterMap', // Unique tag for multiple FABs
            onPressed: () {
              // Animate camera back to user's location or default Manila
              _mapController.move(
                _userCurrentLocation ?? _kDefaultManila,
                14.0, // Zoom closer to the user
              );
            },
            backgroundColor: Colors.blue,
            child: _isFetchingUserLocation
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // You could add another FAB here for "Filter Mechanics" etc.
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
