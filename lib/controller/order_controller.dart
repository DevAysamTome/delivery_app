import 'package:cloud_firestore/cloud_firestore.dart';

class OrderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Stream<int> getNewOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'مكتمل')
        .where('deliveryOption', isEqualTo: 'delivery')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getInProgressOrdersCount() {
    return _firestore
        .collection('orders')
        .where('orderStatus', isEqualTo: 'جاري التوصيل')
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

  // قبول الطلب
  Future<void> acceptOrder(String orderId) async {
    try {
      // الحصول على الطلب الحالي من الـ Collection الأصلي
      QuerySnapshot storeOrdersSnapshot = await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('storeOrders')
          .get();

      if (storeOrdersSnapshot.docs.isNotEmpty) {
        // Assuming you want to handle all the documents in the 'storeOrders' sub-collection
        for (QueryDocumentSnapshot storeOrderDoc in storeOrdersSnapshot.docs) {
          // Get the data from the document
          Map<String, dynamic> storeOrderData =
              storeOrderDoc.data() as Map<String, dynamic>;

          // Store the accepted order in a new collection
          await _firestore.collection('accepted_orders').doc(orderId).set({
            'orderId': orderId, // Order ID comes from the parent document
            'userId': storeOrderData['userId'],
            'address': storeOrderData['placeName'],
            'items': storeOrderData['items'],
            'orderStatus': 'تم اخذ الطلب',
            'totalPrice': storeOrderData['totalPrice'],
            'acceptedAt': Timestamp.now(),
            'deliveryLocation': storeOrderData['userLocation'],
          });

          // Update the order status in the original collection
          await _firestore
              .collection('orders')
              .doc(orderId)
              .update({'orderStatus': 'جاري التوصيل'});
        }
      }
    } catch (e) {
      print('Error accepting order: $e');
    }
  }
}
