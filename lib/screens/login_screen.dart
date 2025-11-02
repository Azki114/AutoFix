// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:autofix/main.dart'; // To access the global 'supabase' client
import 'package:autofix/main.dart' as app_nav; // For NavigationDrawer

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false; // New loading state for the button

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) { // Ensure widget is still in the tree before showing SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _signIn() async {
    if (_isLoading) return; // Prevent multiple submissions
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please enter valid credentials.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        _showSnackBar('Login successful!', Colors.green);
        // Navigate to the home screen or dashboard after successful login
        // The '/' route in main.dart will handle role-based redirection
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      } else {
        // This block might be hit if signInWithPassword doesn't throw but user is null
        _showSnackBar('Login failed. Please check your email and password.', Colors.red);
      }
    } on AuthException catch (e) {
      // Handle specific Supabase Auth errors
      _showSnackBar('Authentication error: ${e.message}', Colors.red);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}', Colors.red);
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false; // Always reset loading state
        });
      }
    }
  }

  // --- MODIFIED: Function to handle the forgot password logic ---
  Future<void> _forgotPassword() async {
    final email = await _showForgotPasswordDialog();
    if (email == null || email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // This sends the password reset email
      // We must specify the redirectTo to create the correct deep link
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.autofix://login', // <-- THE FIX IS HERE
      );
      if (mounted) {
        _showSnackBar('Password reset link sent to $email.', Colors.green);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message, Colors.red);
    } catch (e) {
      _showSnackBar('An unexpected error occurred: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: Dialog to ask for the user's email ---
  Future<String?> _showForgotPasswordDialog() {
    final emailDialogController = TextEditingController();
    // Pre-fill with the email from the login form if it exists
    emailDialogController.text = _emailController.text;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email to receive a password reset link.'),
              const SizedBox(height: 16),
              TextFormField( // Use TextFormField for validation
                controller: emailDialogController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  icon: Icon(Icons.email),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty || !val.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Basic check before closing dialog
                if (emailDialogController.text.isNotEmpty && emailDialogController.text.contains('@')) {
                  Navigator.of(context).pop(emailDialogController.text.trim());
                } else {
                  // Show a quick snackbar *inside* the dialog if possible, or just don't close.
                  // For simplicity, we'll just rely on the user to enter a valid email.
                  // A better implementation would use a Form inside the dialog.
                  Navigator.of(context).pop(emailDialogController.text.trim());
                }
              },
              child: const Text('Send Link'),
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
        title: const Text('Login',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(),
      backgroundColor: const Color.fromARGB(255, 230, 240, 255), // Light blue background
      body: SafeArea(
        child: Center( // Center the card
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card( // Use a Card for the white, rounded container
              margin: const EdgeInsets.symmetric(horizontal: 16.0), // Add some horizontal margin
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Rounded corners for the card
              ),
              elevation: 8, // Add shadow
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Make column only take required height
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Large Arrow Icon
                      Align(
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_forward, // Changed icon to match image
                          size: 80,
                          color: Colors.blue[600], // Slightly darker blue for icon
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome Back!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28, // Increased font size
                          fontWeight: FontWeight.bold,
                          color: Colors.black87, // Darker text for prominence
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Log in to access your AUTOFIX account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 24),

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com', // Updated hint text
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
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
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters long';
                          }
                          return null;
                        },
                      ),
                      
                      // --- NEW: FORGOT PASSWORD BUTTON ---
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isLoading ? null : _forgotPassword,
                          child: const Text(
                            'Forgot Password?',
                             style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12), // Adjusted spacing

                      // Login Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signIn, // Disable when loading
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Log In', // Changed text to match image
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Link to Registration Screen
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/register');
                        },
                        child: const Text(
                          'Don\'t have an account? Sign up', // Updated text to match image
                          style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

