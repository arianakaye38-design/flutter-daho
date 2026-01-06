import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' show cos, sqrt, asin;

class OwnerOrdersScreen extends StatefulWidget {
  const OwnerOrdersScreen({super.key});

  @override
  State<OwnerOrdersScreen> createState() => _OwnerOrdersScreenState();
}

class _OwnerOrdersScreenState extends State<OwnerOrdersScreen> {
  // Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2));

    final c = 2 * asin(sqrt(a));

    return earthRadius * c; // Distance in kilometers
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  double sin(double value) => value - (value * value * value) / 6;

  double pi = 3.14159265359;
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.deepOrange;
      case 'cancelled':
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Filter items to show only owner's products
    final allItems = order['items'] as List? ?? [];
    final ownerItems = allItems
        .where((item) => item['ownerId'] == user.uid)
        .toList();

    // Calculate total for owner's items only
    double ownerTotal = ownerItems.fold(
      0.0,
      (total, item) => total + ((item['price'] ?? 0) * (item['quantity'] ?? 0)),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Order #${order['orderId']?.substring(0, 8) ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Customer:', order['customerName'] ?? 'N/A'),
              _buildInfoRow('Location:', order['customerAddress'] ?? 'N/A'),
              _buildInfoRow(
                'Date:',
                order['createdAt'] != null
                    ? (order['createdAt'] as Timestamp)
                          .toDate()
                          .toString()
                          .substring(0, 16)
                    : 'N/A',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                'Status:',
                order['status']?.toString().toUpperCase() ?? 'N/A',
                isBold: true,
              ),
              if (order['status'] == 'rejected') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Courier Rejected Pickup',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Courier: ${order['rejectedByCourierName'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        'Contact: ${order['rejectedByCourierPhone'] ?? 'Not available'}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Looking for another courier to pickup...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Your Items:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (ownerItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    'No items from your shop in this order',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...List.generate(ownerItems.length, (index) {
                  final item = ownerItems[index];
                  return Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Text(
                      '${item['name']} x${item['quantity']} - ₱${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                    ),
                  );
                }),
              const Divider(),
              _buildInfoRow(
                'Your Total:',
                '₱${ownerTotal.toStringAsFixed(2)}',
                isBold: true,
              ),
            ],
          ),
        ),
        actions: [
          if (order['status'] == 'rejected')
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  // Get list of all previously rejected courier IDs to exclude
                  final rejectedCourierIds = List<String>.from(
                    order['rejectedCourierIds'] ?? [],
                  );

                  // Get shop location from pasalubong_centers
                  final centerId = order['centerId'];
                  GeoPoint? shopLocation;

                  if (centerId != null) {
                    final centerDoc = await FirebaseFirestore.instance
                        .collection('pasalubong_centers')
                        .doc(centerId)
                        .get();

                    if (centerDoc.exists) {
                      shopLocation = centerDoc.data()?['location'] as GeoPoint?;
                    }
                  }

                  // Find all available online couriers
                  final couriersQuery = await FirebaseFirestore.instance
                      .collection('couriers')
                      .where('isOnline', isEqualTo: true)
                      .where('isAvailable', isEqualTo: true)
                      .get();

                  String? assignedCourierId;
                  String? assignedCourierName;
                  String? assignedCourierEmail;
                  double? nearestDistance;

                  if (couriersQuery.docs.isNotEmpty && shopLocation != null) {
                    // Find nearest courier, excluding all who previously rejected
                    for (final courierDoc in couriersQuery.docs) {
                      // Skip couriers who previously rejected
                      if (rejectedCourierIds.contains(courierDoc.id)) continue;

                      final courierData = courierDoc.data();
                      final courierLocation =
                          courierData['currentLocation'] as GeoPoint?;

                      if (courierLocation != null) {
                        final distance = _calculateDistance(
                          shopLocation.latitude,
                          shopLocation.longitude,
                          courierLocation.latitude,
                          courierLocation.longitude,
                        );

                        if (nearestDistance == null ||
                            distance < nearestDistance) {
                          nearestDistance = distance;
                          assignedCourierId = courierDoc.id;

                          // Get courier name from users collection
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(assignedCourierId)
                              .get();

                          if (userDoc.exists) {
                            assignedCourierName =
                                userDoc.data()?['name'] ?? 'Courier';
                            assignedCourierEmail = userDoc.data()?['email'];
                          }
                        }
                      }
                    }
                  } else if (couriersQuery.docs.isNotEmpty) {
                    // Fallback: if no shop location, use first available courier (excluding rejected ones)
                    for (final courierDoc in couriersQuery.docs) {
                      if (rejectedCourierIds.contains(courierDoc.id)) continue;

                      assignedCourierId = courierDoc.id;

                      final userDoc = await FirebaseFirestore.instance
                          .collection('users')
                          .doc(assignedCourierId)
                          .get();

                      if (userDoc.exists) {
                        assignedCourierName =
                            userDoc.data()?['name'] ?? 'Courier';
                        assignedCourierEmail = userDoc.data()?['email'];
                      }
                      break; // Take first available courier that hasn't rejected
                    }
                  }

                  final updateData = <String, dynamic>{
                    'status': 'confirmed',
                    'rejectedAt': FieldValue.delete(),
                    'rejectedBy': FieldValue.delete(),
                    'rejectedByCourierName': FieldValue.delete(),
                    'rejectedByCourierPhone': FieldValue.delete(),
                    'rejectedByCourierEmail': FieldValue.delete(),
                    // Keep rejectedCourierIds list to exclude them next time if needed
                  };

                  if (assignedCourierId != null) {
                    updateData['courierId'] = assignedCourierId;
                    updateData['courierName'] = assignedCourierName;
                    updateData['courierEmail'] = assignedCourierEmail;
                    updateData['assignedAt'] = FieldValue.serverTimestamp();
                  }

                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order['_docId'] ?? order['orderId'])
                      .update(updateData);

                  // Send notification to assigned courier if any
                  if (assignedCourierId != null) {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add({
                          'userId': assignedCourierId,
                          'userType': 'courier',
                          'type': 'order_assigned',
                          'title': 'New Order Assigned',
                          'message':
                              'You have been assigned order #${order['orderId']?.substring(0, 8)}',
                          'orderId': order['orderId'],
                          'read': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        assignedCourierId != null
                            ? 'Order re-assigned to nearest available courier: $assignedCourierName${nearestDistance != null ? ' (${nearestDistance.toStringAsFixed(1)} km away)' : ''}'
                            : 'No other courier available. All nearby couriers have rejected this order.',
                      ),
                      backgroundColor: assignedCourierId != null
                          ? Colors.blue
                          : Colors.orange,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to re-confirm: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Find Another Courier'),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          if (order['status'] == 'pending') ...[
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order['_docId'] ?? order['orderId'])
                      .update({'status': 'declined'});
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Order #${order['orderId']?.substring(0, 8)} declined',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to decline: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Decline'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  // Get shop location from pasalubong_centers
                  final centerId = order['centerId'];
                  GeoPoint? shopLocation;

                  if (centerId != null) {
                    final centerDoc = await FirebaseFirestore.instance
                        .collection('pasalubong_centers')
                        .doc(centerId)
                        .get();

                    if (centerDoc.exists) {
                      shopLocation = centerDoc.data()?['location'] as GeoPoint?;
                    }
                  }

                  // Find all available online couriers
                  final couriersQuery = await FirebaseFirestore.instance
                      .collection('couriers')
                      .where('isOnline', isEqualTo: true)
                      .where('isAvailable', isEqualTo: true)
                      .get();

                  String? assignedCourierId;
                  String? assignedCourierName;
                  String? assignedCourierEmail;
                  double? nearestDistance;

                  if (couriersQuery.docs.isNotEmpty && shopLocation != null) {
                    // Find nearest courier based on distance
                    for (final courierDoc in couriersQuery.docs) {
                      final courierData = courierDoc.data();
                      final courierLocation =
                          courierData['currentLocation'] as GeoPoint?;

                      if (courierLocation != null) {
                        final distance = _calculateDistance(
                          shopLocation.latitude,
                          shopLocation.longitude,
                          courierLocation.latitude,
                          courierLocation.longitude,
                        );

                        if (nearestDistance == null ||
                            distance < nearestDistance) {
                          nearestDistance = distance;
                          assignedCourierId = courierDoc.id;

                          // Get courier name from users collection
                          final userDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(assignedCourierId)
                              .get();

                          if (userDoc.exists) {
                            assignedCourierName =
                                userDoc.data()?['name'] ?? 'Courier';
                            assignedCourierEmail = userDoc.data()?['email'];
                          }
                        }
                      }
                    }
                  } else if (couriersQuery.docs.isNotEmpty) {
                    // Fallback: if no shop location, use first available courier
                    final courierDoc = couriersQuery.docs.first;
                    assignedCourierId = courierDoc.id;

                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(assignedCourierId)
                        .get();

                    if (userDoc.exists) {
                      assignedCourierName =
                          userDoc.data()?['name'] ?? 'Courier';
                      assignedCourierEmail = userDoc.data()?['email'];
                    }
                  }

                  final updateData = <String, dynamic>{'status': 'confirmed'};

                  if (assignedCourierId != null) {
                    updateData['courierId'] = assignedCourierId;
                    updateData['courierName'] = assignedCourierName;
                    updateData['courierEmail'] = assignedCourierEmail;
                    updateData['assignedAt'] = FieldValue.serverTimestamp();
                  }

                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order['_docId'] ?? order['orderId'])
                      .update(updateData);

                  // Send notification to assigned courier if any
                  if (assignedCourierId != null) {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .add({
                          'userId': assignedCourierId,
                          'userType': 'courier',
                          'type': 'order_assigned',
                          'title': 'New Order Assigned',
                          'message':
                              'You have been assigned order #${order['orderId']?.substring(0, 8)}',
                          'orderId': order['orderId'],
                          'read': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                  }

                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        assignedCourierId != null
                            ? 'Order accepted and assigned to nearest courier: $assignedCourierName${nearestDistance != null ? ' (${nearestDistance.toStringAsFixed(1)} km away)' : ''}'
                            : 'Order accepted. No courier available yet.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint('Failed to accept order: $e');
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to accept: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Accept'),
            ),
          ],
          if (order['status'] == 'confirmed')
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(order['_docId'] ?? order['orderId'])
                      .update({'status': 'completed'});
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Order #${order['orderId']?.substring(0, 8)} completed',
                      ),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to complete: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Complete Order'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: user == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('ownerIds', arrayContains: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No orders yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Orders containing your products will appear here',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final orderDoc = orders[index];
                    final order = orderDoc.data() as Map<String, dynamic>;
                    // Add the document ID to the order map for easy reference
                    order['_docId'] = orderDoc.id;
                    final allItems = order['items'] as List? ?? [];
                    final status = order['status'] ?? 'pending';

                    // Filter items to show only owner's products
                    final ownerItems = allItems
                        .where((item) => item['ownerId'] == user.uid)
                        .toList();

                    // Calculate total for owner's items only
                    double ownerTotal = ownerItems.fold(
                      0.0,
                      (total, item) =>
                          total +
                          ((item['price'] ?? 0) * (item['quantity'] ?? 0)),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(status),
                          child: Text(
                            '#${order['orderId']?.substring(0, 3) ?? 'N/A'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          order['customerName'] ?? 'Customer',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ownerItems.length} item(s) from your shop'),
                            Text(
                              '₱${ownerTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF1976d2),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  status,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => _showOrderDetails(order),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
