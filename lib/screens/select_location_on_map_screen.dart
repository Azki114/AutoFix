// lib/screens/select_location_on_map_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class SelectLocationOnMapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const SelectLocationOnMapScreen({super.key, this.initialLocation});

  @override
  State<SelectLocationOnMapScreen> createState() =>
      _SelectLocationOnMapScreenState();
}

class _SelectLocationOnMapScreenState extends State<SelectLocationOnMapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  LatLng _selectedLocation = LatLng(14.5995, 120.9842); // Default to Manila
  String _addressDisplay = 'Drag map to select location';
  bool _isReverseGeocoding = false;

  // State for search feature
  Timer? _debounce;
  List<Map<String, dynamic>> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
    }
    _reverseGeocodeCurrentLocation();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.length > 2) {
        _fetchAutocompleteSuggestions(_searchController.text);
      } else {
        setState(() {
          _suggestions = [];
        });
      }
    });
  }

  Future<void> _fetchAutocompleteSuggestions(String query) async {
    setState(() {
      _isSearching = true;
    });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5');
    final headers = {'User-Agent': 'AutoFixApp/1.0'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _suggestions = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching suggestions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _reverseGeocodeCurrentLocation() async {
    setState(() {
      _isReverseGeocoding = true;
      _addressDisplay = 'Fetching address...';
    });

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${_selectedLocation.latitude}&lon=${_selectedLocation.longitude}');
    final headers = {'User-Agent': 'AutoFixApp/1.0'};

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          _addressDisplay = data['display_name'];
        } else {
          _addressDisplay = 'No address found for this location.';
        }
      } else {
        _addressDisplay = 'Error fetching address.';
      }
    } catch (e) {
      _addressDisplay = 'Network error occurred.';
    } finally {
      if (mounted) {
        setState(() {
          _isReverseGeocoding = false;
        });
      }
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
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && pos.center != null) {
                  setState(() {
                    _selectedLocation = pos.center;
                  });
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                     _reverseGeocodeCurrentLocation();
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.autofix.app',
              ),
            ],
          ),
          const Center(
            child: Icon(
              Icons.location_pin,
              color: Colors.red,
              size: 50,
            ),
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for an address...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _suggestions = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                if (_isSearching) const LinearProgressIndicator(),
                if (_suggestions.isNotEmpty)
                  Card(
                    elevation: 4,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return ListTile(
                          title: Text(suggestion['display_name']),
                          onTap: () {
                            final lat = double.parse(suggestion['lat']);
                            final lon = double.parse(suggestion['lon']);
                            final newLocation = LatLng(lat, lon);
                            
                            setState(() {
                              _selectedLocation = newLocation;
                              _suggestions = [];
                            });
                            _searchController.clear();
                            _mapController.move(newLocation, 16.0);
                             _reverseGeocodeCurrentLocation();
                            FocusScope.of(context).unfocus();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
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
