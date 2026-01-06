// Suppress info about using BuildContext across async gaps here. The
// courier dashboard uses synchronous navigation/showDialog calls; if we add
// async work later we'll add proper mounted checks instead of silencing.
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'notifications_page.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'features/courier/delivery_history_screen.dart';
import 'features/customer/shop_screen.dart';
import 'features/courier/order_notifications_screen.dart';
import 'features/courier/profile_screen.dart';
import 'features/courier/messages_screen.dart';

class CourierDashboard extends StatefulWidget {
  const CourierDashboard({super.key});

  @override
  State<CourierDashboard> createState() => _CourierDashboardState();

  // Center around Alibhon, Guimaras (approximate)
  static final LatLng alibhonCenter = LatLng(10.6036, 122.5927);
}

class _CourierDashboardState extends State<CourierDashboard> {
  String _userEmail = '';
  String _userPhone = '';
  String _courierName = 'Courier';
  String? _profileImageBase64;
  List<Map<String, dynamic>> _landmarks = [];
  bool _isLoadingLandmarks = true;

  @override
  void initState() {
    super.initState();
    _setOnlineStatus();
    _loadUserEmail();
    _loadUserPhone();
    _loadCourierName();
    _loadProfileImage();
    _loadPasalubongCenters();
  }

  void _loadUserEmail() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _userEmail = user.email!;
      });
    }
  }

  Future<void> _loadUserPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        if (!mounted) return;
        setState(() {
          _userPhone = userDoc.data()?['phone'] ?? '+63 9XX XXX XXX';
        });
      }
    } catch (e) {
      debugPrint('Failed to load phone number: $e');
    }
  }

  Future<void> _loadCourierName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final name =
            data?['name'] ?? data?['email']?.split('@')[0] ?? 'Courier';
        if (!mounted) return;
        setState(() {
          _courierName = name;
        });
      }
    } catch (e) {
      debugPrint('Failed to load courier name: $e');
    }
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (!mounted) return;
        setState(() {
          _profileImageBase64 = data?['profileImageBase64'];
        });
      }
    } catch (e) {
      debugPrint('Failed to load profile image: $e');
    }
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
        if (data['latitude'] != null && data['longitude'] != null) {
          landmarks.add({
            'name': data['name'] ?? 'Unknown Shop',
            'type': 'pasalubong',
            'position': LatLng(
              data['latitude'] as double,
              data['longitude'] as double,
            ),
            'location': data['location'] ?? data['address'] ?? 'Guimaras',
            'mobile': data['mobile'] ?? data['phone'] ?? 'N/A',
            'hours': data['hours'] ?? data['operatingHours'] ?? 'N/A',
            'owner': data['owner'] ?? data['ownerName'] ?? 'N/A',
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _landmarks = landmarks;
        _isLoadingLandmarks = false;
      });
    } catch (e) {
      debugPrint('Error loading pasalubong centers: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingLandmarks = false;
      });
    }
  }

  // Automatically set courier as online when dashboard loads
  Future<void> _setOnlineStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Set courier as online in Firestore
      await FirebaseFirestore.instance
          .collection('couriers')
          .doc(user.uid)
          .set({
            'userId': user.uid,
            'isOnline': true,
            'isAvailable': true,
            'lastOnline': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed to set online status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

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
                MaterialPageRoute(builder: (_) => const CourierProfileScreen()),
              );
            },
          ),
        ),
        title: const Text('Courier Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Refreshed')));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 90,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Section
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _profileImageBase64 != null
                          ? CircleAvatar(
                              radius: isDesktop ? 45 : 35,
                              backgroundImage: MemoryImage(
                                base64Decode(_profileImageBase64!),
                              ),
                            )
                          : FaIcon(
                              // ignore: deprecated_member_use
                              FontAwesomeIcons.userCircle,
                              size: isDesktop ? 90 : 70,
                              color: const Color(0xFF9CA3AF),
                            ),
                      const SizedBox(height: 8),
                      Text(
                        _courierName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: Color(0xFF111827),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Auto-online status indicator (read-only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ONLINE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• Available for deliveries',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          InfoRow(
                            // ignore: deprecated_member_use
                            icon: FontAwesomeIcons.phoneAlt,
                            iconColor: Colors.green,
                            text: _userPhone.isNotEmpty
                                ? _userPhone
                                : 'Loading...',
                          ),
                          InfoRow(
                            icon: FontAwesomeIcons.envelope,
                            iconColor: Colors.green,
                            text: _userEmail.isNotEmpty
                                ? _userEmail
                                : 'Loading...',
                          ),
                        ],
                      ),
                      if (isDesktop) ...[
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.bell,
                                size: 22,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Messages',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CourierMessagesScreen(),
                                  ),
                                );
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.message,
                                size: 22,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            IconButton(
                              tooltip: 'History',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CourierDeliveryHistoryScreen(),
                                  ),
                                );
                              },
                              icon: const FaIcon(
                                FontAwesomeIcons.clockRotateLeft,
                                size: 22,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Orders Section with Tabs
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        // Header with tabs
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: const TabBar(
                            labelColor: Color(0xFF1976d2),
                            unselectedLabelColor: Color(0xFF6B7280),
                            indicatorColor: Color(0xFF1976d2),
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            tabs: [
                              Tab(text: 'Confirmed Orders'),
                              Tab(text: 'Active Deliveries'),
                            ],
                          ),
                        ),
                        // Tab content
                        SizedBox(
                          height: 300,
                          child: TabBarView(
                            children: [
                              // Confirmed Orders Tab
                              _buildOrdersList(['confirmed']),
                              // Active Deliveries Tab
                              _buildOrdersList(['picked_up', 'in_delivery']),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Map Section
                Container(
                  height: isDesktop ? 300 : 400,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Map & Route Navigation (GIS)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoadingLandmarks
                            ? const Center(child: CircularProgressIndicator())
                            : ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter:
                                        CourierDashboard.alibhonCenter,
                                    initialZoom: 15,
                                    minZoom: 12,
                                    maxZoom: 18,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.daho',
                                      maxNativeZoom: 18,
                                      maxZoom: 18,
                                    ),
                                    MarkerLayer(
                                      markers: _landmarks.map((land) {
                                        final LatLng pos =
                                            land['position'] as LatLng;
                                        return Marker(
                                          point: pos,
                                          width: 48,
                                          height: 48,
                                          child: GestureDetector(
                                            onTap: () => _onMarkerTap(land),
                                            child: Icon(
                                              _iconForType(
                                                land['type'] as String,
                                              ),
                                              color:
                                                  land['type'] == 'pasalubong'
                                                  ? Colors.deepOrange
                                                  : Colors.redAccent,
                                              size: 36,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CourierOrderNotificationsScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1976d2,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.list_alt,
                                size: 24,
                                color: Color(0xFF1976d2),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Orders',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1976d2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CourierMessagesScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1976d2,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.message,
                                size: 22,
                                color: Color(0xFF1976d2),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Messages',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1976d2),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CourierDeliveryHistoryScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF1976d2,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history,
                                size: 24,
                                color: Color(0xFF1976d2),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'History',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1976d2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<String> statuses) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: statuses)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    statuses.contains('confirmed')
                        ? 'No pending orders'
                        : 'No active deliveries',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Filter orders: for confirmed orders, exclude those assigned to other couriers
        final allOrders = snapshot.data!.docs;
        final filteredOrders = allOrders.where((doc) {
          final order = doc.data() as Map<String, dynamic>;
          final courierId = order['courierId'];

          // For confirmed orders, only show unassigned or assigned to current courier
          if (statuses.contains('confirmed') &&
              order['status'] == 'confirmed') {
            return courierId == null || courierId == user.uid;
          }

          // For active deliveries, only show assigned to current courier
          if (statuses.contains('picked_up') ||
              statuses.contains('in_delivery')) {
            return courierId == user.uid;
          }

          return true;
        }).toList();

        if (filteredOrders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    statuses.contains('confirmed')
                        ? 'No available orders'
                        : 'No active deliveries',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredOrders.length,
          itemBuilder: (context, index) {
            final doc = filteredOrders[index];
            final order = doc.data() as Map<String, dynamic>;
            final orderId = order['orderId'] ?? doc.id;
            final status = order['status'] ?? 'pending';
            final customerName = order['customerName'] ?? 'Unknown';
            final customerAddress = order['customerAddress'] ?? 'N/A';
            final locationDescription = order['locationDescription'] ?? '';
            final centerName = order['centerName'] ?? 'Shop';
            final isAssignedToCourier = order['courierId'] == user.uid;

            // Get first product name or count of items
            String productInfo = 'Order items';
            if (order['items'] != null && (order['items'] as List).isNotEmpty) {
              final items = order['items'] as List;
              if (items.length == 1) {
                productInfo = items[0]['name'] ?? 'Product';
              } else {
                productInfo = '${items.length} items';
              }
            }

            // Determine status display
            String statusText;
            Color statusColor;
            Color statusTextColor;

            switch (status) {
              case 'confirmed':
                statusText = isAssignedToCourier ? 'Accepted' : 'Ready to Pick';
                statusColor = const Color(0xFFFDE68A);
                statusTextColor = const Color(0xFF92400E);
                break;
              case 'picked_up':
                statusText = 'Picked Up';
                statusColor = const Color(0xFFA7F3D0);
                statusTextColor = const Color(0xFF065F46);
                break;
              case 'in_delivery':
                statusText = 'In Delivery';
                statusColor = const Color(0xFFBFDBFE);
                statusTextColor = const Color(0xFF1E40AF);
                break;
              default:
                statusText = status;
                statusColor = const Color(0xFFE5E7EB);
                statusTextColor = const Color(0xFF374151);
            }

            // For confirmed orders without courier assignment, show accept/reject buttons
            if (status == 'confirmed' && !isAssignedToCourier) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '#${orderId.substring(0, 8)} - $customerName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product: $productInfo',
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Pickup: $centerName',
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dropoff: $customerAddress',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showRejectConfirmation(orderId),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showAcceptConfirmation(orderId, order),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            // For confirmed orders assigned to courier, show reject/accept options
            if (status == 'confirmed' && isAssignedToCourier) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      title: Text(
                        '#${orderId.substring(0, 8)} - $customerName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product: $productInfo',
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Pickup: $centerName',
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Dropoff: $customerAddress',
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (locationDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Location Info: $locationDescription',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showRejectConfirmation(orderId),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmPickup(orderId),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Accept'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return DeliveryCard(
              orderId: '#${orderId.substring(0, 8)}',
              orderDocId: orderId,
              status: statusText,
              orderStatus: status,
              statusColor: statusColor,
              statusTextColor: statusTextColor,
              customer: customerName,
              product: productInfo,
              pickup: centerName,
              dropoff: customerAddress,
              locationDescription: locationDescription,
              showActionButtons:
                  isAssignedToCourier &&
                  (status == 'picked_up' || status == 'in_delivery'),
              orderData: order,
              courierName: _courierName,
              courierPhone: _userPhone,
            );
          },
        );
      },
    );
  }

  void _showAcceptConfirmation(String orderId, Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to accept this delivery?'),
            const SizedBox(height: 12),
            Text('Order: #${orderId.substring(0, 8)}'),
            Text('Customer: ${order['customerName'] ?? 'N/A'}'),
            Text('Pickup: ${order['centerName'] ?? 'N/A'}'),
            Text('Dropoff: ${order['customerAddress'] ?? 'N/A'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _acceptDelivery(orderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectConfirmation(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Delivery'),
        content: Text(
          'Are you sure you want to reject order #${orderId.substring(0, 8)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _rejectDelivery(orderId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDelivery(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get order details first
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;

      // Get existing rejected courier IDs list or create new one
      final rejectedCourierIds = List<String>.from(
        orderData['rejectedCourierIds'] ?? [],
      );
      if (!rejectedCourierIds.contains(user.uid)) {
        rejectedCourierIds.add(user.uid);
      }

      // Check how many couriers are available to compare with rejections
      final couriersSnapshot = await FirebaseFirestore.instance
          .collection('couriers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();

      final totalAvailableCouriers = couriersSnapshot.docs.length;
      final allCouriersRejected =
          totalAvailableCouriers > 0 &&
          rejectedCourierIds.length >= totalAvailableCouriers;

      // Update order - change status to rejected and store courier info
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
          'rejectedBy': user.uid,
          'rejectedByCourierName': _courierName,
          'rejectedByCourierPhone': _userPhone,
          'rejectedByCourierEmail': user.email,
          'rejectedCourierIds':
              rejectedCourierIds, // Store list of all rejected couriers
          'allCouriersRejected': allCouriersRejected,
          'courierId': FieldValue.delete(),
          'courierEmail': FieldValue.delete(),
          'courierName': FieldValue.delete(),
        },
      );

      // Send notifications to all owners in the order
      final ownerIds = orderData['ownerIds'] as List?;
      if (ownerIds != null) {
        for (final ownerId in ownerIds) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': ownerId,
            'userType': 'owner',
            'type': 'courier_rejected',
            'title': 'Courier Rejected Order',
            'message': allCouriersRejected
                ? 'All available couriers have rejected order #${orderId.substring(0, 8)}. Please find another courier or cancel the order.'
                : 'Courier $_courierName rejected order #${orderId.substring(0, 8)} pickup. Looking for another courier...',
            'orderId': orderId,
            'courierEmail': user.email,
            'courierName': _courierName,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Notify customer if all couriers rejected
      if (allCouriersRejected) {
        final customerId = orderData['customerId'];
        if (customerId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': customerId,
            'userType': 'customer',
            'type': 'all_couriers_rejected',
            'title': 'Order Delivery Issue',
            'message':
                'Unfortunately, all available couriers have declined your order #${orderId.substring(0, 8)}. The shop owner will review and may cancel or find an alternative delivery method. You will be notified of any updates.',
            'orderId': orderId,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order rejected successfully'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptDelivery(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get order details first
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;

      // Update order with courier info and change status to picked_up
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'courierId': user.uid,
            'courierEmail': user.email,
            'courierName': _courierName,
            'status': 'picked_up',
            'acceptedAt': FieldValue.serverTimestamp(),
          });

      // Initialize message conversation between courier and customer
      try {
        // Check if conversation already exists
        final existingConversation = await FirebaseFirestore.instance
            .collection('messages')
            .where('courierId', isEqualTo: user.uid)
            .where('userId', isEqualTo: orderData['customerId'])
            .limit(1)
            .get();

        if (existingConversation.docs.isEmpty) {
          // Create new conversation
          await FirebaseFirestore.instance.collection('messages').add({
            'courierId': user.uid,
            'userId': orderData['customerId'],
            'courierName': _courierName,
            'userName': orderData['customerName'] ?? 'Customer',
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCountCourier': 0,
            'unreadCountUser': 0,
            'deletedByCourier': false,
            'deletedByUser': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Failed to create message conversation: $e');
      }

      // Create notification for customer
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': orderData['customerId'],
        'userType': 'customer',
        'type': 'courier_accepted',
        'title': 'Courier Assigned',
        'message':
            'A courier has accepted your order #${orderId.substring(0, 8)}',
        'orderId': orderId,
        'courierEmail': user.email,
        'courierName': _courierName,
        'courierPhone': _userPhone,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create notifications for each owner in the order
      final ownerIds = orderData['ownerIds'] as List?;
      if (ownerIds != null) {
        for (final ownerId in ownerIds) {
          // Initialize message conversation between courier and owner
          try {
            // Check if conversation already exists
            final existingOwnerConversation = await FirebaseFirestore.instance
                .collection('messages')
                .where('courierId', isEqualTo: user.uid)
                .where('ownerId', isEqualTo: ownerId)
                .limit(1)
                .get();

            if (existingOwnerConversation.docs.isEmpty) {
              // Get owner name
              String ownerName = 'Owner';
              try {
                final ownerDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(ownerId)
                    .get();
                if (ownerDoc.exists) {
                  ownerName = ownerDoc.data()?['name'] ?? 'Owner';
                }
              } catch (e) {
                debugPrint('Failed to fetch owner name: $e');
              }

              // Create new conversation
              await FirebaseFirestore.instance.collection('messages').add({
                'courierId': user.uid,
                'ownerId': ownerId,
                'courierName': _courierName,
                'ownerName': ownerName,
                'lastMessage': '',
                'lastMessageTime': FieldValue.serverTimestamp(),
                'unreadCountCourier': 0,
                'unreadCountOwner': 0,
                'deletedByCourier': false,
                'deletedByOwner': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            debugPrint('Failed to create owner-courier conversation: $e');
          }

          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': ownerId,
            'userType': 'owner',
            'type': 'courier_accepted',
            'title': 'Courier Assigned to Order',
            'message':
                'Courier $_courierName accepted order #${orderId.substring(0, 8)} and picked up the items',
            'orderId': orderId,
            'courierEmail': user.email,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted and marked as picked up!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmPickup(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get order details first
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;

      // Update order status to picked_up
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': 'picked_up', 'pickedUpAt': FieldValue.serverTimestamp()},
      );

      // Create notification for customer
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': orderData['customerId'],
        'userType': 'customer',
        'type': 'order_picked_up',
        'title': 'Order Picked Up',
        'message':
            'Your order #${orderId.substring(0, 8)} has been picked up by the courier',
        'orderId': orderId,
        'courierEmail': user.email,
        'courierName': _courierName,
        'courierPhone': _userPhone,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create notifications for each owner in the order
      final ownerIds = orderData['ownerIds'] as List?;
      if (ownerIds != null) {
        for (final ownerId in ownerIds) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': ownerId,
            'userType': 'owner',
            'type': 'order_picked_up',
            'title': 'Order Picked Up',
            'message':
                'Courier $_courierName picked up order #${orderId.substring(0, 8)}',
            'orderId': orderId,
            'courierEmail': user.email,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as picked up!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm pickup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onMarkerTap(Map<String, dynamic> lm) {
    final String type = (lm['type'] as String);
    final String shopName = lm['name'] as String;
    final bool isPasalubong = type == 'pasalubong';

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
                Icon(
                  isPasalubong ? Icons.storefront : Icons.church,
                  size: 32,
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

// Reusable widgets below

class InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const InfoRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class DeliveryCard extends StatelessWidget {
  final String orderId;
  final String orderDocId;
  final String status;
  final String orderStatus;
  final Color statusColor;
  final Color statusTextColor;
  final String customer;
  final String product;
  final String pickup;
  final String dropoff;
  final String locationDescription;
  final bool showActionButtons;
  final Map<String, dynamic>? orderData;
  final String courierName;
  final String courierPhone;

  const DeliveryCard({
    super.key,
    required this.orderId,
    required this.orderDocId,
    required this.status,
    required this.orderStatus,
    required this.statusColor,
    required this.statusTextColor,
    required this.customer,
    required this.product,
    required this.pickup,
    required this.dropoff,
    this.locationDescription = '',
    this.showActionButtons = false,
    this.orderData,
    this.courierName = 'Courier',
    this.courierPhone = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      orderId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              // Show badges on a second row if needed
              if (orderData?['deliverAgain'] == true ||
                  (orderData?['deliveryAttempts'] ?? 0) > 0) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Show "Deliver Again" badge if applicable
                    if (orderData?['deliverAgain'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 10,
                              color: Colors.orange[800],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Deliver Again',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Show attempt count if there are delivery attempts
                    if ((orderData?['deliveryAttempts'] ?? 0) > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Attempt ${orderData!['deliveryAttempts']}/3',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Customer: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: customer),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Product: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: product),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Pickup: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: pickup),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Drop-off: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: dropoff),
              ],
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
          if (locationDescription.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Location Info: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: locationDescription),
                ],
              ),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          // Action buttons for active deliveries
          if (showActionButtons) ...[
            const SizedBox(height: 12),
            // Show Start Delivery button only for picked_up status
            if (orderStatus == 'picked_up')
              ElevatedButton.icon(
                onPressed: () => _handleStartDelivery(
                  context,
                  orderDocId,
                  orderData,
                  courierName,
                  courierPhone,
                ),
                icon: const Icon(Icons.local_shipping, size: 18),
                label: const Text('Start Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976d2),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
            // Show delivery action buttons for in_delivery status
            if (orderStatus == 'in_delivery') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDeliveryAction(
                        context,
                        'cannot_reach',
                        orderDocId,
                        orderData,
                        courierName,
                        courierPhone,
                      ),
                      icon: const Icon(Icons.phone_disabled, size: 14),
                      label: const Text(
                        'Cannot Reach',
                        style: TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to messages screen with the customer
                        final customerId = orderData?['customerId'];
                        if (customerId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourierMessagesScreen(
                                preselectedUserId: customerId,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.message, size: 14),
                      label: const Text(
                        'Message',
                        style: TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDeliveryAction(
                        context,
                        'delivered',
                        orderDocId,
                        orderData,
                        courierName,
                        courierPhone,
                      ),
                      icon: const Icon(Icons.check_circle, size: 14),
                      label: const Text(
                        'Delivered',
                        style: TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartDelivery(
    BuildContext context,
    String orderDocId,
    Map<String, dynamic>? orderData,
    String courierName,
    String courierPhone,
  ) async {
    if (orderData == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Delivery'),
        content: const Text(
          'Are you ready to start delivering this order to the customer?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976d2),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Update order status to in_delivery
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderDocId)
          .update({
            'status': 'in_delivery',
            'startedDeliveryAt': FieldValue.serverTimestamp(),
          });

      final now = DateTime.now();
      final timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(now);

      // Notify customer
      final customerId = orderData['customerId'];
      if (customerId != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': customerId,
          'userType': 'customer',
          'type': 'delivery_started',
          'title': 'Delivery Started',
          'message':
              'Your order is now on the way! Courier: $courierName. Time: $timeStr',
          'orderId': orderDocId,
          'courierName': courierName,
          'courierPhone': courierPhone,
          'timestamp': timeStr,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Notify owners
      final ownerIds = orderData['ownerIds'] as List?;
      if (ownerIds != null) {
        for (final ownerId in ownerIds) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': ownerId,
            'userType': 'owner',
            'type': 'delivery_started',
            'title': 'Delivery Started',
            'message':
                'Courier $courierName started delivery for order #${orderDocId.substring(0, 8)}. Time: $timeStr',
            'orderId': orderDocId,
            'courierName': courierName,
            'timestamp': timeStr,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery started! Notifications sent.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeliveryAction(
    BuildContext context,
    String action,
    String orderDocId,
    Map<String, dynamic>? orderData,
    String courierName,
    String courierPhone,
  ) async {
    if (orderData == null) return;

    final now = DateTime.now();
    final timeStr = DateFormat('MMM dd, yyyy • hh:mm a').format(now);

    // Handle "cannot_reach" action with attempt tracking
    if (action == 'cannot_reach') {
      final currentAttempts = (orderData['deliveryAttempts'] ?? 0) as int;
      final newAttempts = currentAttempts + 1;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Reach Customer'),
          content: Text(
            newAttempts >= 3
                ? 'This is the 3rd attempt. The delivery will be marked as unsuccessful if you proceed.'
                : 'Mark this delivery attempt as "cannot be reached"? (Attempt $newAttempts of 3)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: newAttempts >= 3 ? Colors.red : Colors.orange,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        if (newAttempts >= 3) {
          // After 3 attempts, mark as unsuccessful
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderDocId)
              .update({
                'status': 'delivery_failed',
                'deliveryAttempts': newAttempts,
                'lastAttemptAt': FieldValue.serverTimestamp(),
                'failedAt': FieldValue.serverTimestamp(),
              });

          // Notify customer about unsuccessful delivery
          final customerId = orderData['customerId'];
          if (customerId != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': customerId,
              'userType': 'customer',
              'type': 'delivery_failed',
              'title': 'Delivery Unsuccessful',
              'message':
                  'Your order could not be delivered after 3 attempts. Please contact the shop. Courier: $courierName. Time: $timeStr',
              'orderId': orderDocId,
              'courierName': courierName,
              'courierPhone': courierPhone,
              'timestamp': timeStr,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // Notify owners about unsuccessful delivery
          final ownerIds = orderData['ownerIds'] as List?;
          if (ownerIds != null) {
            for (final ownerId in ownerIds) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': ownerId,
                'userType': 'owner',
                'type': 'delivery_failed',
                'title': 'Delivery Unsuccessful',
                'message':
                    'Order #${orderDocId.substring(0, 8)} could not be delivered after 3 attempts by $courierName. Time: $timeStr',
                'orderId': orderDocId,
                'courierName': courierName,
                'timestamp': timeStr,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Delivery marked as unsuccessful after 3 attempts. Notifications sent.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else {
          // Move order back to confirmed status for re-delivery
          await FirebaseFirestore.instance
              .collection('orders')
              .doc(orderDocId)
              .update({
                'status': 'confirmed',
                'deliveryAttempts': newAttempts,
                'lastAttemptAt': FieldValue.serverTimestamp(),
                'deliverAgain': true,
              });

          // Notify customer about re-delivery attempt
          final customerId = orderData['customerId'];
          if (customerId != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': customerId,
              'userType': 'customer',
              'type': 'delivery_reattempt',
              'title': 'Delivery Re-attempt Scheduled',
              'message':
                  'The courier could not reach you. We will attempt to deliver again. Attempt $newAttempts of 3. Time: $timeStr',
              'orderId': orderDocId,
              'courierName': courierName,
              'courierPhone': courierPhone,
              'timestamp': timeStr,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          // Notify owners about re-delivery
          final ownerIds = orderData['ownerIds'] as List?;
          if (ownerIds != null) {
            for (final ownerId in ownerIds) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': ownerId,
                'userType': 'owner',
                'type': 'delivery_reattempt',
                'title': 'Delivery Will Be Re-attempted',
                'message':
                    'Courier $courierName could not reach customer for order #${orderDocId.substring(0, 8)}. Order moved back to confirmed. Attempt $newAttempts of 3. Time: $timeStr',
                'orderId': orderDocId,
                'courierName': courierName,
                'timestamp': timeStr,
                'read': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Order moved back to confirmed for re-delivery. Attempt $newAttempts of 3. Notifications sent.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Handle "delivered" action
    if (action == 'delivered') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Delivery'),
          content: const Text('Mark this order as delivered?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      try {
        // Update order status to delivered
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderDocId)
            .update({
              'status': 'delivered',
              'deliveredAt': FieldValue.serverTimestamp(),
            });

        // Notify customer
        final customerId = orderData['customerId'];
        if (customerId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': customerId,
            'userType': 'customer',
            'type': 'order_delivered',
            'title': 'Order Delivered',
            'message':
                'Your order has been successfully delivered. Time: $timeStr. Courier: $courierName',
            'orderId': orderDocId,
            'courierName': courierName,
            'courierPhone': courierPhone,
            'timestamp': timeStr,
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Notify owners
        final ownerIds = orderData['ownerIds'] as List?;
        if (ownerIds != null) {
          for (final ownerId in ownerIds) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'userId': ownerId,
              'userType': 'owner',
              'type': 'order_delivered',
              'title': 'Order Delivered',
              'message':
                  'Your order has been successfully delivered. Time: $timeStr. Courier: $courierName',
              'orderId': orderDocId,
              'courierName': courierName,
              'timestamp': timeStr,
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order marked as delivered. Notifications sent.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update order: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// `MobileButton` moved to `lib/widgets/mobile_button.dart` for reuse.
