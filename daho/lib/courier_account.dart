// Suppress info about using BuildContext across async gaps here. The
// courier dashboard uses synchronous navigation/showDialog calls; if we add
// async work later we'll add proper mounted checks instead of silencing.
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CourierDashboard extends StatelessWidget {
  const CourierDashboard({super.key});

  void _log(String msg) {
    // Replace this with your logging or action method
    debugPrint(msg);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Flex(
          direction: isDesktop ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Panel
            Flexible(
              flex: 1,
              child: Container(
                margin: isDesktop ? const EdgeInsets.only(right: 16) : null,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      // ignore: deprecated_member_use
                      FontAwesomeIcons.userCircle,
                      size: isDesktop ? 90 : 70,
                      color: const Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Local Courier',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: const [
                        InfoRow(
                          // ignore: deprecated_member_use
                          icon: FontAwesomeIcons.phoneAlt,
                          iconColor: Colors.green,
                          text: '+63 9XX XXX XXX',
                        ),
                        InfoRow(
                          icon: FontAwesomeIcons.envelope,
                          iconColor: Colors.green,
                          text: 'alex.carter@courier.ph',
                        ),
                      ],
                    ),
                    if (isDesktop) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () =>
                                debugPrint("Notifications clicked!"),
                            icon: const FaIcon(
                              FontAwesomeIcons.bell,
                              size: 22,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              // Replace with your navigation logic
                              debugPrint(
                                'Navigate to user-settings from courier-dashboard',
                              );
                            },
                            icon: const FaIcon(
                              FontAwesomeIcons.gear,
                              size: 22,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          IconButton(
                            onPressed: () => debugPrint("History clicked!"),
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
            ),

            // Right Panel
            Flexible(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          // Card: Delivery Tasks/Active Orders
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Header with title and menu icon
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Delivery Tasks / Active Orders',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const FaIcon(
                                        FontAwesomeIcons.ellipsisVertical,
                                        size: 18,
                                        color: Color(0xFF6B7280),
                                      ),
                                      onPressed: () => _log('Menu clicked!'),
                                    ),
                                  ],
                                ),

                                // Delivery Card 1
                                DeliveryCard(
                                  orderId: '#ORD-005',
                                  status: 'Pending',
                                  statusColor: const Color(0xFFFDE68A),
                                  statusTextColor: const Color(0xFF92400E),
                                  customer: 'Jane Doe',
                                  product: 'Pasalubong Basket',
                                  pickup: '123 Maple St (Quezon City)',
                                  dropoff: '139 Pine Ln (Quezon City)',
                                ),

                                // Delivery Card 2
                                DeliveryCard(
                                  orderId: '#ORD-004',
                                  status: 'Picked Up',
                                  statusColor: const Color(0xFFA7F3D0),
                                  statusTextColor: const Color(0xFF065F46),
                                  customer: 'Mark T.',
                                  product: 'Gourmet Coffee',
                                  pickup: 'Cafe St (Manila)',
                                  dropoff: '19 Tagaytay Rd (Tagaytay)',
                                ),
                              ],
                            ),
                          ),

                          if (!isDesktop)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  MobileButton(
                                    icon: FontAwesomeIcons.bell,
                                    label: 'Alerts',
                                    onPressed: () =>
                                        _log('Notifications clicked!'),
                                  ),
                                  MobileButton(
                                    // ignore: deprecated_member_use
                                    icon: FontAwesomeIcons.cog,
                                    label: 'Settings',
                                    onPressed: () {
                                      // Replace with your navigation logic
                                      _log(
                                        'Navigate to user-settings from courier-dashboard',
                                      );
                                    },
                                  ),
                                  MobileButton(
                                    // ignore: deprecated_member_use
                                    icon: FontAwesomeIcons.history,
                                    label: 'History',
                                    onPressed: () => _log('History clicked!'),
                                  ),
                                ],
                              ),
                            ),

                          // Map Card
                          Container(
                            height: isDesktop ? 300 : 400,
                            width: isDesktop
                                ? double.infinity
                                : double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Map & Route Navigation (GIS)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      'Map Placeholder. GIS content here.',
                                      style: TextStyle(
                                        color: Color(0xFF6B7280),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
    );
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
  final String status;
  final Color statusColor;
  final Color statusTextColor;
  final String customer;
  final String product;
  final String pickup;
  final String dropoff;

  const DeliveryCard({
    super.key,
    required this.orderId,
    required this.status,
    required this.statusColor,
    required this.statusTextColor,
    required this.customer,
    required this.product,
    required this.pickup,
    required this.dropoff,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                orderId,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
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
        ],
      ),
    );
  }
}

class MobileButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const MobileButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          FaIcon(icon, size: 22, color: const Color(0xFF1F2937)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }
}
