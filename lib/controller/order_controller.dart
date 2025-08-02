import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/order.dart';

class OrderController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _pollingTimer;
  final StreamController<void> _refreshController = StreamController<void>.broadcast();

  // Stream for new orders count
  Stream<int> getNewOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['تم تجهيز الطلب', 'قيد الانتظار'],
          currentUserId,
        );
        return orders.length;
      } catch (e) {
        print('Error getting new orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Stream for new in-progress orders count
  Stream<int> getNewInProgressOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['تم تجهيز الطلب', 'قيد الانتظار'],
          currentUserId,
        );
        return orders.length;
      } catch (e) {
        print('Error getting in-progress orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Stream for ongoing in-progress orders count
  Stream<int> getOnGoingInProgressOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['جاري التوصيل'],
          currentUserId,
        );
        return orders.length;
      } catch (e) {
        print('Error getting ongoing orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Get orders by status
  Stream<List<Order>> getOrdersByStatus(String status) {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return <Order>[];
        
        final orders = await ApiService.getOrdersByStatusAndWorker(
          [status, 'قيد الانتظار'],
          currentUserId,
        );
        return orders;
      } catch (e) {
        print('Error getting orders by status: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Get orders details with main fields
  Stream<Map<String, dynamic>> getOrdersDetailsWithMainFields() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) {
          return {
            'mainOrders': <Map<String, dynamic>>[],
          };
        }

        // Get all orders that are ready for delivery or pending
        final allOrders = await ApiService.getAllOrders();
        
        if (allOrders.isEmpty) {
          return {
            'mainOrders': <Map<String, dynamic>>[],
          };
        }

        List<Map<String, dynamic>> filteredOrders = [];

        // Process each order
        for (var order in allOrders) {
          // Check if this order is assigned to the current delivery worker
          String? assignedTo = order.assignedTo;
          bool isAssignedToMe = assignedTo == currentUserId;
          
          // Only process orders that are either:
          // 1. Not assigned to anyone (normal mode)
          // 2. Assigned to this delivery worker (admin mode)
          if (assignedTo == null || isAssignedToMe) {
            // Check if order has ready status
            final hasReadyStatus = ['تم تجهيز الطلب', 'قيد الانتظار', 'تم اخذ الطلب', 'عامل التوصيل قد استلم الطلب']
                .contains(order.orderStatus);
            final isDeliveryOrder = order.deliveryOption == 'delivery';
            
            if (hasReadyStatus && isDeliveryOrder) {
              filteredOrders.add({
                'mainOrder': order.toJson(),
                'storeOrders': [order.toJson()], // For simplicity, treating main order as store order
              });
            }
          }
        }

        return {
          'mainOrders': filteredOrders,
        };
      } catch (e) {
        print('Error fetching orders: $e');
        return {
          'mainOrders': <Map<String, dynamic>>[],
        };
      }
    }).asyncMap((future) => future);
  }

  // Get customer name
  Future<String> getCustomerName(String userId) async {
    try {
      return await ApiService.getCustomerName(userId);
    } catch (e) {
      print('Error fetching customer name: $e');
      return 'غير معروف';
    }
  }

  // Get customer phone
  Future<String> getCustomerPhone(String userId) async {
    try {
      return await ApiService.getCustomerPhone(userId);
    } catch (e) {
      print('Error fetching customer phone: $e');
      return 'غير متوفر';
    }
  }

  // Get delivery worker ID
  Future<String?> getDeliveryWorkerId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('deliveryWorkerId');
  }

  // Get assigned orders
  Stream<List<Order>> getAssignedOrders(String deliveryWorkerId) {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['جاري التوصيل'],
          deliveryWorkerId,
        );
        return orders;
      } catch (e) {
        print('Error getting assigned orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Fetch assigned orders
  Stream<List<Order>> fetchAssignedOrders() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        String? deliveryWorkerId = await getDeliveryWorkerId();
        if (deliveryWorkerId != null) {
          return await ApiService.getOrdersByStatusAndWorker(
            ['جاري التوصيل'],
            deliveryWorkerId,
          );
        } else {
          print('Error: No delivery worker ID found.');
          return <Order>[];
        }
      } catch (e) {
        print('Error fetching assigned orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Accept order
  Future<void> acceptOrder(String orderId, String deliveryWorkerId) async {
    try {
      await ApiService.acceptOrder(orderId, deliveryWorkerId);
      print('Order accepted successfully, triggering immediate refresh');
      refreshOrders();
    } catch (e) {
      print('Error accepting order: $e');
      rethrow;
    }
  }

  // Confirm order received
  Future<void> confirmOrderReceived(String orderId) async {
    try {
      await ApiService.confirmOrderReceived(orderId);
      print('Order received confirmed, triggering immediate refresh');
      refreshOrders();
    } catch (e) {
      print('Error confirming order received: $e');
      rethrow;
    }
  }

  // Complete delivery
  Future<void> completeDelivery(String orderId) async {
    try {
      await ApiService.completeDelivery(orderId);
      print('Delivery completed, triggering immediate refresh');
      refreshOrders();
    } catch (e) {
      print('Error completing delivery: $e');
      rethrow;
    }
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

  // Trigger immediate refresh
  void refreshOrders() {
    _refreshController.add(null);
  }

  // Dispose resources
  void dispose() {
    stopPolling();
    _refreshController.close();
  }
}
