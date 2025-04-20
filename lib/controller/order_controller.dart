import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getNewOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'تم تجهيز الطلب')
        .where('deliveryOption', isEqualTo: 'delivery')
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getInProgressOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'جاري التوصيل')
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<QuerySnapshot> getOrdersByStatus(String status) {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: status)
        .where('deliveryOption', isEqualTo: 'delivery')
        .snapshots();
  }

  Stream<QuerySnapshot> getOrders() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'تم تجهيز الطلب')
        .where('deliveryOption', isEqualTo: 'delivery')
        .snapshots();
  }

  Stream<Map<String, dynamic>> getOrdersDetailsWithMainFields() async* {
    try {
      // Get all orders that are ready for delivery
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('orderStatus', isEqualTo: 'تم تجهيز الطلب')
          .where('deliveryOption', isEqualTo: 'delivery')
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        yield {
          'mainOrder': null,
          'storeOrders': <Map<String, dynamic>>[],
        };
        return;
      }

      // Process each order
      for (var orderDoc in ordersSnapshot.docs) {
        String orderId = orderDoc.id;
        Map<String, dynamic> mainOrderData = orderDoc.data() as Map<String, dynamic>;
        
        // Get store orders for this order
        QuerySnapshot storeOrdersSnapshot = await _firestore
            .collection('orders')
            .doc(orderId)
            .collection('storeOrders')
            .where('orderStatus', isEqualTo: 'تم تجهيز الطلب')
            .get();

        if (storeOrdersSnapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> storeOrders = storeOrdersSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          yield {
            'mainOrder': mainOrderData,
            'storeOrders': storeOrders,
          };
        }
      }
    } catch (e) {
      print('Error fetching orders: $e');
      yield {
        'mainOrder': null,
        'storeOrders': <Map<String, dynamic>>[],
      };
    }
  }

  Future<String> getCustomerName(String userId) async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        return userSnapshot['fullName'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      print('Error fetching customer name: $e');
      return 'Unknown';
    }
  }

  Future<String?> getDeliveryWorkerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('deliveryWorkerId');
  }

  Stream<QuerySnapshot> getAssignedOrders(String deliveryWorkerId) {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'جاري التوصيل')
        .where('assignedTo',
            isEqualTo: deliveryWorkerId) // تصفية حسب معرّف عامل التوصيل
        .snapshots();
  }

  Stream<QuerySnapshot> fetchAssignedOrders() async* {
    String? deliveryWorkerId = await getDeliveryWorkerId();
    if (deliveryWorkerId != null) {
      yield* getAssignedOrders(deliveryWorkerId);
    } else {
      print('Error: No delivery worker ID found.');
    }
  }

  // قبول الطلب
  Future<void> acceptOrder(String orderId, String deliveryWorkerId) async {
    try {
      QuerySnapshot storeOrdersSnapshot = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('storeOrders')
          .get();

      if (storeOrdersSnapshot.docs.isNotEmpty) {
        for (QueryDocumentSnapshot storeOrderDoc in storeOrdersSnapshot.docs) {
          Map<String, dynamic> storeOrderData =
              storeOrderDoc.data() as Map<String, dynamic>;
          final orderLocationData = storeOrderData['deliveryDetails']
                  ?['location'] as Map<String, dynamic>? ??
              {};
          final orderLatitude = orderLocationData['latitude'] as double?;
          final orderLongitude = orderLocationData['longitude'] as double?;

          await _firestore.collection('accepted_orders').doc(orderId).set({
            'orderId': orderId,
            'userId': storeOrderData['userId'],
            'address': storeOrderData['address'],
            'items': storeOrderData['items'],
            'orderStatus': 'تم اخذ الطلب',
            'totalPrice': storeOrderData['totalPrice'],
            'acceptedAt': Timestamp.now(),
            'deliveryLocation': {
              'latitude': orderLatitude ?? 0.0,
              'longitude': orderLongitude ?? 0.0,
            },
            'assignedTo': deliveryWorkerId
          });

          await _firestore.collection('orders').doc(orderId).update({
            'orderStatus': 'تم اخذ الطلب',
            'assignedTo': deliveryWorkerId
          });
        }
      }
    } catch (e) {
      print('Error accepting order: $e');
      rethrow; // Rethrow the error to handle it in the UI
    }
  }

  // تأكيد استلام الطلب من المطعم
  Future<void> confirmOrderReceived(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': 'عامل التوصيل قد استلم الطلب',
        'receivedAt': Timestamp.now()
      });

      // Set a timer to change status to "جاري التوصيل" after 5 minutes
      Future.delayed(const Duration(minutes: 5), () async {
        await _firestore.collection('orders').doc(orderId).update({
          'orderStatus': 'جاري التوصيل',
          'deliveryStartedAt': Timestamp.now()
        });
      });
    } catch (e) {
      print('Error confirming order received: $e');
      rethrow;
    }
  }

  // تأكيد اكتمال التوصيل
  Future<void> completeDelivery(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': 'تم التوصيل',
        'deliveredAt': Timestamp.now()
      });
    } catch (e) {
      print('Error completing delivery: $e');
      rethrow;
    }
  }
}
