// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav; // Import main.dart with a prefix for NavigationDrawer
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:geocoding/geocoding.dart'; // Import geocoding for address to lat/lng
import 'package:latlong2/latlong.dart'; // Import for LatLng
import 'package:autofix/screens/select_location_on_map_screen.dart'; // NEW Import for map selection screen

// Assume 'supabase' is initialized globally in main.dart
import 'package:autofix/main.dart'; // To access the global 'supabase' client
import 'package:autofix/screens/terms_conditions_screen.dart'; // Import the new T&C screen

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum AccountType { driver, mechanic }
enum PricingUnit { kilometer, meters_500 } // Kilometer (10php), 500 Meters (5php)

// Custom exception for geocoding no results
class NoResultFoundException implements Exception {
  final String message;
  const NoResultFoundException(this.message);
  @override
  String toString() => 'NoResultFoundException: $message';
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Common Fields Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false; // For password visibility toggle

  // Account Type Selection
  AccountType? _selectedAccountType; // Null initially to force selection

  // Driver Details Controllers
  final TextEditingController _driverFirstNameController = TextEditingController();
  final TextEditingController _driverLastNameController = TextEditingController();
  String? _selectedVehicleType; // Dropdown value
  final List<String> _vehicleTypes = ['Car', 'Motor', 'Truck', 'Van'];
  final TextEditingController _makerController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  // Mechanic Details Controllers
  final TextEditingController _shopNameController = TextEditingController();
  String? _selectedBusinessType; // Dropdown value
  final List<String> _businessTypes = ['Individual', 'Shop'];
  final TextEditingController _certificationsController = TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController(); // This will be updated by reverse geocoding
  final TextEditingController _serviceRadiusController = TextEditingController();
  final TextEditingController _baseRateController = TextEditingController();
  PricingUnit? _selectedPricingUnit;
  final TextEditingController _minimumChargeController = TextEditingController();

