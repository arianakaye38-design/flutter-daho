import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'features/customer/shop_screen.dart';
import 'features/customer/notifications_screen.dart';
import 'features/customer/profile_screen.dart';
import 'features/customer/messages_screen.dart';

class CustomerAccount extends StatefulWidget {
  const CustomerAccount({super.key});

  @override
  State<CustomerAccount> createState() => _CustomerAccountState();

  // Center around Alibhon, Guimaras (approximate)
  static final LatLng alibhonCenter = LatLng(10.6036, 122.5927);
}

class _CustomerAccountState extends State<CustomerAccount> {
  Marker? _courierMarker;
  List<Map<String, dynamic>> _landmarks = [];

  @override
  void initState() {
    super.initState();
    _loadPasalubongCenters();
  }

  Future<void> _loadPasalubongCenters() async {
    try {
      // Load pasalubong centers from Firestore
      final centersSnapshot = await FirebaseFirestore.instance
          .collection('pasalubong_centers')
          .get();

      final List<Map<String, dynamic>> landmarks = [];

      // Add pasalubong centers from database
      for (var doc in centersSnapshot.docs) {
        final data = doc.data();

        // Handle both GeoPoint and separate lat/long fields
        double? latitude;
        double? longitude;

        if (data['location'] != null && data['location'] is GeoPoint) {
          final GeoPoint geoPoint = data['location'] as GeoPoint;
          latitude = geoPoint.latitude;
          longitude = geoPoint.longitude;
        } else if (data['latitude'] != null && data['longitude'] != null) {
          latitude = data['latitude'] as double;
          longitude = data['longitude'] as double;
        }

        if (latitude != null && longitude != null) {
          // Try to get contact from center data first, then from owner's user account
          String contactNumber = data['mobile'] ?? data['phone'] ?? '';
          String ownerName = data['owner'] ?? data['ownerName'] ?? 'N/A';
          String ownerId = data['ownerId'] ?? data['userId'] ?? doc.id;

          // First, try to get shop photo from pasalubong_centers document itself
          String shopImageBase64 = data['shopImageBase64'] ?? '';
          debugPrint(
            '[SHOP PHOTO] From pasalubong_centers for $ownerName: ${shopImageBase64.isNotEmpty ? "YES (${shopImageBase64.length} chars)" : "NO"}',
          );

          // If no contact in center data, fetch from owner's user account
          if (contactNumber.isEmpty && ownerId.isNotEmpty) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(ownerId)
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data();
                contactNumber = userData?['phone'] ?? userData?['mobile'] ?? '';
                if (ownerName == 'N/A') {
                  ownerName = userData?['name'] ?? 'N/A';
                }
                // Only override if we didn't get it from pasalubong_centers
                if (shopImageBase64.isEmpty) {
                  shopImageBase64 = userData?['shopImageBase64'] ?? '';
                  debugPrint(
                    '[SHOP PHOTO] From users collection for $ownerName: ${shopImageBase64.isNotEmpty ? "YES (${shopImageBase64.length} chars)" : "NO"}',
                  );
                }
              }
            } catch (e) {
              debugPrint('Error fetching owner contact: $e');
            }
          } else if (ownerId.isNotEmpty && shopImageBase64.isEmpty) {
            // Fetch shop photo from users collection if not in pasalubong_centers
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(ownerId)
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data();
                shopImageBase64 = userData?['shopImageBase64'] ?? '';
                debugPrint(
                  '[SHOP PHOTO] From users collection (alt path) for $ownerName: ${shopImageBase64.isNotEmpty ? "YES (${shopImageBase64.length} chars)" : "NO"}',
                );
              }
            } catch (e) {
              debugPrint('Error fetching owner shop photo: $e');
            }
          }

          landmarks.add({
            'name': data['name'] ?? 'Unknown Shop',
            'type': 'pasalubong',
            'position': LatLng(latitude, longitude),
            'location':
                data['address'] ?? data['location']?.toString() ?? 'Guimaras',
            'mobile': contactNumber.isNotEmpty ? contactNumber : 'N/A',
            'hours': data['hours'] ?? data['operatingHours'] ?? 'N/A',
            'owner': ownerName,
            'ownerId': ownerId,
            'shopImageBase64': shopImageBase64,
          });
        }
      }

      setState(() {
        _landmarks = landmarks;
      });
    } catch (e) {
      debugPrint('Error loading pasalubong centers: $e');
    }
  }

  void _onMarkerTap(Map<String, dynamic> lm) {
    final String type = (lm['type'] as String);
    final String shopName = lm['name'] as String;
    final bool isPasalubong = type == 'pasalubong';

    debugPrint(
      '[MARKER TAP] Shop: $shopName, Has shopImageBase64: ${lm['shopImageBase64'] != null && (lm['shopImageBase64'] as String).isNotEmpty}',
    );

    // Show a bottom sheet for all location types
    String shopId = '';
    if (isPasalubong) {
      // Use the owner's user ID from the landmark data if available
      shopId =
          lm['ownerId'] ??
          lm['userId'] ??
          shopName.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (isPasalubong &&
                    lm['shopImageBase64'] != null &&
                    (lm['shopImageBase64'] as String).isNotEmpty)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: MemoryImage(base64Decode(lm['shopImageBase64'])),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Icon(
                    isPasalubong ? Icons.storefront : Icons.church,
                    size: 48,
                    color: isPasalubong ? Colors.deepOrange : Colors.redAccent,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPasalubong ? 'Pasalubong Center' : 'Place of Worship',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPasalubong) ...[
              const SizedBox(height: 16),
              _buildInfoRow(Icons.location_on, lm['location'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.phone, lm['mobile'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.access_time, lm['hours'] ?? 'N/A'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.person, lm['owner'] ?? 'N/A'),
            ],
            const SizedBox(height: 20),
            if (isPasalubong) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ShopDetailScreen(shopId: shopId, shopName: shopName),
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_bag),
                label: const Text('View Products'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976d2),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'This is a place of worship.\nNo products available here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: const Icon(Icons.account_circle, size: 40),
            iconSize: 40,
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerProfileScreen(),
                ),
              );
            },
          ),
        ),
        title: const Text('Customer Map'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              // Newer flutter_map versions use initialCenter/initialZoom.
              initialCenter: CustomerAccount.alibhonCenter,
              initialZoom: 15,
              minZoom: 12,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.daho',
                // Prevent requesting tiles beyond available native zoom which can
                // cause blank/white areas when users over-zoom the map.
                maxNativeZoom: 18,
                maxZoom: 18,
              ),
              MarkerLayer(
                // In newer flutter_map, MarkerLayer expects `markers` as before,
                // but Marker instances now use `child` instead of `builder`.
                markers: [
                  ..._landmarks.map((land) {
                    final LatLng pos = land['position'] as LatLng;
                    return Marker(
                      point: pos,
                      width: 48,
                      height: 48,
                      child: GestureDetector(
                        onTap: () => _onMarkerTap(land),
                        child: Icon(
                          _iconForType(land['type'] as String),
                          color: land['type'] == 'pasalubong'
                              ? Colors.deepOrange
                              : Colors.redAccent,
                          size: 36,
                        ),
                      ),
                    );
                  }),
                  if (_courierMarker != null) _courierMarker!,
                ],
              ),
            ],
          ),
          // Bottom navigation buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomButton(
                    icon: Icons.shopping_bag,
                    label: 'Pasalubong Shops',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notifications')
                        .where(
                          'userId',
                          isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                        )
                        .where('userType', isEqualTo: 'customer')
                        .where('read', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;

                      return _buildBottomButton(
                        icon: Icons.notifications,
                        label: 'Notifications',
                        badge: unreadCount > 0 ? unreadCount : null,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CustomerNotificationsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  _buildBottomButton(
                    icon: Icons.message,
                    label: 'Messages',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CustomerMessagesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    int? badge,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976d2).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 26, color: const Color(0xFF1976d2)),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF1976d2),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badge > 9 ? '9+' : badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'school':
        return Icons.school;
      case 'church':
        return Icons.church;
      case 'pasalubong':
        return Icons.storefront;
      case 'government':
        return Icons.account_balance;
      default:
        return Icons.location_on;
    }
  }
}
