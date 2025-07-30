// lib/screens/vehicle_owner_map_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng for flutter_map
// No need for flutter_dotenv here as map keys are handled by TileLayer source or native setup

class MechanicMapScreen extends StatefulWidget {
  const MechanicMapScreen({super.key});

  @override
  State<MechanicMapScreen> createState() => _MechanicMapScreenState();
}

class _MechanicMapScreenState extends State<MechanicMapScreen> {
  // Initial camera position for Manila, Philippines (example coordinates)
  // Use LatLng from latlong2 package for flutter_map
  static const LatLng _kManila = LatLng(14.5995, 120.9842);

  // MapController for controlling the map programmatically
  final MapController _mapController = MapController();

  // Set to store map markers (flutter_map uses a list of Marker widgets)
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _addManilaMarker(); // Add a marker for Manila
    _addSampleMechanicMarker(); // Add a sample mechanic marker
    // In a real app, you would fetch mechanic data from Supabase here
    // and convert their addresses to LatLng using geocoding.
  }

  void _addManilaMarker() {
    _markers.add(
      Marker(
        point: _kManila,
        width: 80,
        height: 80,
        // Using an Icon for the marker, you can customize this further
        child: const Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
        // No direct InfoWindow like Google Maps. You'd typically use
        // a GestureDetector around the icon and show a custom overlay/dialog.
      ),
    );
  }

  void _addSampleMechanicMarker() {
    // Example coordinates for a hypothetical mechanic shop near Manila
    _markers.add(
      Marker(
        point: const LatLng(14.6090, 121.0313), // Example: Quezon City area
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            // Show custom information when mechanic marker is tapped
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Speedy Auto Repair'),
                  content: const Text('Your trusted mechanic in Quezon City\n\nAddress: 123 Main St, Quezon City\nServices: Engine Repair, Oil Change'),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('Close'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Map',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(), // Your NavigationDrawer
      body: FlutterMap(
        mapController: _mapController, // Assign the controller
        options: const MapOptions(
          initialCenter: _kManila, // Center the map on Manila
          initialZoom: 12.0, // Initial zoom level
          minZoom: 2.0, // Minimum zoom level
          maxZoom: 18.0, // Maximum zoom level
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
            markers: _markers, // Pass the list of markers
          ),
          // You can add more layers here, e.g., PolygonLayer, PolylineLayer
        ],
      ),
      // Optional: FloatingActionButton to recenter map or add new features
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Animate camera back to Manila center
          _mapController.move(
            _kManila,
            12.0,
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
