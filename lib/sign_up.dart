import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firebase_auth_service.dart';
import 'log_in.dart';
import 'courier_account.dart';
import 'customer_account.dart';

class SignUpScreen extends StatefulWidget {
  final String initialUserType;
  const SignUpScreen({super.key, this.initialUserType = 'customer'});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final mobileNumberController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final locationDescriptionController = TextEditingController();

  // Shop location controllers (for owners)
  final List<TextEditingController> shopNameControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> shopLatitudeControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> shopLongitudeControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> shopHoursControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int activeShopCount = 1; // Start with 1 shop location

  String userType = 'customer';
  int? selectedAge;
  String selectedMunicipality = 'Jordan';
  String selectedBarangay = 'Alibhon';
  String zipCode = '5045';
  String error = '';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Guimaras Municipalities and their Barangays
  final Map<String, List<String>> municipalityBarangays = {
    'Jordan': [
      'Alibhon',
      'Alaguisoc',
      'Balcon Maravilla',
      'Balcon Melliza',
      'Bugnay',
    ],
    'Buenavista': [
      'Agsanayan',
      'Alcaiaga',
      'Banban',
      'Buenavista Proper',
      'Cansilayan',
    ],
  };

  @override
  void initState() {
    super.initState();
    userType = widget.initialUserType;
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    mobileNumberController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    locationDescriptionController.dispose();
    for (var controller in shopNameControllers) {
      controller.dispose();
    }
    for (var controller in shopLatitudeControllers) {
      controller.dispose();
    }
    for (var controller in shopLongitudeControllers) {
      controller.dispose();
    }
    for (var controller in shopHoursControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showAccountExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Account Already Exists'),
        content: Text(
          'An account with email "$email" already exists in the system.\n\nWould you like to login instead?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectOperatingHours(int shopIndex) async {
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    // Show start time picker
    final pickedStartTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Select Opening Time',
    );

    if (pickedStartTime == null) return;
    startTime = pickedStartTime;

    // Show end time picker
    if (!mounted) return;
    final pickedEndTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Select Closing Time',
    );

    if (pickedEndTime == null) return;
    endTime = pickedEndTime;

    // Format the time range
    if (!mounted) return;
    final startFormatted = startTime.format(context);
    final endFormatted = endTime.format(context);
    final hoursText = '$startFormatted - $endFormatted';

    setState(() {
      shopHoursControllers[shopIndex].text = hoursText;
    });
  }

  void _handleSignUp() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final mobileNumber = mobileNumberController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Clear any error message
    setState(() => error = '');

