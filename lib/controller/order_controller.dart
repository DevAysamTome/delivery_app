import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../models/order.dart';
import 'dart:convert'; // Added for json.decode

class OrderController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Timer? _pollingTimer;
  final StreamController<void> _refreshController = StreamController<void>.broadcast();

  // Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Stream for new orders count (with location-based filtering)
  Stream<int> getNewOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['تم تجهيز الطلب', 'قيد الانتظار'],
            currentUserId,
          );
          return orders.length;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['تم تجهيز الطلب', 'قيد الانتظار'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders.length;
      } catch (e) {
        print('Error getting new orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Stream for new in-progress orders count (with location-based filtering)
  Stream<int> getNewInProgressOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['تم تجهيز الطلب', 'قيد الانتظار'],
            currentUserId,
          );
          return orders.length;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['تم تجهيز الطلب', 'قيد الانتظار'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders.length;
      } catch (e) {
        print('Error getting in-progress orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Stream for ongoing in-progress orders count (with location-based filtering)
  Stream<int> getOnGoingInProgressOrdersCount() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return 0;
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['جاري التوصيل'],
            currentUserId,
          );
          return orders.length;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['جاري التوصيل'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders.length;
      } catch (e) {
        print('Error getting ongoing orders count: $e');
        return 0;
      }
    }).asyncMap((future) => future);
  }

  // Get orders by status (with location-based filtering)
  Stream<List<Order>> getOrdersByStatus(String status) {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return <Order>[];
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            [status, 'قيد الانتظار'],
            currentUserId,
          );
          return orders;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          [status, 'قيد الانتظار'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders;
      } catch (e) {
        print('Error getting orders by status: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Get orders details with main fields (with location-based filtering)
  Stream<Map<String, dynamic>> getOrdersDetailsWithMainFields() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) {
          return {
            'mainOrders': <Map<String, dynamic>>[],
          };
        }

        // Get current location
        final position = await _getCurrentLocation();
        List<Order> allOrders;

        if (position != null) {
          // Use nearby orders with location
          print('[OrderController] Using nearby orders with location: ${position.latitude}, ${position.longitude}');
          allOrders = await ApiService.getNearbyOrders(
            latitude: position.latitude,
            longitude: position.longitude,
            radiusInKm: 5.0,
            deliveryWorkerId: currentUserId,
            status: 'قيد الانتظار', // Use pending status for nearby orders
          );
        } else {
          // Fallback to regular orders if location not available
          print('[OrderController] Using regular orders (location not available)');
          allOrders = await ApiService.getOrders();
        }
        
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

  // Get assigned orders (with location-based filtering)
  Stream<List<Order>> getAssignedOrders(String deliveryWorkerId) {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['جاري التوصيل'],
            deliveryWorkerId,
          );
          return orders;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['جاري التوصيل'],
          deliveryWorkerId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders;
      } catch (e) {
        print('Error getting assigned orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Fetch assigned orders (with location-based filtering)
  Stream<List<Order>> fetchAssignedOrders() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        String? deliveryWorkerId = await getDeliveryWorkerId();
        if (deliveryWorkerId != null) {
          // Get current location
          final position = await _getCurrentLocation();
          if (position == null) {
            // Fallback to regular orders if location not available
            return await ApiService.getOrdersByStatusAndWorker(
              ['جاري التوصيل'],
              deliveryWorkerId,
            );
          }

          // Use nearby orders with location
          return await ApiService.getOrdersByStatusAndWorker(
            ['جاري التوصيل'],
            deliveryWorkerId,
            latitude: position.latitude,
            longitude: position.longitude,
            radiusInKm: 5.0,
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

  // Get pending orders (with location-based filtering)
  Stream<List<Order>> getPendingOrders() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return <Order>[];
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['قيد الانتظار'],
            currentUserId,
          );
          return orders;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['قيد الانتظار'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders;
      } catch (e) {
        print('Error getting pending orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Get ready orders (with location-based filtering)
  Stream<List<Order>> getReadyOrders() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return <Order>[];
        
        // Get current location
        final position = await _getCurrentLocation();
        if (position == null) {
          // Fallback to regular orders if location not available
          final orders = await ApiService.getOrdersByStatusAndWorker(
            ['تم تجهيز الطلب'],
            currentUserId,
          );
          return orders;
        }

        // Use nearby orders with location
        final orders = await ApiService.getOrdersByStatusAndWorker(
          ['تم تجهيز الطلب'],
          currentUserId,
          latitude: position.latitude,
          longitude: position.longitude,
          radiusInKm: 5.0,
        );
        return orders;
      } catch (e) {
        print('Error getting ready orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Get completed orders (without location filtering)
  Stream<List<Order>> getCompletedOrders() {
    return Stream.periodic(const Duration(seconds: 8), (_) async {
      try {
        final currentUserId = _auth.currentUser?.uid;
        if (currentUserId == null) return <Order>[];
        
        print('[OrderController] Getting completed orders for worker: $currentUserId');
        
        // Get all orders and filter by status and worker
        final response = await ApiService.getOrders();
        
        // Filter by status and worker
        final completedOrders = response.where((order) {
          final statusMatch = order.orderStatus == 'تم التوصيل';
          final workerMatch = order.assignedTo == currentUserId;
          return statusMatch && workerMatch;
        }).toList();
        
        print('[OrderController] Found ${response.length} total orders, ${completedOrders.length} completed orders for worker $currentUserId');
        return completedOrders;
      } catch (e) {
        print('Error getting completed orders: $e');
        return <Order>[];
      }
    }).asyncMap((future) => future);
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await ApiService.updateOrder(orderId, Order(
        orderId: orderId,
        orderStatus: newStatus,
        storeId: '',
        userId: '',
        totalPrice: 0,
        items: [],
        placeName: '',
        selectedAddOns: [],
      ));
    } catch (e) {
      print('Error updating order status: $e');
      throw e;
    }
  }

  // Accept order
  Future<void> acceptOrder(String orderId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      await ApiService.acceptOrder(orderId, currentUserId);
    } catch (e) {
      print('Error accepting order: $e');
      throw e;
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

  // Refresh orders
  void refreshOrders() {
    _refreshController.add(null);
  }

  // Dispose resources
  void dispose() {
    stopPolling();
    _refreshController.close();
  }
}
