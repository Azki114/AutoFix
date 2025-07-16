// lib/screens/select_location_on_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart'; // For LatLng
import 'package:geocoding/geocoding.dart'; // For reverse geocoding

class SelectLocationOnMapScreen extends StatefulWidget {
  // Optional: Pass an initial location if you want to center the map
  // around the user's current location or a previous selection.
  final LatLng? initialLocation;

  const SelectLocationOnMapScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  State<SelectLocationOnMapScreen> createState() => _SelectLocationOnMapScreenState();
}

class _SelectLocationOnMapScreenState extends State<SelectLocationOnMapScreen> {
  // Changed default location to a more likely resolvable address in Manila (Rizal Park)
  LatLng _selectedLocation = LatLng(14.5847, 120.9789); // Rizal Park, Manila, Philippines
  String _addressDisplay = 'Drag map to select location'; // Updated hint
  bool _isReverseGeocoding = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
    // Always attempt to reverse geocode the initial/default location
    _reverseGeocodeCurrentLocation();
  }

  // Function to reverse geocode the selected LatLng into an address string
  Future<void> _reverseGeocodeCurrentLocation() async {
    setState(() {
      _isReverseGeocoding = true;
      _addressDisplay = 'Fetching address...'; // Temporary message
    });
    try {
      // Use placemarkFromCoordinates directly without 'geocoding.' prefix
      List<Placemark> placemarks = await placemarkFromCoordinates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );
      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        // Construct a readable address string
        _addressDisplay = [
          place.street,
          place.subLocality, // e.g., district
          place.locality, // e.g., city/municipality
          place.administrativeArea, // e.g., province/state
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
      } else {
        // If no address found, indicate that coordinates are primary
        _addressDisplay = 'No street address found. Coordinates will be used.';
      }
    } catch (e) {
      // If an error occurs during fetching, show a more user-friendly message
      _addressDisplay = 'Could not fetch address. Coordinates will be used.';
      print('Error reverse geocoding: $e'); // Log the actual error for debugging
    } finally {
      setState(() {
        _isReverseGeocoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Shop Location',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              // Corrected: Use 'center' and 'zoom' directly
              initialCenter: _selectedLocation, // Center map on initially selected or default location
              initialZoom: 13.0,
              // When the map moves, update the selected location to its new center
              onPositionChanged: (pos, hasGesture) {
                if (pos.center != _selectedLocation) {
                  setState(() {
                    _selectedLocation = pos.center;
                    _reverseGeocodeCurrentLocation(); // Reverse geocode the new center
                  });
                }
              },
              // onTap is also useful if you want to tap anywhere to set the location
              onTap: (tapPos, latLng) {
                setState(() {
                  _selectedLocation = latLng;
                  _reverseGeocodeCurrentLocation();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.autofix.app', // Your app's package name
              ),
              // Removed MarkerLayer, using central Icon for selection indication
            ],
          ),
          // Crosshair in the center to indicate the selection point
          const Center(
            child: Icon(
              Icons.location_pin, // Use a pin icon to indicate the center selection
              color: Colors.red,
              size: 40,
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selected Location:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    _isReverseGeocoding
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Text(
                            _addressDisplay,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14),
                          ),
                    const SizedBox(height: 10),
                    // Always show Lat/Lng clearly
                    Text(
                      'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: () {
                // Always return the selected coordinates
                Navigator.pop(context, _selectedLocation);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
