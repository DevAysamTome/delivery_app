import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/delivery_person.dart';
import '../services/api_service.dart';

class DeliveryPersonController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _pollingTimer;

  // Get the current delivery person's status
  Stream<DeliveryPerson> getDeliveryPersonStatus() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final userId = _auth.currentUser?.uid;
        if (userId == null) {
          throw Exception('User not logged in');
        }

        final worker = await ApiService.getDeliveryWorker(userId);
        if (worker != null) {
          return worker;
        } else {
          // Return default worker if not found
          return DeliveryPerson(
            userId: userId,
            fullName: 'Unknown',
            email: '',
            phoneNumber: '',
            isAvailable: false,
            status: 'غير متاح',
          );
        }
      } catch (e) {
        print('Error getting delivery person status: $e');
        // Return default worker on error
        return DeliveryPerson(
          userId: _auth.currentUser?.uid ?? '',
          fullName: 'Unknown',
          email: '',
          phoneNumber: '',
          isAvailable: false,
          status: 'غير متاح',
        );
      }
    }).asyncMap((future) => future);
  }

  // Update the delivery person's availability status
  Future<void> updateAvailabilityStatus(bool isAvailable) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      print('Updating availability status for user $userId to: $isAvailable');
      await ApiService.updateDeliveryWorkerAvailability(userId, isAvailable);
      print('Availability status updated successfully');
    } catch (e) {
      print('Error updating availability status: $e');
      rethrow;
    }
  }

  // Initialize delivery person document if it doesn't exist
  Future<void> initializeDeliveryPerson(String name) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      final existingWorker = await ApiService.getDeliveryWorker(userId);
      if (existingWorker == null) {
        // Create new delivery worker
        final newWorker = DeliveryPerson(
          userId: userId,
          fullName: name,
          email: '',
          phoneNumber: '',
          isAvailable: false,
          status: 'غير متاح',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await ApiService.createOrUpdateDeliveryWorker(newWorker);
      }
    } catch (e) {
      print('Error initializing delivery person: $e');
      rethrow;
    }
  }

  // Update delivery person location
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      await ApiService.updateDeliveryWorkerLocation(userId, latitude, longitude);
    } catch (e) {
      print('Error updating location: $e');
      rethrow;
    }
  }

  // Update FCM token
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      await ApiService.updateDeliveryWorkerToken(userId, fcmToken);
    } catch (e) {
      print('Error updating FCM token: $e');
      rethrow;
    }
  }

  // Get available delivery workers
  Stream<List<DeliveryPerson>> getAvailableDeliveryWorkers() {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      try {
        return await ApiService.getAvailableDeliveryWorkers();
      } catch (e) {
        print('Error getting available delivery workers: $e');
        return <DeliveryPerson>[];
      }
    }).asyncMap((future) => future);
  }

  // Start polling for updates
  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      // This will trigger the streams to refresh
    });
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // Dispose resources
  void dispose() {
    stopPolling();
  }
} 