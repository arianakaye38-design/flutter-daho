import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'log_in.dart';
import 'models/product.dart';
import 'services/order_service.dart';
import 'owner_account.dart' show productData;

class CustomerAccount extends StatefulWidget {
  const CustomerAccount({super.key});

  @override
  State<CustomerAccount> createState() => _CustomerAccountState();

  // Center around Alibhon, Guimaras (approximate)
  static final LatLng alibhonCenter = LatLng(10.6036, 122.5927);

  // Landmarks with precise coordinates for the two Pasalubong Centers
  static final List<Map<String, dynamic>> landmarks = [
    {
      'name': 'JMM Bakeshop',
      'type': 'pasalubong',
      // Exact coordinate requested by user
      'position': LatLng(10.59806876046459, 122.59228907843912),
    },
    {
      'name': "Boboy's Delicacies",
      'type': 'pasalubong',
      // Exact coordinate requested by user
      'position': LatLng(10.60749434917473, 122.59313057862323),
    },
    {
      'name': 'Alibhon School',
      'type': 'school',
      'position': LatLng(10.5995, 122.5918),
    },
    {
      'name': 'Alibhon Church',
      'type': 'church',
      'position': LatLng(10.6050, 122.5940),
    },
    {
      'name': 'Guimaras Municipal Office',
      'type': 'government',
      'position': LatLng(10.6045, 122.5940),
    },
  ];
}

class _CustomerAccountState extends State<CustomerAccount> {
  final OrderService _orderService = OrderService.instance;
  late final List<Product> _sampleProducts;
  Marker? _courierMarker;

  @override
  void initState() {
    super.initState();
    _sampleProducts = [
      Product(
        id: 'p1',
        name: 'Banana Chips',
        description: 'Crispy banana chips',
        price: 80.0,
      ),
      Product(
        id: 'p2',
        name: 'Dried Mangoes',
        description: 'Sweet dried mangoes',
        price: 120.0,
      ),
    ];
  }

  void _startCourierSimulation(LatLng from, LatLng to) {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final stream = _orderService.simulateCourier(orderId, from, to);
    stream.listen((pos) {
      if (!mounted) return;
      setState(() {
        _courierMarker = Marker(
          width: 48,
          height: 48,
          point: pos,
          // Newer flutter_map versions use `child` instead of `builder`.
          child: const Icon(
            Icons.delivery_dining,
            color: Colors.blue,
            size: 32,
          ),
        );
      });
    });
  }

  void _onMarkerTap(Map<String, dynamic> lm) {
    // Decide which product source to show: owner's productData for pasalubong
    final String type = (lm['type'] as String);
    final bool isPasalubong = type == 'pasalubong';
    final bool isSchoolOrChurch = type == 'school' || type == 'church';
    showModalBottomSheet(
      context: context,
      builder: (_) => SizedBox(
        height: 300,
        child: Column(
          children: [
            ListTile(
              title: Text(lm['name'] as String),
              subtitle: Text(isPasalubong ? 'Pasalubong Center' : 'Place'),
            ),
            const Divider(),
            Expanded(
              child: isSchoolOrChurch
                  // Schools and churches are not sellers — show info only.
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '${lm['name']} is a ${type == 'school' ? 'school' : 'church'}.\nThis location does not offer pasalubong products.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : isPasalubong
                      ? ListView.builder(
                          itemCount: productData.length,
                          itemBuilder: (context, index) {
                            final p = productData[index];
                            return ListTile(
                              leading: p['img'] != null
                                  ? Image.asset(
                                      p['img'],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox(width: 48, height: 48),
                              title: Text(p['name'] as String),
                              subtitle: Text(p['price'] as String? ?? ''),
                              trailing: ElevatedButton(
                                child: const Text('Buy'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  final storePos = lm['position'] as LatLng;
                                  final deliveryPos = LatLng(
                                    storePos.latitude + 0.002,
                                    storePos.longitude + 0.001,
                                  );
                                  _startCourierSimulation(storePos, deliveryPos);
                                },
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          itemCount: _sampleProducts.length,
                          itemBuilder: (context, index) {
                            final p = _sampleProducts[index];
                            return ListTile(
                              title: Text(p.name),
                              subtitle: Text('₱${p.price}'),
                              trailing: ElevatedButton(
                                child: const Text('Buy'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  final storePos = lm['position'] as LatLng;
                                  final deliveryPos = LatLng(
                                    storePos.latitude + 0.002,
                                    storePos.longitude + 0.001,
                                  );
                                  _startCourierSimulation(storePos, deliveryPos);
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer - Map (Alibhon, Guimaras)'),
        actions: [
          IconButton(
            tooltip: 'Log out / Back to Login',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          // Newer flutter_map versions use initialCenter/initialZoom.
          initialCenter: CustomerAccount.alibhonCenter,
          initialZoom: 15,
          minZoom: 12,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
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
              ...CustomerAccount.landmarks.map((land) {
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
