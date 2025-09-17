import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:autofix/main.dart'; // For snackbarKey

class MechanicMapScreen extends StatefulWidget {
  final LatLng mechanicLocation;
  final LatLng requesterLocation;

  const MechanicMapScreen({
    super.key,
    required this.mechanicLocation,
    required this.requesterLocation,
  });

  @override
  State<MechanicMapScreen> createState() => _MechanicMapScreenState();
}

class _MechanicMapScreenState extends State<MechanicMapScreen> {
  final MapController _mapController = MapController();
  final List<Marker> _markers = [];
  List<Polyline> _polylines = [];
  bool _isCalculatingRoute = true; // Start in loading state

  @override
  void initState() {
    super.initState();
    _setupMapAndRoute();
  }
  
  /// Sets up the map markers and immediately calculates the route.
  void _setupMapAndRoute() {
    // Add markers for both the mechanic and the requester.
    _markers.add(
      Marker(
        point: widget.mechanicLocation,
        child: const Tooltip(message: 'Your Location', child: Icon(Icons.directions_car, color: Colors.green, size: 40)),
      ),
    );
    _markers.add(
      Marker(
        point: widget.requesterLocation,
        child: const Tooltip(message: 'Requester Location', child: Icon(Icons.location_on, color: Colors.blue, size: 40)),
      ),
    );

    // Calculate the route as soon as the screen loads.
    _getDirections(widget.mechanicLocation, widget.requesterLocation);
  }
  
  /// Fetches route data from OSRM and updates the polyline state.
  Future<void> _getDirections(LatLng start, LatLng end) async {
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        final routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
        if (mounted) setState(() => _polylines = [Polyline(points: routePoints, color: Colors.blueAccent, strokeWidth: 5.0)]);
      }
    } catch (e) {
      if(mounted) snackbarKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not fetch route.')));
    } finally {
      if (mounted) setState(() => _isCalculatingRoute = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Route'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // Automatically fit the map to show both points.
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints([widget.mechanicLocation, widget.requesterLocation]),
                padding: const EdgeInsets.all(50.0),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.autofix.app',
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
            ],
          ),
          if (_isCalculatingRoute)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
