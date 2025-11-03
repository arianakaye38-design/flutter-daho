import 'dart:async';
import 'package:latlong2/latlong.dart';

// Firestore is used when available. Calls are guarded with try/catch so the
// existing simulator remains the fallback for local development.
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  // Singleton
  OrderService._private();
  static final OrderService instance = OrderService._private();

  final Map<String, StreamController<LatLng>> _courierControllers = {};

  Stream<LatLng> simulateCourier(
    String orderId,
    LatLng from,
    LatLng to, {
    int steps = 40,
    Duration stepDuration = const Duration(milliseconds: 500),
  }) {
    final ctrl = StreamController<LatLng>();
    _courierControllers[orderId] = ctrl;

    // simple linear interpolation
    Timer.periodic(stepDuration, (timer) {
      final t = timer.tick / steps;
      if (t > 1.0) {
        ctrl.add(to);
        ctrl.close();
        timer.cancel();
        return;
      }
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;
      ctrl.add(LatLng(lat, lng));
    });

    return ctrl.stream;
  }

  void cancelSimulation(String orderId) {
    final c = _courierControllers.remove(orderId);
    c?.close();
  }

  /// Attempts to connect to Firestore order position updates at
  /// `orders/{orderId}/position`. The Firestore path and field shape can be
  /// adapted to your schema. If Firestore isn't available or fails, this
  /// returns the same simulated stream.
  Stream<LatLng> orderPositionStream(
    String orderId,
    LatLng fallbackStart,
    LatLng fallbackEnd,
  ) {
    // Try to use Firestore realtime updates. We expect the document at
    // `orders/{orderId}` to contain fields `lat` and `lng` (numbers). If your
    // schema uses a subcollection (e.g. `positions`) adjust the path below.
    try {
      final docRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId);

      final stream = docRef.snapshots().map((snap) {
        final data = snap.data();
        if (data == null) throw StateError('no data for order $orderId');

        // Firestore Map uses dynamic values — be defensive converting to double.
        double toDouble(dynamic v) {
          if (v is num) return v.toDouble();
          if (v is String) return double.tryParse(v) ?? 0.0;
          return 0.0;
        }

        final lat = toDouble(data['lat']);
        final lng = toDouble(data['lng']);
        return LatLng(lat, lng);
      });

      return stream;
    } catch (e) {
      // On any error (Firestore not configured, permissions, network),
      // return the simulated courier stream so the app remains functional.
      return simulateCourier(orderId, fallbackStart, fallbackEnd);
    }
  }

  /// Write a courier position to Firestore for an order. Returns true on
  /// success. This is a convenience for integration tests or simulation that
  /// want to visually move the courier in real-time for other clients.
  Future<bool> writeCourierPosition(String orderId, LatLng position) async {
    try {
      final docRef = FirebaseFirestore.instance.doc('orders/$orderId');
      await docRef.set({
        'lat': position.latitude,
        'lng': position.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }
}