  // New state variables for map-selected location
  LatLng? _mechanicLatitudeLongitude;
  bool _agreedToTerms = false;
  bool _isRegistering = false; // New loading state for the button

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _passwordController.dispose();
    _driverFirstNameController.dispose();
    _driverLastNameController.dispose();
    _makerController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _licensePlateController.dispose();
    _shopNameController.dispose();
    _certificationsController.dispose();
    _specialtiesController.dispose();
    _yearsExperienceController.dispose();
    _businessAddressController.dispose();
    _serviceRadiusController.dispose();
    _baseRateController.dispose();
    _minimumChargeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) { // Ensure widget is still in the tree before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4), // Increased duration for better visibility
        ),
      );
    }
  }

  // Helper function to delete partially created user data
  Future<void> _rollbackRegistration(String? userId) async {
    if (userId != null) {
      try {
        // Delete profile entry if it was created
        await supabase.from('profiles').delete().eq('id', userId);
        print('Attempted to delete profiles entry for user $userId due to registration failure.');
      } catch (e) {
        print('Error during rollback for user $userId: $e');
        _showSnackBar('Failed to clean up incomplete registration. Please contact support.', Colors.orange);
      }
    }
  }

  Future<void> _registerAccount() async {
    if (_isRegistering) return; // Prevent multiple taps

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form.', Colors.red);
      return;
    }
    if (_selectedAccountType == null) {
      _showSnackBar('Please select an account type (Driver or Mechanic).', Colors.red);
      return;
    }
    if (!_agreedToTerms) {
      _showSnackBar('You must agree to the Terms and Conditions.', Colors.red);
      return;
    }

    // --- New validation for mechanic location from map ---
    if (_selectedAccountType == AccountType.mechanic && _mechanicLatitudeLongitude == null) {
      _showSnackBar('Please select your business location on the map.', Colors.red);
      return;
    }

    setState(() {
      _isRegistering = true; // Set loading state
    });

    String? userId; // Variable to store userId for potential rollback

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String fullName = _fullNameController.text.trim();
      final String phoneNumber = _phoneNumberController.text.trim();

      // --- Step 1: Supabase Authentication - Create User ---
      final AuthResponse authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final User? user = authResponse.user;

      if (user == null) {
        _showSnackBar('Registration failed: User account could not be created.', Colors.red);
        return; // Exit if user is null
      }

      userId = user.id; // Store userId for potential rollback

      // --- Step 2: Store Common Profile Details ---
      await supabase.from('profiles').insert({
        'id': userId, // Link to Supabase Auth user ID
        'full_name': fullName,
        'phone_number': phoneNumber,
        'email': email,
        'role': _selectedAccountType == AccountType.driver ? 'driver' : 'mechanic',
      });

      // --- Step 3: Store Role-Specific Details ---
      if (_selectedAccountType == AccountType.driver) {
        await supabase.from('drivers').insert({
          'user_id': userId,
          'first_name': _driverFirstNameController.text.trim(),
          'last_name': _driverLastNameController.text.trim(),
          'vehicle_type': _selectedVehicleType,
          'maker': _makerController.text.trim(),
          'model': _modelController.text.trim(),
          'year': _yearController.text.trim(),
          'license_plate': _licensePlateController.text.trim(),
        });
        _showSnackBar('Driver account created successfully! Please verify your email.', Colors.green);
        _resetForm(); // Reset form after successful registration
        Navigator.pushReplacementNamed(context, '/login'); // Redirect to login
      } else if (_selectedAccountType == AccountType.mechanic) {
        // --- Use map-selected coordinates directly ---
        // _mechanicLatitudeLongitude is guaranteed to be not null due to earlier validation
        await supabase.from('mechanics').insert({
          'user_id': userId,
          'shop_name': _shopNameController.text.trim(),
          'business_type': _selectedBusinessType,
          'certifications': _certificationsController.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          'specialties': _specialtiesController.text.trim().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          'years_experience': int.tryParse(_yearsExperienceController.text.trim()) ?? 0,
          'business_address': _businessAddressController.text.trim(), // Use the reverse-geocoded address
          'latitude': _mechanicLatitudeLongitude!.latitude, // Use map-selected lat
          'longitude': _mechanicLatitudeLongitude!.longitude, // Use map-selected lng
          'service_radius_km': double.tryParse(_serviceRadiusController.text.trim()),
          'base_rate_php': double.tryParse(_baseRateController.text.trim()),
          'pricing_unit': _selectedPricingUnit?.toString().split('.').last,
          'minimum_charge_php': double.tryParse(_minimumChargeController.text.trim()),
        });
        _showSnackBar('Mechanic account created successfully! Please verify your email.', Colors.green);
        _resetForm();
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on AuthException catch (e) {
      // Catch errors during Supabase authentication (e.g., email already registered, invalid password)
      _showSnackBar('Authentication error: ${e.message}', Colors.red);
      // No rollback needed here as user wasn't fully created or profile wasn't inserted yet
    } on PostgrestException catch (e) {
      // Catch errors during database inserts (e.g., RLS violations, unique constraint violations)
      _showSnackBar('Database error: ${e.message}', Colors.red);
      await _rollbackRegistration(userId); // Rollback if profiles or driver/mechanic insert fails
    } catch (e) {
      // Catch any other unexpected errors
      _showSnackBar('An unexpected error occurred during registration: ${e.toString()}', Colors.red);
      await _rollbackRegistration(userId); // Rollback for any other error
    } finally {
      setState(() {
        _isRegistering = false; // Always reset loading state
      });
    }
  }

  // Resets all form fields and selections
  void _resetForm() {
    _formKey.currentState?.reset(); // Resets validators
    _fullNameController.clear();
    _emailController.clear();
    _phoneNumberController.clear();
    _passwordController.clear();
    _driverFirstNameController.clear();
    _driverLastNameController.clear();
    _makerController.clear();
    _modelController.clear();
    _yearController.clear();
    _licensePlateController.clear();
    _shopNameController.clear();
    _certificationsController.clear();
    _specialtiesController.clear();
    _yearsExperienceController.clear();
    _businessAddressController.clear();
    _serviceRadiusController.clear();
    _baseRateController.clear();
    _minimumChargeController.clear();
    setState(() {
      _selectedAccountType = null;
      _selectedVehicleType = null;
      _selectedBusinessType = null;
      _selectedPricingUnit = null;
      _agreedToTerms = false;
      _passwordVisible = false;
      _mechanicLatitudeLongitude = null; // Reset map selection
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.person_add, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'Join AUTOFIX today!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.blueGrey),
                ),
                const SizedBox(height: 24),

                // Common Fields
                _buildTextField(_fullNameController, 'Full Name', 'Enter your full name', (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                }),
                const SizedBox(height: 16),
                _buildTextField(_emailController, 'Email', 'example@email.com', (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                }, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),
                _buildTextField(_phoneNumberController, 'Phone Number', '+63 9123456789', (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  // Basic validation for numbers and length (adjust regex as needed)
                  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                }, keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.blueGrey,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Account Type Selection
                const Text(
                  'Account Type:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<AccountType>(
                        title: const Text('Driver'),
                        value: AccountType.driver,
                        groupValue: _selectedAccountType,
                        onChanged: (AccountType? value) {
                          setState(() {
                            _selectedAccountType = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<AccountType>(
                        title: const Text('Mechanic'),
                        value: AccountType.mechanic,
                        groupValue: _selectedAccountType,
                        onChanged: (AccountType? value) {
                          setState(() {
                            _selectedAccountType = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Conditional Fields based on Account Type
                if (_selectedAccountType == AccountType.driver)
                  _buildDriverDetailsForm(),
                if (_selectedAccountType == AccountType.mechanic)
                  _buildMechanicDetailsForm(),

                const SizedBox(height: 24),

                // Terms and Conditions
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreedToTerms = value!;
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Navigate to the Terms and Conditions screen
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TermsConditionsScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'I have read and agree to the Terms and Conditions.',
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Register Button
                ElevatedButton(
                  onPressed: _isRegistering ? null : _registerAccount, // Disable when registering
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isRegistering
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Register',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build common TextField widgets
  Widget _buildTextField(TextEditingController controller, String label, String hint, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled, // Added enabled property
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }

  // --- Driver Details Form ---
  Widget _buildDriverDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Driver Details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        _buildTextField(_driverFirstNameController, 'First Name', 'John', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your first name';
          }
          return null;
        }),
        const SizedBox(height: 16),
        _buildTextField(_driverLastNameController, 'Last Name', 'Doe', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your last name';
          }
          return null;
        }),
        const SizedBox(height: 24),

        const Text(
          'Vehicle Details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedVehicleType,
          hint: const Text('Select Vehicle Type'),
          decoration: InputDecoration(
            labelText: 'Vehicle Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _vehicleTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedVehicleType = newValue;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a vehicle type';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(_makerController, 'Maker', 'Toyota, Yamaha etc.', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter vehicle maker';
          }
          return null;
        }),
        const SizedBox(height: 16),
        _buildTextField(_modelController, 'Model', 'Mio i125 etc.', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter vehicle model';
          }
          return null;
        }),
        const SizedBox(height: 16),
        _buildTextField(_yearController, 'Year', '2014', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter vehicle year';
          }
          if (!RegExp(r'^[0-9]{4}$').hasMatch(value)) {
            return 'Please enter a valid 4-digit year';
          }
          return null;
        }, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        _buildTextField(_licensePlateController, 'License Plate', '123YBCE1', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter license plate number';
          }
          return null;
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- Mechanic Details Form ---
  Widget _buildMechanicDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Mechanic Details:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        _buildTextField(_shopNameController, 'Shop Name / Your Name', 'AutoFix Garage', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter shop name or your name';
          }
          return null;
        }),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedBusinessType,
          hint: const Text('Select Business Type'),
          decoration: InputDecoration(
            labelText: 'Business Type',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: _businessTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedBusinessType = newValue;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a business type';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(_certificationsController, 'Certifications (comma-separated)', 'ASE Certified, NCIII Certified', null),
        const SizedBox(height: 16),
        _buildTextField(_specialtiesController, 'Specialties (comma-separated)', 'Engine Repair, Brakes', null),
        const SizedBox(height: 16),
        _buildTextField(_yearsExperienceController, 'Years of Experience', '5', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter years of experience';
          }
          if (int.tryParse(value) == null || int.parse(value) < 0) {
            return 'Please enter a valid number for years of experience';
          }
          return null;
        }, keyboardType: TextInputType.number),
        const SizedBox(height: 24),

        const Text(
          'Location & Service:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        // Display the selected address from map, make it read-only
        _buildTextField(
          _businessAddressController,
          'Business Address (from map)',
          _mechanicLatitudeLongitude == null ? 'Select location on map below' : '', // Hint changes
          (value) {
            if (value == null || value.isEmpty || _mechanicLatitudeLongitude == null) {
              return 'Please select your business address on the map.';
            }
            return null;
          },
          enabled: false, // Make this field read-only
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.map, color: Colors.white),
          label: const Text('Select on Map', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            // Navigate to map screen and wait for result
            final LatLng? selectedLatLng = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectLocationOnMapScreen(
                  initialLocation: _mechanicLatitudeLongitude, // Pass current selection if any
                ),
              ),
            );

            if (selectedLatLng != null) {
              setState(() {
                _mechanicLatitudeLongitude = selectedLatLng;
              });
              // Reverse geocode the selected coordinates to display address in the text field
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
                  _showSnackBar('Address not found for selected coordinates. Please try another spot.', Colors.orange);
                }
              } catch (e) {
                _businessAddressController.text = 'Error fetching address.';
                _showSnackBar('Error fetching address for selected location: ${e.toString()}', Colors.red);
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
        _buildTextField(_serviceRadiusController, 'Service Radius (km)', '30', (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter service radius';
          }
          if (double.tryParse(value) == null || double.parse(value) <= 0) {
            return 'Please enter a valid number for service radius';
          }
          return null;
        }, keyboardType: TextInputType.number),
        const SizedBox(height: 24),

        const Text(
          'Pricing (optional):',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        _buildTextField(_baseRateController, 'Base Rate (₱)', '30', null, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        const Text(
          'Price per:',
          style: TextStyle(fontSize: 16, color: Colors.blueGrey),
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<PricingUnit>(
                title: const Text('Kilometer (₱10)'),
                value: PricingUnit.kilometer,
                groupValue: _selectedPricingUnit,
                onChanged: (PricingUnit? value) {
                  setState(() {
                    _selectedPricingUnit = value;
                  });
                },
                activeColor: Colors.blue,
              ),
            ),
            Expanded(
              child: RadioListTile<PricingUnit>(
                title: const Text('500 meters (₱5)'),
                value: PricingUnit.meters_500,
                groupValue: _selectedPricingUnit,
                onChanged: (PricingUnit? value) {
                  setState(() {
                    _selectedPricingUnit = value;
                  });
                },
                activeColor: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(_minimumChargeController, 'Minimum Charge (₱)', '25', null, keyboardType: TextInputType.number),
        const SizedBox(height: 24),
      ],
    );
  }
}
