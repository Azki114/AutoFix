// lib/screens/mechanic_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autofix/main.dart'; // To access the global 'supabase' client and 'snackbarKey'
import 'package:autofix/screens/select_location_on_map_screen.dart'; // For editing shop location
import 'package:latlong2/latlong.dart'; // For LatLng
import 'package:geocoding/geocoding.dart'; // For reverse geocoding
import 'package:autofix/screens/chat_list_screen.dart'; // NEW: Import ChatListScreen

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() => _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  Map<String, dynamic>? _mechanicShopData;
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers for editing shop details
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();
  final TextEditingController _serviceRadiusController = TextEditingController();
  final TextEditingController _baseRateController = TextEditingController();
  final TextEditingController _minimumChargeController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();
  final TextEditingController _certificationsController = TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();

  LatLng? _currentShopLocation; // Store the LatLng for map interaction
  String? _mechanicName; // To display welcome message

  @override
  void initState() {
    super.initState();
    _fetchMechanicShopData();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _businessAddressController.dispose();
    _serviceRadiusController.dispose();
    _baseRateController.dispose();
    _minimumChargeController.dispose();
    _yearsExperienceController.dispose();
    _certificationsController.dispose();
    _specialtiesController.dispose();
    super.dispose();
  }

  Future<void> _fetchMechanicShopData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('No authenticated user found.')),
      );
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // Fetch mechanic details for the current user
      final response = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)') // Also fetch full_name from profiles
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _mechanicShopData = response;
          _isLoading = false;

          // Populate controllers with fetched data for editing
          _shopNameController.text = _mechanicShopData!['shop_name'] ?? '';
          _businessAddressController.text = _mechanicShopData!['business_address'] ?? '';
          _serviceRadiusController.text = (_mechanicShopData!['service_radius_km'] ?? '').toString();
          _baseRateController.text = (_mechanicShopData!['base_rate_php'] ?? '').toString();
          _minimumChargeController.text = (_mechanicShopData!['minimum_charge_php'] ?? '').toString();
          _yearsExperienceController.text = (_mechanicShopData!['years_experience'] ?? '').toString();
          _certificationsController.text = _mechanicShopData!['certifications'] ?? ''; // Stored as text
          _specialtiesController.text = _mechanicShopData!['specialties'] ?? ''; // Stored as text

          // Set current shop location for map interaction
          final double? lat = _mechanicShopData!['latitude'];
          final double? lng = _mechanicShopData!['longitude'];
          if (lat != null && lng != null) {
            _currentShopLocation = LatLng(lat, lng);
          }
          
          // Set mechanic name from joined profile data
          _mechanicName = (_mechanicShopData!['profiles'] as Map<String, dynamic>?)?['full_name'] ?? 'Mechanic';
        });
      }
    } on PostgrestException catch (e) {
      _errorMessage = 'Error loading shop data: ${e.message}';
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      snackbarKey.currentState?.showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMechanicShopData() async {
    setState(() {
      _isLoading = true; // Use _isLoading for update too
    });

    final user = supabase.auth.currentUser;
    if (user == null) {
      snackbarKey.currentState?.showSnackBar(
        const SnackBar(content: Text('User not authenticated.')),
      );
      setState(() { _isLoading = false; });
      return;
    }

    try {
      final updates = {
        'shop_name': _shopNameController.text.trim(),
        'business_address': _businessAddressController.text.trim(),
        'service_radius_km': double.tryParse(_serviceRadiusController.text.trim()),
        'base_rate_php': double.tryParse(_baseRateController.text.trim()),
        'minimum_charge_php': double.tryParse(_minimumChargeController.text.trim()),
        'years_experience': int.tryParse(_yearsExperienceController.text.trim()),
        'certifications': _certificationsController.text.trim(),
        'specialties': _specialtiesController.text.trim(),
        'latitude': _currentShopLocation?.latitude,
        'longitude': _currentShopLocation?.longitude,
      };

      await supabase
          .from('mechanics')
          .update(updates)
          .eq('user_id', user.id);

      _showSnackBar('Shop data updated successfully!', Colors.green);
      _fetchMechanicShopData(); // Refresh data after update
    } on PostgrestException catch (e) {
      _showSnackBar('Error updating shop data: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('An unexpected error occurred during update: ${e.toString()}', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    snackbarKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  // Helper method to build common TextField widgets
  Widget _buildTextField(TextEditingController controller, String label, String hint, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Helper method to build a dashboard card
  Widget _buildDashboardCard(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.blue),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mechanic Dashboard',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(), // Attach the NavigationDrawer
      body: _isLoading
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
                        label: const Text('Retry Load Data', style: TextStyle(color: Colors.white)),
                        onPressed: _fetchMechanicShopData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Welcome, ${_mechanicName ?? 'Mechanic'}!',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const SizedBox(height: 20),
                      // Dashboard Grid for main actions
                      GridView.count(
                        shrinkWrap: true, // Make GridView take only necessary space
                        physics: const NeverScrollableScrollPhysics(), // Disable GridView's own scrolling
                        crossAxisCount: 2, // 2 columns
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                        children: [
                          // Card for "My Chats"
                          _buildDashboardCard(
                            context,
                            title: 'My Chats',
                            icon: Icons.chat,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChatListScreen(),
                                ),
                              );
                            },
                          ),
                          // Placeholder for other Mechanic functions
                          _buildDashboardCard(
                            context,
                            title: 'Service Requests',
                            icon: Icons.handyman,
                            onTap: () {
                              snackbarKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Service Requests coming soon!')),
                              );
                              // TODO: Navigate to Service Requests screen
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            title: 'My Profile',
                            icon: Icons.person,
                            onTap: () {
                              snackbarKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Profile edit fields are below!')),
                              );
                              // Can also navigate to a separate profile screen if desired
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            title: 'Settings',
                            icon: Icons.settings,
                            onTap: () {
                              snackbarKey.currentState?.showSnackBar(
                                const SnackBar(content: Text('Settings coming soon!')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32), // Separator

                      // Shop Information Edit Section
                      const Text(
                        'Edit Shop Information',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_shopNameController, 'Shop Name', 'Your Shop Name'),
                      const SizedBox(height: 16),
                      _buildTextField(_yearsExperienceController, 'Years of Experience', 'e.g., 5', keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      _buildTextField(_certificationsController, 'Certifications (comma-separated)', 'e.g., ASE, NCIII'),
                      const SizedBox(height: 16),
                      _buildTextField(_specialtiesController, 'Specialties (comma-separated)', 'e.g., Engine, Brakes'),
                      const SizedBox(height: 24),

                      const Text(
                        'Location & Service Details',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_businessAddressController, 'Business Address', 'Select on map below', enabled: false),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.map, color: Colors.white),
                        label: const Text('Edit Shop Location on Map', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          final LatLng? selectedLatLng = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SelectLocationOnMapScreen(
                                initialLocation: _currentShopLocation,
                              ),
                            ),
                          );

                          if (selectedLatLng != null) {
                            setState(() {
                              _currentShopLocation = selectedLatLng;
                            });
                            // Reverse geocode the selected coordinates to display address
                            try {
                              List<Placemark> placemarks = await placemarkFromCoordinates(
                                selectedLatLng.latitude,
                                selectedLatLng.longitude,
                              );
                              if (placemarks.isNotEmpty) {
                                final Placemark place = placemarks.first;
                                _businessAddressController.text = [
                                  place.street,
                                  place.subLocality,
                                  place.locality,
                                  place.administrativeArea,
                                  place.country,
                                ].where((element) => element != null && element.isNotEmpty).join(', ');
                              } else {
                                _businessAddressController.text = 'Address not found for selected coordinates.';
                                snackbarKey.currentState?.showSnackBar(
                                  const SnackBar(content: Text('Address not found for selected coordinates. Using raw coordinates.')),
                                );
                              }
                            } catch (e) {
                              _businessAddressController.text = 'Error fetching address.';
                              snackbarKey.currentState?.showSnackBar(
                                SnackBar(content: Text('Error fetching address: ${e.toString()}. Using raw coordinates.')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(_serviceRadiusController, 'Service Radius (km)', 'e.g., 30', keyboardType: TextInputType.number),
                      const SizedBox(height: 24),

                      const Text(
                        'Pricing Details',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(_baseRateController, 'Base Rate (₱)', 'e.g., 50', keyboardType: TextInputType.number),
                      const SizedBox(height: 16),
                      _buildTextField(_minimumChargeController, 'Minimum Charge (₱)', 'e.g., 100', keyboardType: TextInputType.number),
                      // You might want to add a dropdown for pricing unit here if you allow editing it
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('Save Changes', style: TextStyle(fontSize: 18, color: Colors.white)),
                        onPressed: _isLoading ? null : _updateMechanicShopData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
