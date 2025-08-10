// lib/screens/vehicle_owner_map_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng for flutter_map
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:geolocator/geolocator.dart'; // For fetching user's current location
import 'package:http/http.dart' as http; // Import for making HTTP requests
import 'dart:convert'; // For JSON encoding/decoding

class VehicleOwnerMapScreen extends StatefulWidget {
  const VehicleOwnerMapScreen({super.key});

  @override
  State<VehicleOwnerMapScreen> createState() => _VehicleOwnerMapScreenState();
}

class _VehicleOwnerMapScreenState extends State<VehicleOwnerMapScreen> {
  // Default map center for Manila, Philippines (example coordinates)
  static const LatLng _kDefaultManila = LatLng(14.5995, 120.9842);
  LatLng _currentMapCenter = _kDefaultManila;

  // MapController for programmatic map control
  final MapController _mapController = MapController();

  // List to store map markers (mechanics)
  List<Marker> _mechanicMarkers = [];
  bool _isLoadingMechanics = true;
  String? _errorMessage;

  // User's current location
  LatLng? _userCurrentLocation;
  bool _isFetchingUserLocation = false;

  // Polyline to draw the route on the map
  List<Polyline> _routePolylines = [];
  bool _isCalculatingRoute = false; // New state for route calculation loading

  @override
  void initState() {
    super.initState();
    // Fetch mechanics data first
    _fetchMechanics();

    // Delay getting current location until after the first frame.
    // This ensures the FlutterMap widget has been built at least once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _mapController.dispose(); // Dispose the controller when the widget is removed
    super.dispose();
  }

  // Function to get the user's current location
  Future<void> _getCurrentLocation() async {
    if (!mounted) return; // Check if widget is still mounted

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
          snackbarKey.currentState?.showSnackBar(
            const SnackBar(content: Text('Location permissions are denied.')),
          );
          if (mounted) {
            setState(() {
              _isFetchingUserLocation = false;
            });
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        snackbarKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
        );
        if (mounted) {
          setState(() {
            _isFetchingUserLocation = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      if (!mounted) return;

      setState(() {
        _userCurrentLocation = LatLng(position.latitude, position.longitude);
        _currentMapCenter = _userCurrentLocation!; // Center map on user's location
        
        // ADDED: Small delay to ensure MapController is fully ready
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) { // Re-check mounted after delay
             _mapController.move(_userCurrentLocation!, 14.0);
          }
        });
       
        _isFetchingUserLocation = false;
      });
    } catch (e) {
      print('Error getting user location: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to get current location: ${e.toString()}')),
      );
      if (mounted) {
        setState(() {
          _isFetchingUserLocation = false;
        });
      }
    }
  }

  // Function to fetch mechanic data from Supabase
  Future<void> _fetchMechanics() async {
    if (!mounted) return; // Check if widget is still mounted

    setState(() {
      _isLoadingMechanics = true;
      _errorMessage = null;
      _mechanicMarkers.clear(); // Clear existing markers
    });

    try {
      // Fetch mechanics data. Join with profiles to get full_name
      final List<Map<String, dynamic>> mechanicsData = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)');

      if (!mounted) return; // Check if widget is still mounted after async op

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
                    mechanic['id'] as String, // Pass mechanic ID for directions
                    shopName!,
                    LatLng(lat, lng), // Pass LatLng for directions
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

      if (mounted) {
        setState(() {
          _mechanicMarkers = newMarkers;
          _isLoadingMechanics = false;
        });
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Database error: ${e.message}';
      print('Error fetching mechanics: ${e.message}');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      if (mounted) {
        setState(() {
          _isLoadingMechanics = false;
        });
      }
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      print('Unexpected error fetching mechanics: $e');
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      if (mounted) {
        setState(() {
          _isLoadingMechanics = false;
        });
      }
    }
  }

  // New function to fetch directions from OSRM
  Future<void> _getDirections(LatLng start, LatLng end) async {
    if (!mounted) return;
    setState(() {
      _isCalculatingRoute = true;
      _routePolylines.clear(); // Clear previous route
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
            return LatLng(coord[1], coord[0]); // OSRM returns [lon, lat], LatLng expects (lat, lon)
          }).toList();

          if (mounted) {
            setState(() {
              _routePolylines = [
                Polyline(
                  points: routePoints,
                  color: Colors.blueAccent,
                  strokeWidth: 5.0,
                ),
              ];
              // Optionally fit the map to the route
              _mapController.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routePoints),
                padding: const EdgeInsets.all(50.0), // Add padding around the route
              ));
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
      print('Error fetching directions: $e');
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

  // Function to show mechanic details in an AlertDialog
  void _showMechanicDetails(
    BuildContext context,
    String mechanicId, // Added mechanicId
    String shopName,
    LatLng mechanicLocation, // Added mechanicLocation
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
            // New "Get Directions" button
            TextButton(
              child: const Text('Get Directions'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                if (_userCurrentLocation != null) {
                  _getDirections(_userCurrentLocation!, mechanicLocation);
                } else {
                  snackbarKey.currentState?.showSnackBar(
                    const SnackBar(content: Text('Cannot get directions: Your current location is not available.'), backgroundColor: Colors.orange),
                  );
                }
              },
            ),
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
              : Stack( // Use Stack to layer map and loading indicator
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
                          markers: _mechanicMarkers,
                        ),
                        // Add PolylineLayer to draw routes
                        PolylineLayer(
                          polylines: _routePolylines,
                        ),
                      ],
                    ),
                    if (_isCalculatingRoute) // Show loading indicator when calculating route
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
                // Clear any drawn routes when recentering
                setState(() {
                  _routePolylines.clear();
                });
              }
            },
            backgroundColor: Colors.blue,
            child: _isFetchingUserLocation
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Icon(Icons.my_location, color: Colors.white),
          ),
          const SizedBox(height: 10),
          // Optional: Add a dedicated "Clear Route" button
          if (_routePolylines.isNotEmpty) // Only show if a route is drawn
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
