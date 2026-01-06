import 'package:latlong2/latlong.dart';

class Order {
  final String id;
  final String productId;
  final String customerId;
  final LatLng deliveryPoint;

  Order({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.deliveryPoint,
  });
}
