import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<int> getNewOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'مكتمل')
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
        .where('orderStatus', isEqualTo: 'مكتمل')
        .where('deliveryOption', isEqualTo: 'delivery')
        .snapshots();
  }

  Stream<Map<String, dynamic>> getOrdersDetailsWithMainFields() async* {
    // جلب orderId من /order_numbers/current
    DocumentSnapshot currentSnapshot =
        await _firestore.collection('order_numbers').doc('current').get();

    if (currentSnapshot.exists) {
      String orderId = currentSnapshot.get('currentNumber').toString();

      // استرجاع المستند الرئيسي باستخدام orderId
      DocumentSnapshot orderSnapshot =
          await _firestore.collection('orders').doc(orderId).get();

      if (orderSnapshot.exists) {
        // استرجاع جميع المستندات داخل المجموعة الفرعية
        Stream<QuerySnapshot> storeOrdersSnapshot = _firestore
            .collection('orders')
            .doc(orderId)
            .collection('storeOrders')
            .where('orderStatus', isEqualTo: 'مكتمل')
            .snapshots();

        // دمج الحقول من المستند الرئيسي مع الحقول من المستندات الفرعية
        await for (QuerySnapshot snapshot in storeOrdersSnapshot) {
          List<Object?> storeOrders =
              snapshot.docs.map((doc) => doc.data()).toList();

          yield {
            'mainOrder': orderSnapshot.data(), // البيانات من المستند الرئيسي
            'storeOrders': storeOrders // البيانات من المستندات الفرعية
          };
        }
      }
    } else {
      throw Exception('No current order found.');
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
          final orderLocation = orderLatitude != null && orderLongitude != null
              ? LatLng(orderLatitude, orderLongitude)
              : const LatLng(0.0, 0.0);

          await _firestore.collection('accepted_orders').doc(orderId).set({
            'orderId': orderId,
            'userId': storeOrderData['userId'],
            'address': storeOrderData['address'],
            'items': storeOrderData['items'],
            'orderStatus': 'تم اخذ الطلب',
            'totalPrice': storeOrderData['totalPrice'],
            'acceptedAt': Timestamp.now(),
            'deliveryLocation': orderLocation,
            'assignedTo': deliveryWorkerId // إضافة معرّف عامل التوصيل هنا
          });

          await _firestore.collection('orders').doc(orderId).update({
            'orderStatus': 'جاري التوصيل',
            'assignedTo': deliveryWorkerId // تعيين معرّف عامل التوصيل هنا
          });
        }
      }
    } catch (e) {
      print('Error accepting order: $e');
    }
  }
}
