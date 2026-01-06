import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  State<OwnerNotificationsScreen> createState() =>
      _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
      }
    }
  }

  Future<void> _showNotificationDetails(String? orderId) async {
    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No order details available')),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch order details
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (!orderDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Order not found')));
        return;
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      final totalAmount = orderData['totalAmount'] ?? 0;
      final status = orderData['status'] ?? 'Unknown';
      final courierId = orderData['courierId'];

      debugPrint('Order Data - courierId: $courierId, status: $status');

      // Get customer info directly from order (stored when order was placed)
      final customerName = orderData['customerName'] ?? 'N/A';
      final customerPhone = orderData['customerPhone'] ?? 'N/A';
      final customerAddress = orderData['customerAddress'] ?? 'Not provided';
      final customerLocation = orderData['customerLocation'] as GeoPoint?;

      debugPrint(
        'Customer Info - Name: $customerName, Phone: $customerPhone, Address: $customerAddress',
      );

      // Fetch courier details - check order first for stored courier info, then users collection
      String courierName = 'Not yet assigned';
      String courierPhone = 'Not available';

      // First, check if courier info is stored directly in the order
      if (orderData['courierName'] != null &&
          orderData['courierName'].toString().isNotEmpty) {
        courierName = orderData['courierName'];
        debugPrint('Using courierName from order: $courierName');
      }

      if (courierId != null && courierId.isNotEmpty) {
        debugPrint('Fetching courier details for ID: $courierId');
        try {
          final courierDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(courierId)
              .get();

          debugPrint('Courier doc exists: ${courierDoc.exists}');

          if (courierDoc.exists) {
            final courierData = courierDoc.data() as Map<String, dynamic>;
            debugPrint('Courier data: $courierData');

            // Update courierName if we got it from users collection
            if (courierData.containsKey('name') &&
                courierData['name'] != null) {
              courierName = courierData['name'].toString();
            }
            if (courierData.containsKey('phone') &&
                courierData['phone'] != null) {
              courierPhone = courierData['phone'].toString();
            }
            debugPrint('Courier Name: $courierName, Phone: $courierPhone');
          } else {
            debugPrint('Courier document does not exist for ID: $courierId');
          }
        } catch (e) {
          debugPrint('Error fetching courier details: $e');
        }
      } else {
        debugPrint('No courier assigned yet - courierId is null or empty');
      }

      // Show order details dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Order Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Customer Information
                const Text(
                  'Customer Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Name: $customerName'),
                const SizedBox(height: 4),
                Text('Phone: $customerPhone'),
                const SizedBox(height: 4),
                Text('Address: $customerAddress'),
                if (customerLocation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Coordinates: ${customerLocation.latitude.toStringAsFixed(6)}, ${customerLocation.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const Divider(height: 24),

                // Courier Information
                const Text(
                  'Courier Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Name: $courierName'),
                const SizedBox(height: 4),
                Text('Contact Number: $courierPhone'),
                const Divider(height: 24),

                // Order Status
                const Text(
                  'Order Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Status: ${status.toUpperCase()}'),
                const Divider(height: 24),

                // Order Items
                const Text(
                  'Order Items',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...items.map((item) {
                  final name = item['name'] ?? 'Unknown';
                  final quantity = item['quantity'] ?? 0;
                  final price = item['price'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $name x$quantity - ₱${price.toStringAsFixed(2)}',
                    ),
                  );
                }),
                const Divider(height: 24),

                // Total Amount
                const Text(
                  'Amount to be Paid',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '₱${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog if still open
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading order details: $e')),
      );
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'courier_accepted':
        return Icons.local_shipping;
      case 'order_placed':
        return Icons.shopping_cart;
      case 'order_completed':
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'courier_accepted':
        return Colors.blue;
      case 'order_placed':
        return Colors.orange;
      case 'order_completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: const Color(0xFF1976d2),
        ),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF1976d2),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .where('userType', isEqualTo: 'owner')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final notification = doc.data() as Map<String, dynamic>;
              final notificationId = doc.id;
              final isRead = notification['read'] ?? false;
              final type = notification['type'] ?? 'general';
              final title = notification['title'] ?? 'Notification';
              final message = notification['message'] ?? '';
              final timestamp = notification['createdAt'] as Timestamp?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isRead ? 1 : 3,
                color: isRead ? null : Colors.blue.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(type),
                    child: Icon(
                      _getNotificationIcon(type),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(message),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!isRead) {
                      _markAsRead(notificationId);
                    }
                    // Show notification details
                    final orderId = notification['orderId'] as String?;
                    _showNotificationDetails(orderId);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
