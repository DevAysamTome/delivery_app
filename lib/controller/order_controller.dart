import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getNewOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', whereIn: ['تم تجهيز الطلب', 'قيد الانتظار'])
        .where('deliveryOption', isEqualTo: 'delivery')
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getNewInProgressOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', whereIn: ['تم تجهيز الطلب', 'قيد الانتظار'])
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  Stream<int> getOnGoingInProgressOrdersCount() {
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
        .where('orderStatus', whereIn: [status, 'قيد الانتظار'])
        .where('deliveryOption', isEqualTo: 'delivery')
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots();
  }

  Stream<QuerySnapshot> getOrders() {
    return _firestore
        .collection('orders')
        .where('orderStatus', whereIn: ['تم تجهيز الطلب', 'قيد الانتظار'])
        .where('deliveryOption', isEqualTo: 'delivery')
        .where('assignedTo', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
        .snapshots();
  }

  Stream<Map<String, dynamic>> getOrdersDetailsWithMainFields() async* {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        yield {
          'mainOrders': <Map<String, dynamic>>[],
        };
        return;
      }

      // Get all orders that are ready for delivery or pending
      QuerySnapshot ordersSnapshot = await _firestore
          .collection('orders')
          .where('orderStatus', whereIn: ['تم تجهيز الطلب', 'قيد الانتظار', 'تم اخذ الطلب', 'عامل التوصيل قد استلم الطلب'])
          .where('deliveryOption', isEqualTo: 'delivery')
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        yield {
          'mainOrders': <Map<String, dynamic>>[],
        };
        return;
      }

      List<Map<String, dynamic>> allOrders = [];

      // Process each order
      for (var orderDoc in ordersSnapshot.docs) {
        String orderId = orderDoc.id;
        Map<String, dynamic> mainOrderData = orderDoc.data() as Map<String, dynamic>;
        
        // Check if this order is assigned to the current delivery worker
        String? assignedTo = mainOrderData['assignedTo'] as String?;
        bool isAssignedToMe = assignedTo == currentUserId;
        
        // Only process orders that are either:
        // 1. Not assigned to anyone (normal mode)
        // 2. Assigned to this delivery worker (admin mode)
        if (assignedTo == null || isAssignedToMe) {
          // Get store orders for this order
          QuerySnapshot storeOrdersSnapshot = await _firestore
              .collection('orders')
              .doc(orderId)
              .collection('storeOrders')
              .where('orderStatus', whereIn: ['تم تجهيز الطلب', 'قيد الانتظار'])
              .get();

          if (storeOrdersSnapshot.docs.isNotEmpty) {
            List<Map<String, dynamic>> storeOrders = storeOrdersSnapshot.docs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList();

            allOrders.add({
              'mainOrder': mainOrderData,
              'storeOrders': storeOrders,
            });
          }
        }
      }

      yield {
        'mainOrders': allOrders,
      };
    } catch (e) {
      print('Error fetching orders: $e');
      yield {
        'mainOrders': <Map<String, dynamic>>[],
      };
    }
  }

  Future<String> getCustomerName(String userId) async {
    try {
      if (userId.isEmpty) {
        return 'غير معروف';
      }
      
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        return userSnapshot['fullName'] as String? ?? 'غير معروف';
      } else {
        return 'غير معروف';
      }
    } catch (e) {
      print('Error fetching customer name: $e');
      return 'غير معروف';
    }
  }

  Future<String> getCustomerPhone(String userId) async {
    try {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(userId).get();
      if (userSnapshot.exists) {
        return userSnapshot['phoneNumber'] ?? 'غير متوفر';
      } else {
        return 'غير متوفر';
      }
    } catch (e) {
      print('Error fetching customer phone: $e');
      return 'غير متوفر';
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
      // First update the order status to received
      await _firestore.collection('orders').doc(orderId).update({
        'orderStatus': 'عامل التوصيل قد استلم الطلب',
        'receivedAt': Timestamp.now(),
        'deliveryTimer': Timestamp.fromDate(DateTime.now().add(const Duration(seconds: 5))), // Add timer field
      });

      // Call the Cloud Function to handle the timer
      
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
