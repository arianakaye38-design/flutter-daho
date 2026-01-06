import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddShopLocationScreen extends StatefulWidget {
  const AddShopLocationScreen({super.key});

  @override
  State<AddShopLocationScreen> createState() => _AddShopLocationScreenState();
}

class _AddShopLocationScreenState extends State<AddShopLocationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _hoursController = TextEditingController();

  LatLng _selectedLocation = const LatLng(
    10.6036,
    122.5927,
  ); // Default: Alibhon, Guimaras
  bool _isSaving = false;
  int _shopCount = 0;
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _existingLocations = [];
  bool _isLoading = true;
  bool _isAddingNew = false;

  @override
  void initState() {
    super.initState();
    _loadShopLocations();
    _loadShopProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload locations whenever the screen becomes visible
    if (!_isLoading) {
      _loadShopLocations();
    }
  }

  Future<void> _loadShopLocations() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      debugPrint('Loading shop locations for owner: $userId');

      final snapshot = await FirebaseFirestore.instance
          .collection('pasalubong_centers')
          .where('ownerId', isEqualTo: userId)
          .get();

      debugPrint('Found ${snapshot.docs.length} locations for this owner');

      setState(() {
        _shopCount = snapshot.docs.length;
        _existingLocations = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unnamed Shop',
                'hours':
                    doc.data()['operatingHours'] ??
                    doc.data()['hours'] ??
                    'N/A',
                'latitude': doc.data()['latitude'] ?? 10.6036,
                'longitude': doc.data()['longitude'] ?? 122.5927,
                'createdAt': doc.data()['createdAt'],
              },
            )
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading shop locations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadShopProfile() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Load shop details from the first pasalubong_center (if exists)
      final shopQuery = await FirebaseFirestore.instance
          .collection('pasalubong_centers')
          .where('ownerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (shopQuery.docs.isNotEmpty) {
        final shopData = shopQuery.docs.first.data();
        setState(() {
          // Pre-fill shop name if not already filled
          if (_shopNameController.text.isEmpty) {
            _shopNameController.text = shopData['name'] ?? '';
          }
          // Pre-fill operating hours if not already filled
          if (_hoursController.text.isEmpty) {
            _hoursController.text =
                shopData['operatingHours'] ?? shopData['hours'] ?? '';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading shop profile: $e');
    }
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _cancelEditing() {
    setState(() {
      _isAddingNew = false;
      _shopNameController.clear();
      _hoursController.clear();
      _selectedLocation = const LatLng(10.6036, 122.5927);
    });
    _loadShopProfile();
  }

  void _startAddingNew() {
    setState(() {
      _isAddingNew = true;
      _shopNameController.clear();
      _hoursController.clear();
      _selectedLocation = const LatLng(10.6036, 122.5927);
    });
    _loadShopProfile();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _removeLocation(String locationId, String shopName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Location'),
        content: Text('Are you sure you want to remove "$shopName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('pasalubong_centers')
          .doc(locationId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location removed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadShopLocations();
      _cancelEditing();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectOperatingHours() async {
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
      _hoursController.text = hoursText;
    });
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    if (_shopCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only add up to 3 shop locations'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};
      final name = userData['name'] ?? user.email ?? 'Unknown Owner';
      final phone = userData['phone'] ?? 'N/A';
      final address = userData['address'] ?? 'Guimaras';

      final locationData = {
        'name': _shopNameController.text.trim(),
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'location': address,
        'address': address,
        'phone': phone,
        'mobile': phone,
        'hours': _hoursController.text.trim().isNotEmpty
            ? _hoursController.text.trim()
            : 'N/A',
        'operatingHours': _hoursController.text.trim().isNotEmpty
            ? _hoursController.text.trim()
            : 'N/A',
        'owner': name,
        'ownerName': name,
        'ownerId': user.uid,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('pasalubong_centers')
          .add(locationData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shop location added successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _loadShopLocations();
      _cancelEditing();
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAddMore = _shopCount < 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isAddingNew ? 'Edit Shop Location' : 'Manage Shop Locations',
        ),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Shop count indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isAddingNew
                      ? Colors.orange[50]
                      : (canAddMore ? Colors.blue[50] : Colors.orange[50]),
                  child: Row(
                    children: [
                      Icon(
                        _isAddingNew
                            ? Icons.edit_location
                            : (canAddMore ? Icons.store : Icons.warning),
                        color: _isAddingNew
                            ? Colors.orange
                            : (canAddMore ? Colors.blue : Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _isAddingNew
                              ? 'Editing location - tap map to change pin position'
                              : (canAddMore
                                    ? 'Shop Locations: $_shopCount/3'
                                    : 'Maximum 3 locations reached'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isAddingNew
                                ? Colors.orange[900]
                                : (canAddMore
                                      ? Colors.blue[900]
                                      : Colors.orange[900]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Existing Locations List
                if (_existingLocations.isNotEmpty && !_isAddingNew)
                  Container(
                    color: Colors.grey[100],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Your Shop Locations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        ..._existingLocations.map((location) {
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFF1976d2),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                location['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text('Hours: ${location['hours']}'),
                                  Text(
                                    'Location: ${location['latitude'].toStringAsFixed(4)}, ${location['longitude'].toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (location['createdAt'] != null)
                                    Text(
                                      'Added: ${_formatDate(location['createdAt'])}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Remove location',
                                onPressed: () {
                                  _removeLocation(
                                    location['id'],
                                    location['name'],
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                // Map (only show when adding new or no locations exist)
                if (_isAddingNew || _existingLocations.isEmpty)
                  Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation,
                            initialZoom: 15,
                            onTap: (tapPosition, point) {
                              setState(() {
                                _selectedLocation = point;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            MarkerLayer(
                              markers: [
                                // Show selected/new location marker
                                if (_isAddingNew)
                                  Marker(
                                    point: _selectedLocation,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_pin,
                                      color: Colors.orange,
                                      size: 50,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (_isAddingNew)
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isAddingNew
                                        ? 'Tap on the map to change location'
                                        : 'Tap on the map to select shop location',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}, Lon: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                // Form (shown when editing or adding)
                if (_isAddingNew || _existingLocations.isEmpty)
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Shop Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.store),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter shop name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _hoursController,
                              readOnly: true,
                              onTap: _selectOperatingHours,
                              decoration: const InputDecoration(
                                labelText: 'Operating Hours',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                                hintText: 'Tap to select hours',
                                suffixIcon: Icon(Icons.arrow_drop_down),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                if (_isAddingNew || _isAddingNew) ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _cancelEditing,
                                      icon: const Icon(Icons.cancel),
                                      label: const Text('Cancel'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isSaving ||
                                            (!_isAddingNew && !canAddMore)
                                        ? null
                                        : _saveLocation,
                                    icon: _isSaving
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            _isAddingNew
                                                ? Icons.save
                                                : Icons.add_location,
                                          ),
                                    label: Text(
                                      _isSaving
                                          ? 'Saving...'
                                          : (_isAddingNew
                                                ? 'Update Location'
                                                : 'Add Location'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976d2),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: canAddMore && !_isAddingNew && !_isAddingNew
          ? FloatingActionButton(
              onPressed: _startAddingNew,
              backgroundColor: const Color(0xFF1976d2),
              tooltip: 'Add New Location',
              child: const Icon(Icons.add_location, color: Colors.white),
            )
          : null,
    );
  }
}
