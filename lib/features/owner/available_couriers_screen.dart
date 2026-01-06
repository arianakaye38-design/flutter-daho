import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'messages_screen.dart';

class AvailableCouriersScreen extends StatefulWidget {
  const AvailableCouriersScreen({super.key});

  @override
  State<AvailableCouriersScreen> createState() =>
      _AvailableCouriersScreenState();
}

class _AvailableCouriersScreenState extends State<AvailableCouriersScreen> {
  bool _isDetailedView = true; // true = detailed, false = list

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Couriers'),
        backgroundColor: const Color(0xFF1976d2),
        actions: [
          IconButton(
            icon: Icon(_isDetailedView ? Icons.view_list : Icons.view_module),
            tooltip: _isDetailedView
                ? 'Switch to List View'
                : 'Switch to Detailed View',
            onPressed: () {
              setState(() {
                _isDetailedView = !_isDetailedView;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('couriers')
            .orderBy('isOnline', descending: true)
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
                    Icons.delivery_dining,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No couriers found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No courier accounts have been created yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final couriers = snapshot.data!.docs;

          return _isDetailedView
              ? _buildDetailedView(couriers)
              : _buildListView(couriers);
        },
      ),
    );
  }

  Widget _buildDetailedView(List<QueryDocumentSnapshot> couriers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: couriers.length,
      itemBuilder: (context, index) {
        final courier = couriers[index].data() as Map<String, dynamic>;
        final courierId = couriers[index].id;
        final isOnline = courier['isOnline'] ?? false;
        final lastActive = courier['lastActive'] as Timestamp?;

        return FutureBuilder<List<String>>(
          future: Future.wait([
            _getCourierName(courierId, courier),
            _getCourierPhone(courierId, courier),
            _getCourierLocation(courierId, courier),
            _getCourierEmail(courierId, courier),
          ]),
          builder: (context, snapshot) {
            final name = snapshot.data?[0] ?? 'Loading...';
            final phone = snapshot.data?[1] ?? 'N/A';
            final locationText = snapshot.data?[2] ?? 'Location not available';
            final email = snapshot.data?[3] ?? 'No email';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: isOnline
                              ? const Color(0xFF1976d2)
                              : Colors.grey[400],
                          child: Icon(
                            Icons.delivery_dining,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isOnline
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: isOnline
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          isOnline ? 'ONLINE' : 'OFFLINE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: isOnline
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: ${courierId.substring(0, 8)}...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(phone, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationText,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.email, size: 18, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (lastActive != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last active: ${_formatTime(lastActive.toDate())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            _showAssignOrderDialog(
                              context,
                              courierId,
                              name,
                              email,
                            );
                          },
                          icon: const Icon(Icons.local_shipping, size: 16),
                          label: const Text('Assign Order'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _openMessages(context, courierId);
                          },
                          icon: const Icon(Icons.message, size: 16),
                          label: const Text('Message'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976d2),
                            side: const BorderSide(color: Color(0xFF1976d2)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String> _getCourierName(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    // First check if name exists in courier document
    if (courierData['name'] != null &&
        courierData['name'].toString().isNotEmpty) {
      return courierData['name'];
    }

    // Try to fetch from users collection using courier ID
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(courierId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();

        // Try to build full name from firstName and lastName
        if (userData != null) {
          final firstName = userData['firstName']?.toString() ?? '';
          final lastName = userData['lastName']?.toString() ?? '';

          if (firstName.isNotEmpty && lastName.isNotEmpty) {
            return '$firstName $lastName';
          } else if (firstName.isNotEmpty) {
            return firstName;
          } else if (lastName.isNotEmpty) {
            return lastName;
          }

          // Fallback to 'name' field if firstName/lastName not available
          if (userData['name'] != null &&
              userData['name'].toString().isNotEmpty) {
            return userData['name'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching courier name: $e');
    }

    // Fallback to email username
    return courierData['email']?.split('@')[0] ?? 'Courier';
  }

  Future<String> _getCourierPhone(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    // First check if phone exists in courier document
    if (courierData['phone'] != null &&
        courierData['phone'].toString().isNotEmpty) {
      return courierData['phone'];
    }
    if (courierData['mobile'] != null &&
        courierData['mobile'].toString().isNotEmpty) {
      return courierData['mobile'];
    }

    // Try to fetch from users collection using courier ID
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(courierId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData['phone'] != null &&
            userData['phone'].toString().isNotEmpty) {
          return userData['phone'];
        }
        if (userData != null &&
            userData['mobile'] != null &&
            userData['mobile'].toString().isNotEmpty) {
          return userData['mobile'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching courier phone: $e');
    }

    // Fallback
    return 'N/A';
  }

  Future<String> _getCourierLocation(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    // First check if address exists in courier document
    if (courierData['address'] != null &&
        courierData['address'].toString().isNotEmpty) {
      return courierData['address'];
    }

    // Try to fetch from users collection using courier ID
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(courierId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData['location'] != null &&
            userData['location'].toString().isNotEmpty) {
          return userData['location'];
        }
        if (userData != null &&
            userData['address'] != null &&
            userData['address'].toString().isNotEmpty) {
          return userData['address'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching courier location: $e');
    }

    // Check if currentLocation (GeoPoint) exists
    if (courierData['currentLocation'] != null &&
        courierData['currentLocation'] is GeoPoint) {
      final GeoPoint location = courierData['currentLocation'];
      return 'Lat: ${location.latitude.toStringAsFixed(4)}, Lng: ${location.longitude.toStringAsFixed(4)}';
    }

    return 'Location not available';
  }

  Future<String> _getCourierEmail(
    String courierId,
    Map<String, dynamic> courierData,
  ) async {
    // First check if email exists in courier document
    if (courierData['email'] != null &&
        courierData['email'].toString().isNotEmpty) {
      return courierData['email'];
    }

    // Try to fetch from users collection using courier ID
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(courierId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null &&
            userData['email'] != null &&
            userData['email'].toString().isNotEmpty) {
          return userData['email'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching courier email: $e');
    }

    return 'No email';
  }

  Widget _buildListView(List<QueryDocumentSnapshot> couriers) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: couriers.length,
      itemBuilder: (context, index) {
        final courier = couriers[index].data() as Map<String, dynamic>;
        final courierId = couriers[index].id;
        final isOnline = courier['isOnline'] ?? false;

        return FutureBuilder<List<String>>(
          future: Future.wait([
            _getCourierName(courierId, courier),
            _getCourierPhone(courierId, courier),
            _getCourierLocation(courierId, courier),
            _getCourierEmail(courierId, courier),
          ]),
          builder: (context, snapshot) {
            final name = snapshot.data?[0] ?? 'Loading...';
            final phone = snapshot.data?[1] ?? 'N/A';
            final locationText = snapshot.data?[2] ?? 'Location N/A';
            final email = snapshot.data?[3] ?? 'No email';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isOnline
                      ? const Color(0xFF1976d2)
                      : Colors.grey[400],
                  child: Icon(
                    Icons.delivery_dining,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.circle,
                      size: 10,
                      color: isOnline ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.email, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 14),
                        const SizedBox(width: 4),
                        Text(phone, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            locationText,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.local_shipping,
                        color: Colors.blue,
                      ),
                      tooltip: 'Assign Order',
                      onPressed: () {
                        _showAssignOrderDialog(context, courierId, name, email);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Color(0xFF1976d2)),
                      tooltip: 'Message',
                      onPressed: () {
                        _openMessages(context, courierId);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  _openMessages(context, courierId);
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
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

  void _openMessages(BuildContext context, String courierId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerMessagesScreen(preselectedCourierId: courierId),
      ),
    );
  }

  void _showAssignOrderDialog(
    BuildContext context,
    String courierId,
    String courierName,
    String courierEmail,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Order to Courier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a rejected order to assign to:',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          courierName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          courierEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rejected Orders:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('status', isEqualTo: 'rejected')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'No rejected orders available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                final orders = snapshot.data!.docs;

                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order =
                          orders[index].data() as Map<String, dynamic>;
                      final orderId = order['orderId'] ?? orders[index].id;
                      final customerName = order['customerName'] ?? 'N/A';
                      final rejectedCourierIds = List<String>.from(
                        order['rejectedCourierIds'] ?? [],
                      );

                      // Check if this courier already rejected this order
                      final alreadyRejected = rejectedCourierIds.contains(
                        courierId,
                      );

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: alreadyRejected
                                ? Colors.orange
                                : Colors.red,
                            child: const Icon(
                              Icons.warning,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Order #${orderId.toString().substring(0, 8)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: $customerName',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (alreadyRejected)
                                Text(
                                  '⚠️ Previously rejected by this courier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          trailing: ElevatedButton(
                            onPressed: alreadyRejected
                                ? null
                                : () async {
                                    await _assignOrderToCourier(
                                      ctx,
                                      orderId,
                                      courierId,
                                      courierName,
                                      courierEmail,
                                      rejectedCourierIds,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: alreadyRejected
                                  ? Colors.grey
                                  : Colors.blue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'Assign',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignOrderToCourier(
    BuildContext context,
    String orderId,
    String courierId,
    String courierName,
    String courierEmail,
    List<String> rejectedCourierIds,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Check if courier already rejected this order
      if (rejectedCourierIds.contains(courierId)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This courier previously rejected this order. Please choose another courier.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final updateData = <String, dynamic>{
        'status': 'confirmed',
        'courierId': courierId,
        'courierName': courierName,
        'courierEmail': courierEmail,
        'assignedAt': FieldValue.serverTimestamp(),
        'rejectedAt': FieldValue.delete(),
        'rejectedBy': FieldValue.delete(),
        'rejectedByCourierName': FieldValue.delete(),
        'rejectedByCourierPhone': FieldValue.delete(),
        'rejectedByCourierEmail': FieldValue.delete(),
      };

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(updateData);

      // Send notification to assigned courier
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': courierId,
        'userType': 'courier',
        'type': 'order_assigned',
        'title': 'New Order Assigned',
        'message':
            'You have been manually assigned order #${orderId.substring(0, 8)}',
        'orderId': orderId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Order assigned to $courierName successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to assign order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
