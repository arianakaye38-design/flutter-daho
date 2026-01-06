import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../log_in.dart';
import '../../services/user_account_service.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _originalEmail = '';

  String _selectedGender = 'Male';
  String _selectedMunicipality = 'Jordan';
  String _selectedBarangay = 'Alibhon';
  String _selectedZipCode = '5045';
  final _locationDescriptionController = TextEditingController();
  bool _isLoading = true;
  bool _isEditing = false;
  bool _obscurePassword = true;
  String? _profileImageBase64;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

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
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _locationDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          _firstNameController.text = data['firstName'] ?? '';
          _lastNameController.text = data['lastName'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _emailController.text = user.email ?? '';
          _originalEmail = user.email ?? '';
          _contactController.text = data['phone'] ?? '';
          _selectedGender = data['gender'] ?? 'Male';
          _selectedZipCode = data['zipCode'] ?? '5045';
          _locationDescriptionController.text =
              data['locationDescription'] ?? '';
          _profileImageBase64 = data['profileImageBase64'];

          // Parse location string (format: "Barangay, Municipality, Guimaras")
          final location = data['location'] ?? '';
          if (location.isNotEmpty) {
            final parts = location.split(', ');
            if (parts.length >= 2) {
              final barangay = parts[0];
              final municipality = parts[1];

              // Validate and set municipality
              if (municipalityBarangays.containsKey(municipality)) {
                _selectedMunicipality = municipality;
                // Validate and set barangay
                if (municipalityBarangays[municipality]!.contains(barangay)) {
                  _selectedBarangay = barangay;
                } else {
                  _selectedBarangay =
                      municipalityBarangays[municipality]!.first;
                }
              }
            }
          }

          _isLoading = false;
        });
      } else {
        // Set email if document doesn't exist
        setState(() {
          _emailController.text = user.email ?? '';
          _originalEmail = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if email or password is being changed
    final emailChanged = _emailController.text.trim() != _originalEmail;
    final passwordChanged = _newPasswordController.text.isNotEmpty;

    // If email or password changed, require current password
    if ((emailChanged || passwordChanged) &&
        _currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your current password to change email or password',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate new password if provided
    if (passwordChanged) {
      if (_newPasswordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New password must be at least 6 characters'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String? imageBase64 = _profileImageBase64;

      // Convert image to base64 if a new one was selected
      if (_imageFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing image...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        imageBase64 = await _convertImageToBase64(_imageFile!);

        if (imageBase64 == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image processing failed. Profile will be saved without photo.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Handle email and password changes
      if (emailChanged && passwordChanged) {
        // Update both email and password
        final error = await UserAccountService.instance.updateEmailAndPassword(
          _emailController.text.trim(),
          _currentPasswordController.text,
          _newPasswordController.text,
        );

        if (error != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
          return;
        }
        _originalEmail = _emailController.text.trim();
      } else if (emailChanged) {
        // Update only email
        final error = await UserAccountService.instance.updateEmail(
          _emailController.text.trim(),
          _currentPasswordController.text,
        );

        if (error != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
          return;
        }
        _originalEmail = _emailController.text.trim();
      } else if (passwordChanged) {
        // Update only password
        final error = await UserAccountService.instance.updatePassword(
          _currentPasswordController.text,
          _newPasswordController.text,
        );

        if (error != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
          return;
        }
      }

      // Refresh user reference after credential changes (email migration creates new UID)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update Firestore user data
      final location = '$_selectedBarangay, $_selectedMunicipality, Guimaras';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'age': int.tryParse(_ageController.text.trim()) ?? 0,
            'location': location,
            'phone': _contactController.text.trim(),
            'gender': _selectedGender,
            'zipCode': _selectedZipCode,
            'locationDescription': _locationDescriptionController.text.trim(),
            if (imageBase64 != null) 'profileImageBase64': imageBase64,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() {
        _profileImageBase64 = imageBase64;
        _imageFile = null;
        _isLoading = false;
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _convertImageToBase64(File imageFile) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Check size (limit to ~500KB to stay well under Firestore's 1MB limit)
      if (bytes.length > 500000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Please select a smaller image.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      // Convert to base64
      final base64String = base64Encode(bytes);
      return base64String;
    } catch (e) {
      debugPrint('Error converting image to base64: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color(0xFF1976d2),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Avatar
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: const Color(0xFF1976d2),
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : (_profileImageBase64 != null
                                        ? MemoryImage(
                                            base64Decode(_profileImageBase64!),
                                          )
                                        : null)
                                    as ImageProvider?,
                          child:
                              (_imageFile == null &&
                                  _profileImageBase64 == null)
                              ? Text(
                                  _getInitials(),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        if (_isEditing)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1976d2),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // First Name
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      icon: Icons.person,
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age
                    _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      icon: Icons.cake,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your age';
                        }
                        final age = int.tryParse(value);
                        if (age == null || age < 1 || age > 120) {
                          return 'Please enter a valid age';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    _buildGenderField(),
                    const SizedBox(height: 16),

                    // Municipality
                    _buildLocationDropdown(
                      label: 'Municipality',
                      value: _selectedMunicipality,
                      items: municipalityBarangays.keys.toList(),
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                _selectedMunicipality = value!;
                                _selectedBarangay =
                                    municipalityBarangays[value]!.first;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Barangay
                    _buildLocationDropdown(
                      label: 'Barangay',
                      value: _selectedBarangay,
                      items: municipalityBarangays[_selectedMunicipality]!,
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                _selectedBarangay = value!;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Zip Code
                    _buildLocationDropdown(
                      label: 'Zip Code',
                      value: _selectedZipCode,
                      items: const ['5045', '5046'],
                      onChanged: _isEditing
                          ? (value) {
                              setState(() {
                                _selectedZipCode = value!;
                              });
                            }
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Description of Location
                    _buildTextField(
                      controller: _locationDescriptionController,
                      label: 'Description of Location',
                      icon: Icons.description,
                      enabled: _isEditing,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Province (read-only)
                    _buildTextField(
                      controller: TextEditingController(text: 'Guimaras'),
                      label: 'Province',
                      icon: Icons.location_city,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    // Email
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      enabled: _isEditing,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        final trimmedValue = value.trim();
                        final emailRegex = RegExp(
                          r"^[^@\s]+@[^@\s]+\.[^@\s]+$",
                        );
                        if (!emailRegex.hasMatch(trimmedValue)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Contact Number
                    _buildTextField(
                      controller: _contactController,
                      label: 'Contact Number',
                      icon: Icons.phone,
                      enabled: _isEditing,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your contact number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Password Section - Show when editing
                    if (_isEditing) ...[
                      const Divider(thickness: 2),
                      const SizedBox(height: 16),
                      const Text(
                        'Change Email or Password',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your current password to change email or password',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      // Current Password
                      _buildTextField(
                        controller: _currentPasswordController,
                        label: 'Current Password',
                        icon: Icons.lock_outline,
                        enabled: _isEditing,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // New Password
                      _buildTextField(
                        controller: _newPasswordController,
                        label: 'New Password (optional)',
                        icon: Icons.lock,
                        enabled: _isEditing,
                        obscureText: _obscurePassword,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm New Password',
                        icon: Icons.lock_clock,
                        enabled: _isEditing,
                        obscureText: _obscurePassword,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Leave password fields blank to keep current password',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Cancel button when editing
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _imageFile = null;
                          });
                          _loadUserProfile();
                          _currentPasswordController.clear();
                          _newPasswordController.clear();
                          _confirmPasswordController.clear();
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],

                    // Log Out button at the bottom
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop(true);
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Log Out'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Log Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  String _getInitials() {
    String initials = '';
    if (_firstNameController.text.isNotEmpty) {
      initials += _firstNameController.text[0].toUpperCase();
    }
    if (_lastNameController.text.isNotEmpty) {
      initials += _lastNameController.text[0].toUpperCase();
    }
    return initials.isEmpty ? 'U' : initials;
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: obscureText ? 1 : maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !enabled,
        fillColor: enabled ? null : Colors.grey[100],
      ),
    );
  }

  Widget _buildGenderField() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Gender',
        prefixIcon: const Icon(Icons.wc),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !_isEditing,
        fillColor: _isEditing ? null : Colors.grey[100],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isDense: true,
          onChanged: _isEditing
              ? (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedGender = newValue);
                  }
                }
              : null,
          items: ['Male', 'Female', 'Other'].map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: !_isEditing,
        fillColor: _isEditing ? null : Colors.grey[100],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