    // Validate inputs
    if (firstName.isEmpty) {
      setState(() => error = 'Please enter your first name');
      return;
    }
    if (lastName.isEmpty) {
      setState(() => error = 'Please enter your last name');
      return;
    }
    if (selectedAge == null) {
      setState(() => error = 'Please select your age');
      return;
    }
    if (email.isEmpty || password.isEmpty) {
      setState(() => error = 'Please enter both email and password');
      return;
    }
    if (mobileNumber.isEmpty) {
      setState(() => error = 'Please enter your mobile number');
      return;
    }
    if (password != confirmPassword) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setState(() => error = 'Password must be at least 6 characters');
      return;
    }

    // Validate owner shop locations
    if (userType == 'owner') {
      bool hasValidShop = false;
      for (int i = 0; i < activeShopCount; i++) {
        if (shopNameControllers[i].text.trim().isNotEmpty) {
          hasValidShop = true;
          break;
        }
      }
      if (!hasValidShop) {
        setState(
          () => error = 'Please add at least one shop location with name',
        );
        return;
      }
    }

    // Sign out any existing session before attempting registration
    try {
      await FirebaseAuthService.instance.signOut();
    } catch (_) {
      // Ignore signout errors - user might not be signed in
    }

    // Create full address
    final address = '$selectedBarangay, $selectedMunicipality, Guimaras';
    final locationDescription = locationDescriptionController.text.trim();

    final err = await FirebaseAuthService.instance.register(
      email,
      password,
      userType,
      firstName: firstName,
      lastName: lastName,
      age: selectedAge,
      address: address,
      phone: mobileNumber,
      locationDescription: locationDescription,
    );

    if (!mounted) return;

    if (err != null) {
      setState(() => error = err);

      // If email already exists, offer to navigate to login
      if (err.contains('already registered') ||
          err.contains('already in use')) {
        _showAccountExistsDialog(email);
      }
      return;
    }

    // For owner and courier accounts, show pending approval message and don't attempt login
    if (userType == 'owner' || userType == 'courier') {
      if (!mounted) return;

      final accountTypeName = userType == 'owner' ? 'owner' : 'courier';

      // Show pending approval dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.pending, color: Colors.orange),
              SizedBox(width: 8),
              Text('Account Pending'),
            ],
          ),
          content: Text(
            'Your $accountTypeName account has been created.\\n\\n'
            'Waiting for Admin approval. For inquiries, please contact the admin.\\n\\n'
            'Admin Contact: 09123456789',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // For customer accounts, proceed with auto-login
    // Try to automatically sign the user in after successful registration
    // so the user is taken to the correct dashboard immediately.
    // ignore: avoid_print
    print(
      'SignUpScreen: registration succeeded for $email, attempting auto-login',
    );

    try {
      final userTypeRes = await FirebaseAuthService.instance.login(
        email,
        password,
      );

      if (!mounted) return;

      if (userTypeRes == null) {
        // If auto-login failed, navigate to login screen with a helpful message.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }

      // If auto-login succeeded, navigate directly to the appropriate dashboard.
      if (userTypeRes == 'courier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CourierDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CustomerAccount()),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // Handle pending/rejected account statuses
      if (e.code == 'account-pending' || e.code == 'account-rejected') {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(
              e.code == 'account-pending'
                  ? 'Account Pending'
                  : 'Account Rejected',
            ),
            content: Text(e.message ?? 'Unable to login'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Other auth errors
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = screenWidth * 0.06;
    final maxWidth = screenWidth > 600 ? 500.0 : screenWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Sign Up',
          style: TextStyle(fontSize: isSmallScreen ? 18 : 20),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1976d2),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                minHeight:
                    screenHeight -
                    MediaQuery.of(context).padding.vertical -
                    kToolbarHeight -
                    32,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isSmallScreen ? 16 : 24),
                  // First Name
                  TextField(
                    controller: firstNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Last Name
                  TextField(
                    controller: lastNameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Age Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<int>(
                      value: selectedAge,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      underline: const SizedBox(),
                      hint: const Text(
                        'Age',
                        style: TextStyle(color: Colors.black54),
                      ),
                      items: List.generate(53, (index) => index + 18).map((
                        age,
                      ) {
                        return DropdownMenuItem(
                          value: age,
                          child: Text(age.toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedAge = value;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Municipality Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: selectedMunicipality,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      underline: const SizedBox(),
                      hint: const Text(
                        'Municipality',
                        style: TextStyle(color: Colors.black54),
                      ),
                      items: municipalityBarangays.keys.map((municipality) {
                        return DropdownMenuItem(
                          value: municipality,
                          child: Text(municipality),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          selectedMunicipality = v ?? 'Jordan';
                          // Reset barangay to first in new municipality
                          selectedBarangay =
                              municipalityBarangays[selectedMunicipality]!
                                  .first;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Barangay Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: selectedBarangay,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      underline: const SizedBox(),
                      hint: const Text(
                        'Barangay',
                        style: TextStyle(color: Colors.black54),
                      ),
                      items: municipalityBarangays[selectedMunicipality]!.map((
                        barangay,
                      ) {
                        return DropdownMenuItem(
                          value: barangay,
                          child: Text(barangay),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          selectedBarangay =
                              v ??
                              municipalityBarangays[selectedMunicipality]!
                                  .first;
                        });
                      },
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Zip Code Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: zipCode.isEmpty ? '5045' : zipCode,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      underline: const SizedBox(),
                      hint: const Text(
                        'Zip Code',
                        style: TextStyle(color: Colors.black54),
                      ),
                      items: const [
                        DropdownMenuItem(value: '5045', child: Text('5045')),
                        DropdownMenuItem(value: '5046', child: Text('5046')),
                      ],
                      onChanged: (v) {
                        setState(() {
                          zipCode = v ?? '5045';
                        });
                      },
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Description of Location (for customers only)
                  if (userType == 'customer') ...[
                    TextField(
                      controller: locationDescriptionController,
                      style: const TextStyle(color: Colors.black),
                      decoration: InputDecoration(
                        labelText: 'Description of Location',
                        labelStyle: const TextStyle(color: Colors.black54),
                        border: const OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        hintText: 'e.g., Near church, beside store',
                      ),
                      maxLines: 2,
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                  ],
                  // Email
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Mobile Number
                  TextField(
                    controller: mobileNumberController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      hintText: '+63 9XX XXX XXXX',
                      hintStyle: const TextStyle(color: Colors.black38),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Password
                  TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // Confirm Password
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: const TextStyle(color: Colors.black54),
                      border: const OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  // User Type Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: userType,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'customer',
                          child: Text('Customer'),
                        ),
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text('Pasalubong Owner'),
                        ),
                        DropdownMenuItem(
                          value: 'courier',
                          child: Text('Local Courier'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => userType = v ?? 'customer'),
                    ),
                  ),
                  if (userType == 'owner') ...[
                    SizedBox(height: isSmallScreen ? 16 : 20),
                    Text(
                      'Shop Locations ($activeShopCount/3)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add up to 3 shop locations. Get coordinates from Google Maps.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.black54,
                      ),
                    ),
                    ...List.generate(activeShopCount, (index) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Shop Location ${index + 1}',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1976d2),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (index > 0)
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                  ),
                                  iconSize: 20,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    setState(() {
                                      shopNameControllers[index].clear();
                                      shopHoursControllers[index].clear();
                                      activeShopCount--;
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: shopNameControllers[index],
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Shop Name *',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: shopHoursControllers[index],
                            readOnly: true,
                            onTap: () => _selectOperatingHours(index),
                            style: const TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              labelText: 'Operating Hours',
                              labelStyle: const TextStyle(
                                color: Colors.black54,
                              ),
                              border: const OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: isSmallScreen ? 12 : 16,
                              ),
                              hintText: '8:00 AM - 6:00 PM',
                              suffixIcon: const Icon(
                                Icons.access_time,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    if (activeShopCount < 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              activeShopCount++;
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Another Location'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF1976d2),
                          ),
                        ),
                      ),
                  ],
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SizedBox(height: isSmallScreen ? 20 : 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleSignUp,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          isSmallScreen ? 44 : 48,
                        ),
                        backgroundColor: const Color(0xFF1976d2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Create Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 16 : 18,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 16 : 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
