// lib/screens/register_screen.dart
import 'dart:convert'; // For JSON decoding
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:autofix/screens/select_location_on_map_screen.dart';
import 'package:autofix/screens/terms_conditions_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; // NEW: Import image_picker

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum AccountType { driver, mechanic }

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;

  AccountType? _selectedAccountType;

  final TextEditingController _driverFirstNameController = TextEditingController();
  final TextEditingController _driverLastNameController = TextEditingController();
  String? _selectedVehicleType;
  final List<String> _vehicleTypes = ['Car', 'Motor', 'Truck', 'Van'];
  final TextEditingController _makerController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _licensePlateController = TextEditingController();

  final TextEditingController _shopNameController = TextEditingController();
  String? _selectedBusinessType;
  final List<String> _businessTypes = ['Individual', 'Shop'];
  final TextEditingController _certificationsController = TextEditingController();
  final TextEditingController _specialtiesController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();
  final TextEditingController _businessAddressController = TextEditingController();

  LatLng? _mechanicLatitudeLongitude;
  bool _agreedToTerms = false;
  bool _isRegistering = false;
  bool _isGeocodingAddress = false;
  
  // --- NEW STATE VARIABLES FOR FILE UPLOADS ---
  XFile? _idFile;
  XFile? _certificateFile;
  final ImagePicker _picker = ImagePicker();

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
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- NEW: Helper function to pick a file ---
  Future<void> _pickFile(bool isId) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isId) {
          _idFile = pickedFile;
        } else {
          _certificateFile = pickedFile;
        }
      });
    }
  }

  // --- NEW: Helper function to upload a file to the private bucket ---
  Future<String?> _uploadFileToBucket(XFile file, String bucket, String userId) async {
    try {
      final fileBytes = await file.readAsBytes();
      final fileExt = file.name.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/$fileName'; // Store in a user-specific folder

      await app_nav.supabase.storage.from(bucket).uploadBinary(
            filePath,
            fileBytes,
            fileOptions: FileOptions(contentType: file.mimeType),
          );
      return filePath; // Return the path for database storage
    } catch (e) {
      _showSnackBar('File upload failed: ${e.toString()}', Colors.red);
      return null;
    }
  }

  // --- MODIFIED: Rollback now also deletes uploaded files ---
  Future<void> _rollbackRegistration(String? userId, AccountType? accountType, List<String> uploadedFilePaths) async {
    // 1. Delete uploaded files from storage
    if (uploadedFilePaths.isNotEmpty) {
      try {
        await app_nav.supabase.storage.from('user_documents').remove(uploadedFilePaths);
      } catch (e) {
        _showSnackBar('Failed to clean up storage files.', Colors.orange);
      }
    }

    // 2. Delete database entries
    if (userId != null) {
      try {
        await app_nav.supabase.from('profiles').delete().eq('id', userId);

        if (accountType == AccountType.driver) {
          await app_nav.supabase.from('drivers').delete().eq('user_id', userId);
        } else if (accountType == AccountType.mechanic) {
          await app_nav.supabase.from('mechanics').delete().eq('user_id', userId);
        }
      } catch (e) {
        _showSnackBar('Failed to clean up incomplete registration. Please contact support.', Colors.orange);
      }
    }
  }

  Future<void> _getAddressFromNominatim(LatLng point) async {
    // ... (This function is unchanged)
    setState(() {
      _isGeocodingAddress = true;
      _businessAddressController.text = 'Fetching address...';
    });

    final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}';
    final headers = {'User-Agent': 'AutoFixApp (your-contact-email@example.com)'};

    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['display_name'] != null) {
          final address = data['display_name'];
          setState(() {
            _businessAddressController.text = address;
          });
        } else {
          setState(() {
            _businessAddressController.text = 'No address found for this location.';
            _showSnackBar('Address not found for selected coordinates. Please try another spot.', Colors.orange);
          });
        }
      } else {
        setState(() {
          _businessAddressController.text = 'Error fetching address.';
          _showSnackBar('Server error fetching address: ${response.statusCode}', Colors.red);
        });
      }
    } catch (e) {
      setState(() {
        _businessAddressController.text = 'Network error occurred.';
        _showSnackBar('Network error fetching address: ${e.toString()}', Colors.red);
      });
    } finally {
      setState(() {
        _isGeocodingAddress = false;
      });
    }
  }

  // --- MODIFIED: Main registration logic now includes file uploads ---
  Future<void> _registerAccount() async {
    if (_isRegistering || _isGeocodingAddress) return;

    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please correct the errors in the form.', Colors.red);
      return;
    }
    if (_selectedAccountType == null) {
      _showSnackBar('Please select an account type (Driver or Mechanic).', Colors.red);
      return;
    }
    
    // --- NEW: Add validation for mandatory ID file ---
    if (_idFile == null) {
      _showSnackBar('Please upload a valid ID.', Colors.red);
      return;
    }
    
    if (!_agreedToTerms) {
      _showSnackBar('You must agree to the Terms and Conditions.', Colors.red);
      return;
    }

    if (_selectedAccountType == AccountType.mechanic && _mechanicLatitudeLongitude == null) {
      _showSnackBar('Please select your business location on the map.', Colors.red);
      return;
    }

    if (_selectedAccountType == AccountType.mechanic && (_businessAddressController.text.contains('Fetching address') || _businessAddressController.text.contains('No address found'))) {
      _showSnackBar('Please wait for the address to be resolved or select a valid location.', Colors.red);
      return;
    }


    setState(() {
      _isRegistering = true;
    });

    String? userId;
    AccountType? registeredAccountType = _selectedAccountType;
    List<String> uploadedFilePaths = []; // To track files for rollback

    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text.trim();
      final String fullName = _fullNameController.text.trim();
      final String phoneNumber = _phoneNumberController.text.trim();

      // 1. Sign up the user
      final AuthResponse authResponse = await app_nav.supabase.auth.signUp(
        email: email,
        password: password,
      );

      final User? user = authResponse.user;

      if (user == null) {
        _showSnackBar('Registration failed: User account could not be created.', Colors.red);
        setState(() => _isRegistering = false);
        return;
      }

      userId = user.id;

      // 2. Upload Valid ID (mandatory)
      final String? idFilePath = await _uploadFileToBucket(_idFile!, 'user_documents', userId);
      if (idFilePath == null) {
        _showSnackBar('Failed to upload ID. Registration cancelled.', Colors.red);
        await _rollbackRegistration(userId, registeredAccountType, uploadedFilePaths);
        setState(() => _isRegistering = false);
        return;
      }
      uploadedFilePaths.add(idFilePath);

      // 3. Upload Certificate (optional, for mechanics)
      String? certFilePath;
      if (_selectedAccountType == AccountType.mechanic && _certificateFile != null) {
        certFilePath = await _uploadFileToBucket(_certificateFile!, 'user_documents', userId);
        if (certFilePath == null) {
          _showSnackBar('Failed to upload certificate. Registration cancelled.', Colors.red);
          await _rollbackRegistration(userId, registeredAccountType, uploadedFilePaths);
          setState(() => _isRegistering = false);
          return;
        }
        uploadedFilePaths.add(certFilePath);
      }

      // 4. Insert into 'profiles' table
      await app_nav.supabase.from('profiles').insert({
        'id': userId,
        'full_name': fullName,
        'email': email, // Save the email
        'phone_number': phoneNumber,
        'role': _selectedAccountType == AccountType.driver ? 'driver' : 'mechanic',
        'valid_id_url': idFilePath, // NEW: Save the ID file path
        'is_verified': false,      // NEW: Set verification to false by default
      });

      // 5. Insert into role-specific table
      if (_selectedAccountType == AccountType.driver) {
        await app_nav.supabase.from('drivers').insert({
          'user_id': userId,
          'first_name': _driverFirstNameController.text.trim(),
          'last_name': _driverLastNameController.text.trim(),
          'vehicle_type': _selectedVehicleType,
          'maker': _makerController.text.trim(),
          'model': _modelController.text.trim(),
          'year': _yearController.text.trim(),
          'license_plate': _licensePlateController.text.trim(),
        });
      } else if (_selectedAccountType == AccountType.mechanic) {
        await app_nav.supabase.from('mechanics').insert({
          'user_id': userId,
          'shop_name': _shopNameController.text.trim(),
          'business_type': _selectedBusinessType,
          'certifications': _certificationsController.text.trim(),
          'specialties': _specialtiesController.text.trim(),
          'years_experience': int.tryParse(_yearsExperienceController.text.trim()) ?? 0,
          'business_address': _businessAddressController.text.trim(),
          'latitude': _mechanicLatitudeLongitude!.latitude,
          'longitude': _mechanicLatitudeLongitude!.longitude,
          'certificate_url': certFilePath, // NEW: Save the certificate file path
        });
      }

      _showSnackBar('Registration successful! Please wait for admin verification.', Colors.green);
      _resetForm();

    } on AuthException catch (e) {
      _showSnackBar('Authentication error: ${e.message}', Colors.red);
    } on PostgrestException catch (e) {
      _showSnackBar('Database error: ${e.message}', Colors.red);
      await _rollbackRegistration(userId, registeredAccountType, uploadedFilePaths);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}', Colors.red);
      await _rollbackRegistration(userId, registeredAccountType, uploadedFilePaths);
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  // --- MODIFIED: Reset form now also clears files ---
  void _resetForm() {
    _formKey.currentState?.reset();
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
    setState(() {
      _selectedAccountType = null;
      _selectedVehicleType = null;
      _selectedBusinessType = null;
      _agreedToTerms = false;
      _passwordVisible = false;
      _mechanicLatitudeLongitude = null;
      _isGeocodingAddress = false;
      _idFile = null; // NEW
      _certificateFile = null; // NEW
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
                // --- Basic Info ---
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
                _buildTextField(_phoneNumberController, 'Phone Number', '09123456789', (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
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

                // --- NEW: Verification Section ---
                const Text(
                  'Verification Documents',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 10),
                _buildFileUploadButton(
                  title: 'Upload Valid ID (Required)',
                  file: _idFile,
                  onPressed: () => _pickFile(true),
                ),
                const SizedBox(height: 10),
                // --- End Verification Section ---

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
                if (_selectedAccountType == AccountType.driver)
                  _buildDriverDetailsForm(),
                if (_selectedAccountType == AccountType.mechanic)
                  _buildMechanicDetailsForm(),
                const SizedBox(height: 24),
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
                ElevatedButton(
                  onPressed: (_isRegistering || _isGeocodingAddress) ? null : _registerAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: (_isRegistering || _isGeocodingAddress)
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

  Widget _buildTextField(TextEditingController controller, String label, String hint, String? Function(String?)? validator, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
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
      validator: validator,
    );
  }

  // --- NEW: Helper widget for file upload buttons ---
  Widget _buildFileUploadButton({
    required String title,
    required XFile? file,
    required VoidCallback onPressed,
  }) {
    bool isUploaded = file != null;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        isUploaded ? Icons.check_circle : Icons.upload_file,
        color: isUploaded ? Colors.green : Colors.black54,
      ),
      label: Text(
        isUploaded ? file.name.split('/').last : title,
        style: TextStyle(
          color: isUploaded ? Colors.green : Colors.black54,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: isUploaded ? Colors.green : Colors.grey),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }


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
        const SizedBox(height: 16),

        // --- NEW: Certificate Upload Button ---
        _buildFileUploadButton(
          title: 'Upload Certificate (Optional)',
          file: _certificateFile,
          onPressed: () => _pickFile(false),
        ),
        const SizedBox(height: 24),
        // --- End New Button ---
        
        const Text(
          'Location & Service:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          _businessAddressController,
          'Business Address (from map)',
          _mechanicLatitudeLongitude == null ? 'Select location on map below' : '',
          (value) {
            if (value == null || value.isEmpty || _mechanicLatitudeLongitude == null || _businessAddressController.text.contains('No address found')) {
              return 'Please select your business address on the map.';
            }
            return null;
          },
          enabled: false,
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.map, color: Colors.white),
          label: _isGeocodingAddress
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Select on Map', style: TextStyle(color: Colors.white)),
          onPressed: _isGeocodingAddress ? null : () async {
            final LatLng? selectedLatLng = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectLocationOnMapScreen(
                  initialLocation: _mechanicLatitudeLongitude,
                ),
              ),
            );

            if (selectedLatLng != null) {
              setState(() {
                _mechanicLatitudeLongitude = selectedLatLng;
              });
              await _getAddressFromNominatim(selectedLatLng);
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
      ],
    );
  }
}