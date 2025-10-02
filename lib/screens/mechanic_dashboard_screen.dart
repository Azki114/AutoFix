// lib/screens/mechanic_dashboard_screen.dart

import 'package:autofix/screens/mechanic_reviews_screen.dart'; // Import the new reviews screen
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:autofix/main.dart';
import 'package:autofix/screens/select_location_on_map_screen.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:autofix/screens/chat_list_screen.dart';
import 'package:autofix/screens/mechanic_service_requests_screen.dart';

class MechanicDashboardScreen extends StatefulWidget {
  const MechanicDashboardScreen({super.key});

  @override
  State<MechanicDashboardScreen> createState() =>
      _MechanicDashboardScreenState();
}

class _MechanicDashboardScreenState extends State<MechanicDashboardScreen> {
  Map<String, dynamic>? _mechanicShopData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isAvailable = false;

  // Controllers for editing shop details (removed pricing and radius)
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _businessAddressController =
      TextEditingController();
  final TextEditingController _yearsExperienceController =
      TextEditingController();
  final TextEditingController _certificationsController =
      TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();

  LatLng? _currentShopLocation;
  String? _mechanicName;

  @override
  void initState() {
    super.initState();
    _fetchMechanicShopData();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _businessAddressController.dispose();
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
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await supabase
          .from('mechanics')
          .select('*, profiles!inner(full_name)')
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _mechanicShopData = response;
          _isLoading = false;
          _isAvailable = _mechanicShopData!['is_available'] ?? false;

          _shopNameController.text = _mechanicShopData!['shop_name'] ?? '';
          _businessAddressController.text =
              _mechanicShopData!['business_address'] ?? '';
          _yearsExperienceController.text =
              (_mechanicShopData!['years_experience'] ?? '').toString();
          _certificationsController.text =
              _mechanicShopData!['certifications'] ?? '';
          _specialtiesController.text = _mechanicShopData!['specialties'] ?? '';

          final double? lat = _mechanicShopData!['latitude'];
          final double? lng = _mechanicShopData!['longitude'];
          if (lat != null && lng != null) {
            _currentShopLocation = LatLng(lat, lng);
          }
          
          _mechanicName = (_mechanicShopData!['profiles']
              as Map<String, dynamic>?)?['full_name'] ?? 'Mechanic';
        });
      }
    } catch (e) {
      _errorMessage = 'An error occurred loading your data.';
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateMechanicShopData() async {
    setState(() => _isLoading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showSnackBar('User not authenticated.', Colors.red);
      setState(() => _isLoading = false);
      return;
    }
    try {
      // Removed pricing and radius from the update payload
      final updates = {
        'shop_name': _shopNameController.text.trim(),
        'business_address': _businessAddressController.text.trim(),
        'years_experience':
            int.tryParse(_yearsExperienceController.text.trim()),
        'certifications': _certificationsController.text.trim(),
        'specialties': _specialtiesController.text.trim(),
        'latitude': _currentShopLocation?.latitude,
        'longitude': _currentShopLocation?.longitude,
      };
      await supabase.from('mechanics').update(updates).eq('user_id', user.id);
      _showSnackBar('Shop data updated successfully!', Colors.green);
      _fetchMechanicShopData();
    } catch (e) {
      _showSnackBar('Error updating shop data: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isAvailable = value);
    final user = supabase.auth.currentUser;
    try {
      await supabase
          .from('mechanics')
          .update({'is_available': value})
          .eq('user_id', user!.id);
      _showSnackBar(
          'You are now ${value ? "Online" : "Offline"}',
          value ? Colors.green : Colors.orange,
      );
    } catch (e) {
      _showSnackBar('Failed to update availability.', Colors.red);
      if(mounted) setState(() => _isAvailable = !value);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    snackbarKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint,
      {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
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

  Widget _buildHomeTab() {
    return SingleChildScrollView(
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
          SwitchListTile.adaptive(
            title: Text(
              _isAvailable ? 'You are Online' : 'You are Offline',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_isAvailable
                ? 'You can now receive service requests.'
                : 'Go online to receive requests.'),
            value: _isAvailable,
            onChanged: _toggleAvailability,
            activeColor: Colors.green,
            tileColor: Colors.blue.withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            secondary: Icon(
              _isAvailable ? Icons.check_circle : Icons.cancel,
              color: _isAvailable ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
            children: [
              _buildDashboardCard(
                context,
                title: 'Service Requests',
                icon: Icons.handyman,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MechanicServiceRequestsScreen(),
                    ),
                  );
                },
              ),
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
              _buildDashboardCard(
                context,
                title: 'My Reviews', // CHANGED FROM "Service History"
                icon: Icons.star_rate, // CHANGED ICON
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MechanicReviewsScreen(), // NAVIGATES TO NEW SCREEN
                    ),
                  );
                },
              ),
              _buildDashboardCard(
                context,
                title: 'My Account', // CHANGED FROM "My Earnings"
                icon: Icons.person, // CHANGED ICON
                onTap: () {
                  // This will switch to the second tab ("My Shop Profile")
                  DefaultTabController.of(context).animateTo(1);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Edit Shop Information',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(_shopNameController, 'Shop Name', 'Your Shop Name'),
          const SizedBox(height: 16),
          _buildTextField(_yearsExperienceController, 'Years of Experience', 'e.g., 5',
              keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildTextField(_certificationsController,
              'Certifications (comma-separated)', 'e.g., ASE, NCIII'),
          const SizedBox(height: 16),
          _buildTextField(_specialtiesController,
              'Specialties (comma-separated)', 'e.g., Engine, Brakes'),
          const SizedBox(height: 24),
          const Text(
            'Location Details',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildTextField(_businessAddressController, 'Business Address',
              'Select on map below',
              enabled: false),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text('Edit Shop Location on Map',
                style: TextStyle(color: Colors.white)),
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
                setState(() => _currentShopLocation = selectedLatLng);
                try {
                  List<Placemark> placemarks = await placemarkFromCoordinates(
                    selectedLatLng.latitude,
                    selectedLatLng.longitude,
                  );
                  if (placemarks.isNotEmpty) {
                    final Placemark p = placemarks.first;
                    _businessAddressController.text = [
                      p.street, p.subLocality, p.locality, p.administrativeArea, p.country
                    ].where((e) => e != null && e.isNotEmpty).join(', ');
                  }
                } catch (e) {
                   _showSnackBar('Error fetching address.', Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save Changes',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            onPressed: _isLoading ? null : _updateMechanicShopData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mechanic Home',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          backgroundColor: const Color.fromARGB(233, 214, 251, 250),
          centerTitle: true,
          elevation: 1,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home), text: 'Home'),
              Tab(icon: Icon(Icons.store), text: 'My Shop Profile'),
            ],
          ),
        ),
        drawer: const app_nav.NavigationDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            onPressed: _fetchMechanicShopData,
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _buildHomeTab(),
                      _buildProfileTab(),
                    ],
                  ),
      ),
    );
  }
}