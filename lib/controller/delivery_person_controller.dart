import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_app/models/delivery_person.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeliveryPersonController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current delivery person's status
  Stream<DeliveryPerson> getDeliveryPersonStatus() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    return _firestore
        .collection('deliveryWorkers')
        .doc(userId)
        .snapshots()
        .map((doc) {
          final data = doc.data() ?? {};
          // Convert string status to boolean
          final isAvailable = data['status'] == 'متاح';
          return DeliveryPerson.fromMap({
            ...data,
            'isAvailable': isAvailable,
          });
        });
  }

  // Update the delivery person's availability status
  Future<void> updateAvailabilityStatus(bool isAvailable) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    await _firestore.collection('deliveryWorkers').doc(userId).set({
      'id': userId,
      'status': isAvailable ? 'متاح' : 'غير متاح',
    }, SetOptions(merge: true));
  }

  // Initialize delivery person document if it doesn't exist
  Future<void> initializeDeliveryPerson(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final docRef = _firestore.collection('deliveryWorkers').doc(userId);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'id': userId,
        'name': name,
        'status': 'غير متاح',
        'currentOrderId': null,
      });
    }
  }
} 