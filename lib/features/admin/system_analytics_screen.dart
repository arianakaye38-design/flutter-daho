import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemAnalyticsScreen extends StatefulWidget {
  const SystemAnalyticsScreen({super.key});

  @override
  State<SystemAnalyticsScreen> createState() => _SystemAnalyticsScreenState();
}

class _SystemAnalyticsScreenState extends State<SystemAnalyticsScreen> {
  Map<String, int> userTypeDistribution = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Load ALL users from Firestore
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final Map<String, int> typeDistribution = {
        'Customers': 0,
        'Owners': 0,
        'Couriers': 0,
        'Admins': 0,
      };

      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        final userType = data['type'] as String?;

        // Count all user types
        if (userType == 'customer') {
          typeDistribution['Customers'] = typeDistribution['Customers']! + 1;
        } else if (userType == 'owner') {
          typeDistribution['Owners'] = typeDistribution['Owners']! + 1;
        } else if (userType == 'courier') {
          typeDistribution['Couriers'] = typeDistribution['Couriers']! + 1;
        } else if (userType == 'admin') {
          typeDistribution['Admins'] = typeDistribution['Admins']! + 1;
        }
      }

      debugPrint('📊 Loaded user distribution: $typeDistribution');
      debugPrint('📊 Total users found: ${allUsersSnapshot.docs.length}');

      if (!mounted) return;

      setState(() {
        userTypeDistribution = typeDistribution;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxValue = userTypeDistribution.values.isEmpty
        ? 1
        : userTypeDistribution.values.reduce((a, b) => a > b ? a : b);

    final colors = {
      'Customers': const Color(0xFF4CAF50),
      'Owners': const Color(0xFF2196F3),
      'Couriers': const Color(0xFFFF9800),
      'Admins': const Color(0xFF9C27B0),
    };

    final total = userTypeDistribution.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Analytics'),
        backgroundColor: const Color(0xFF1976d2),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All Users in the App',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (userTypeDistribution.isEmpty || total == 0)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No users found in database',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 400,
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: userTypeDistribution.entries.map((entry) {
                        final barHeight = maxValue > 0
                            ? (entry.value / maxValue) * 280
                            : 20.0;
                        return Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${entry.value}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: 50,
                                  height: barHeight.clamp(20, 280),
                                  decoration: BoxDecoration(
                                    color: colors[entry.key] ?? Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (!isLoading && total > 0)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Users: $total',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ...userTypeDistribution.entries.map((entry) {
                          final percentage = total > 0
                              ? (entry.value / total * 100).toStringAsFixed(1)
                              : '0.0';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: colors[entry.key],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.key}: ${entry.value} ($percentage%)',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
