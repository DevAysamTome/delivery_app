import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../models/delivery_person.dart';
import '../models/store_order.dart';

class ApiService {
  static const String baseUrl = 'https://backend-jm4h.onrender.com/api';
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Helper method for making HTTP requests with retry logic
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<http.Response> _makeRequest(
    String url,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    print('[ApiService] Making $method request to: $url');
    print('[ApiService] Token present: ${token != null}');
    print('[ApiService] Headers: $headers');

    const int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        http.Response response;
        
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(Uri.parse(url), headers: headers);
            break;
          case 'POST':
            response = await http.post(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              Uri.parse(url),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(Uri.parse(url), headers: headers);
            break;
          default:
            throw Exception('Unsupported HTTP method: $method');
        }

        print('[ApiService] Response status: ${response.statusCode}');
        if (response.statusCode == 401) {
          print('[ApiService] 401 Unauthorized - Token might be invalid or missing');
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else if (response.statusCode >= 500 && retryCount < maxRetries - 1) {
          // Retry on server errors
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          continue;
        } else {
          return response;
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }
        throw Exception('Network error: $e');
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  // ========== ORDER METHODS ==========

  // Get all orders
  static Future<List<Order>> getAllOrders() async {
    try {
      final response = await _makeRequest('$baseUrl/order', 'GET');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }

  // Get order by MongoDB _id
  static Future<Order> getOrderById(String id) async {
    try {
      final response = await _makeRequest('$baseUrl/order/byOrderId/$id', 'GET');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Order.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Order not found');
      } else {
        throw Exception('Failed to load order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching order: $e');
    }
  }

  // Get order by orderId (sequential number)
  static Future<Order> getOrderByOrderId(int orderId) async {
    try {
      final response = await _makeRequest('$baseUrl/orders/byOrderId/$orderId', 'GET');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Order.fromJson(data);
      } else if (response.statusCode == 404) {
        throw Exception('Order not found');
      } else {
        throw Exception('Failed to load order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching order: $e');
    }
  }

  // Create new order
  static Future<Map<String, dynamic>> createOrder(Order order) async {
    try {
      final response = await _makeRequest(
        '$baseUrl/orders',
        'POST',
        body: order.toJson(),
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating order: $e');
    }
  }

  // Update order
  static Future<Order> updateOrder(String id, Order order) async {
    try {
      print('[ApiService] Updating order with body: ${order.toJson()}');
      final response = await _makeRequest(
        '$baseUrl/order/byOrderId/$id',
        'PUT',
        body: order.toJson(),
      );
      print('[ApiService] Update order response: ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Order.fromJson(data);
      } else {
        throw Exception('Failed to update order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating order: $e');
    }
  }

  // Delete order
  static Future<void> deleteOrder(String id) async {
    try {
      final response = await _makeRequest('$baseUrl/orders/$id', 'DELETE');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting order: $e');
    }
  }

  // Get orders by userId
  static Future<List<Order>> getOrdersByUserId(String userId) async {
    try {
      final response = await _makeRequest('$baseUrl/orders/user/$userId', 'GET');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user orders: $e');
    }
  }

  // Get orders by status and delivery worker
  static Future<List<Order>> getOrdersByStatusAndWorker(
    List<String> statuses,
    String deliveryWorkerId,
  ) async {
    try {
      // First get all orders
      final allOrders = await getAllOrders();
      
      // Filter by status and delivery worker
      return allOrders.where((order) {
        final hasMatchingStatus = statuses.contains(order.orderStatus);
        final isAssignedToWorker = order.assignedTo == deliveryWorkerId;
        final isDeliveryOrder = order.deliveryOption == 'delivery';
        
        return hasMatchingStatus && isAssignedToWorker && isDeliveryOrder;
      }).toList();
    } catch (e) {
      throw Exception('Error fetching orders by status: $e');
    }
  }

  // Get orders for delivery (not assigned or assigned to specific worker)
  static Future<List<Order>> getDeliveryOrders(String? deliveryWorkerId) async {
    try {
      final allOrders = await getAllOrders();
      
      return allOrders.where((order) {
        final isDeliveryOrder = order.deliveryOption == 'delivery';
        final hasReadyStatus = ['تم تجهيز الطلب', 'قيد الانتظار', 'تم اخذ الطلب', 'عامل التوصيل قد استلم الطلب']
            .contains(order.orderStatus);
        
        if (deliveryWorkerId != null) {
          // Return orders assigned to this worker
          return isDeliveryOrder && hasReadyStatus && order.assignedTo == deliveryWorkerId;
        } else {
          // Return unassigned orders
          return isDeliveryOrder && hasReadyStatus && order.assignedTo == null;
        }
      }).toList();
    } catch (e) {
      throw Exception('Error fetching delivery orders: $e');
    }
  }

  // Accept order
  static Future<void> acceptOrder(String orderId, String deliveryWorkerId) async {
    try {
      print('[ApiService] Accepting order: $orderId for delivery worker: $deliveryWorkerId');
      final order = await getOrderById(orderId);
      print('[ApiService] Original order assignedTo: ${order.assignedTo}');
      
      // Try different field names that the backend might expect
      final updateData = {
        'orderStatus': 'تم اخذ الطلب',
        'assignedTo': deliveryWorkerId,
        'assigned_to': deliveryWorkerId,
        'deliveryWorkerId': deliveryWorkerId,
        'deliveryWorker': deliveryWorkerId,
        'workerId': deliveryWorkerId,
      };
      
      print('[ApiService] Update data being sent:');
      print('[ApiService] - assignedTo: ${updateData['assignedTo']}');
      print('[ApiService] - orderStatus: ${updateData['orderStatus']}');
      print('[ApiService] Sending update data: $updateData');
      
      // Use the byOrderId endpoint as shown in the backend code
      final response = await _makeRequest(
        '$baseUrl/order/byOrderId/$orderId',
        'PUT',
        body: updateData,
      );
      
      print('[ApiService] Update response: ${response.body}');
      
      if (response.statusCode == 200) {
        print('[ApiService] Update successful!');
        
        // Wait a moment for the database to update
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verify the update by fetching the order again
        final verificationOrder = await getOrderById(orderId);
        print('[ApiService] Verification - order assignedTo: ${verificationOrder.assignedTo}');
        
        if (verificationOrder.assignedTo != deliveryWorkerId) {
          print('[ApiService] WARNING: assignedTo field was not properly saved!');
          print('[ApiService] Expected: $deliveryWorkerId, Got: ${verificationOrder.assignedTo}');
        } else {
          print('[ApiService] SUCCESS: assignedTo field was properly saved!');
        }
      } else {
        throw Exception('Failed to update order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error accepting order: $e');
    }
  }

  // Confirm order received
  static Future<void> confirmOrderReceived(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      final updatedOrder = order.copyWith(
        orderStatus: 'عامل التوصيل قد استلم الطلب',
        updatedAt: DateTime.now(),
      );
      
      await updateOrder(orderId, updatedOrder);
    } catch (e) {
      throw Exception('Error confirming order received: $e');
    }
  }

  // Complete delivery
  static Future<void> completeDelivery(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      final updatedOrder = order.copyWith(
        orderStatus: 'تم التوصيل',
        updatedAt: DateTime.now(),
      );
      
      await updateOrder(orderId, updatedOrder);
    } catch (e) {
      throw Exception('Error completing delivery: $e');
    }
  }

  // ========== STORE ORDERS METHODS ==========

  // Get all store orders
  static Future<List<StoreOrder>> getAllStoreOrders() async {
    try {
      final response = await _makeRequest('$baseUrl/store-orders', 'GET');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => StoreOrder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load store orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching store orders: $e');
    }
  }

  // Create new store order
  static Future<StoreOrder> createStoreOrder(StoreOrder storeOrder) async {
    try {
      final response = await _makeRequest(
        '$baseUrl/store-orders',
        'POST',
        body: storeOrder.toJson(),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return StoreOrder.fromJson(data);
      } else {
        throw Exception('Failed to create store order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating store order: $e');
    }
  }

  // Get store orders by user ID
  static Future<List<StoreOrder>> getStoreOrdersByUserId(String userId) async {
    try {
      final response = await _makeRequest('$baseUrl/store-orders/users/$userId', 'GET');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => StoreOrder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user store orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user store orders: $e');
    }
  }

  // Get store orders by main order ID
  static Future<List<StoreOrder>> getStoreOrdersByMainOrderId(int mainOrderId) async {
    try {
      print('[ApiService] Getting store orders for mainOrderId: $mainOrderId');
      final response = await _makeRequest('$baseUrl/store-orders/main-orders/$mainOrderId', 'GET');
      
      print('[ApiService] Store orders response status: ${response.statusCode}');
      print('[ApiService] Store orders response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('[ApiService] Parsed store orders data: $data');
        return data.map((json) => StoreOrder.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load store orders: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Error fetching store orders: $e');
      throw Exception('Error fetching store orders: $e');
    }
  }

  // Get store orders by main order ID (returns raw data)
  static Future<List<Map<String, dynamic>>> getStoreOrdersByMainOrderIdRaw(int mainOrderId) async {
    try {
      print('[ApiService] Getting store orders (raw) for mainOrderId: $mainOrderId');
      final response = await _makeRequest('$baseUrl/store-orders/byOrder/$mainOrderId', 'GET');
      
      print('[ApiService] Store orders (raw) response status: ${response.statusCode}');
      print('[ApiService] Store orders (raw) response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('[ApiService] Parsed store orders (raw) data: $data');
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load store orders: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Error fetching store orders (raw): $e');
      throw Exception('Error fetching store orders: $e');
    }
  }



  // ========== DELIVERY WORKER METHODS ==========

  // Create delivery worker
  static Future<Map<String, dynamic>> createDeliveryWorker({
    String? id,
    required String email,
    required String fullName,
    required String phoneNumber,
    String? fcmToken,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _makeRequest(
        '$baseUrl/deliveryworkers/create',
        'POST',
        body: {
          if (id != null) '_id': id,
          'email': email,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          if (fcmToken != null) 'fcmToken': fcmToken,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create delivery worker: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating delivery worker: $e');
    }
  }

  // Get delivery worker by ID
  static Future<Map<String, dynamic>?> getDeliveryWorkerById(String _id) async {
    try {
      print('[ApiService] Making GET request to: $baseUrl/deliveryworkers/$_id');
      final response = await _makeRequest('$baseUrl/deliveryworkers/$_id', 'GET');
      
      print('[ApiService] Response status: ${response.statusCode}');
      print('[ApiService] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[ApiService] Parsed data: $data');
        return data;
      } else if (response.statusCode == 404) {
        print('[ApiService] Delivery worker not found (404)');
        return null;
      } else {
        print('[ApiService] Unexpected status code: ${response.statusCode}');
        throw Exception('Failed to load delivery worker: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Error in getDeliveryWorkerById: $e');
      throw Exception('Error fetching delivery worker: $e');
    }
  }

  // Get all delivery workers
  static Future<List<Map<String, dynamic>>> getAllDeliveryWorkers() async {
    try {
      final response = await _makeRequest('$baseUrl/deliveryworkers', 'GET');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => json as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load delivery workers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching delivery workers: $e');
    }
  }

  // Update delivery worker
  static Future<Map<String, dynamic>> updateDeliveryWorker(
    String id, {
    String? status,
    bool? isAvailable,
    double? latitude,
    double? longitude,
    String? fcmToken,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (status != null) body['status'] = status;
      if (isAvailable != null) body['isAvailable'] = isAvailable;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (fcmToken != null) body['fcmToken'] = fcmToken;

      print('Updating delivery worker with body: $body');

      final response = await _makeRequest(
        '$baseUrl/deliveryworkers/$id',
        'PUT',
        body: body,
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update delivery worker: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating delivery worker: $e');
    }
  }

  // Delete delivery worker
  static Future<void> deleteDeliveryWorker(String id) async {
    try {
      final response = await _makeRequest('$baseUrl/deliveryworkers/$id', 'DELETE');
      
      if (response.statusCode != 200) {
        throw Exception('Failed to delete delivery worker: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting delivery worker: $e');
    }
  }

  // Get delivery worker by user ID (for backward compatibility)
  static Future<DeliveryPerson?> getDeliveryWorker(String userId) async {
    try {
      final workerData = await getDeliveryWorkerById(userId);
      if (workerData != null) {
        return DeliveryPerson.fromJson(workerData);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching delivery worker: $e');
    }
  }

  // Create or update delivery worker (for backward compatibility)
  static Future<DeliveryPerson> createOrUpdateDeliveryWorker(DeliveryPerson worker) async {
    try {
      // Try to update first, if not found then create
      try {
        final updated = await updateDeliveryWorker(
          worker.userId,
          status: worker.status,
          isAvailable: worker.isAvailable,
          latitude: worker.latitude,
          longitude: worker.longitude,
          fcmToken: worker.fcmToken,
        );
        return DeliveryPerson.fromJson(updated);
      } catch (e) {
        // If update fails, try to create
        final created = await createDeliveryWorker(
          email: worker.email ?? '',
          fullName: worker.name,
          phoneNumber: worker.phone ?? '',
          fcmToken: worker.fcmToken,
          latitude: worker.latitude,
          longitude: worker.longitude,
        );
        return DeliveryPerson.fromJson(created['deliveryWorker']);
      }
    } catch (e) {
      throw Exception('Error saving delivery worker: $e');
    }
  }

  // Update delivery worker location
  static Future<void> updateDeliveryWorkerLocation(String userId, double latitude, double longitude) async {
    try {
      await updateDeliveryWorker(userId, latitude: latitude, longitude: longitude);
    } catch (e) {
      throw Exception('Error updating location: $e');
    }
  }

  // Update delivery worker availability
  static Future<void> updateDeliveryWorkerAvailability(String userId, bool isAvailable) async {
    try {
      final status = isAvailable ? 'متاح' : 'غير متاح';
      print('Updating delivery worker availability - userId: $userId, isAvailable: $isAvailable, status: $status');
      await updateDeliveryWorker(userId, status: status, isAvailable: isAvailable);
      print('Delivery worker availability updated successfully');
    } catch (e) {
      print('Error updating delivery worker availability: $e');
      throw Exception('Error updating availability: $e');
    }
  }

  // Update delivery worker FCM token
  static Future<void> updateDeliveryWorkerToken(String userId, String fcmToken) async {
    try {
      await updateDeliveryWorker(userId, fcmToken: fcmToken);
    } catch (e) {
      throw Exception('Error updating token: $e');
    }
  }

  // Get available delivery workers
  static Future<List<DeliveryPerson>> getAvailableDeliveryWorkers() async {
    try {
      final allWorkers = await getAllDeliveryWorkers();
      final availableWorkers = allWorkers.where((worker) => 
        worker['status'] == 'متاح'
      ).map((worker) => DeliveryPerson.fromJson(worker)).toList();
      
      return availableWorkers;
    } catch (e) {
      throw Exception('Error fetching available workers: $e');
    }
  }

  // ========== USER METHODS ==========

  // Get user by ID
  static Future<Map<String, dynamic>?> getUser(String userId) async {
    try {
      final response = await _makeRequest('$baseUrl/users/$userId', 'GET');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load user: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  // Get customer name
  static Future<String> getCustomerName(String userId) async {
    try {
      final user = await getUser(userId);
      return user?['fullName'] ?? 'غير معروف';
    } catch (e) {
      return 'غير معروف';
    }
  }

  // Get customer phone
  static Future<String> getCustomerPhone(String userId) async {
    try {
      final user = await getUser(userId);
      return user?['phoneNumber'] ?? 'غير متوفر';
    } catch (e) {
      return 'غير متوفر';
    }
  }

  // ========== STORE ORDERS METHODS ==========

  // Get store orders by main order ID (for backward compatibility with string orderId)
  static Future<List<Map<String, dynamic>>> getStoreOrdersByMainOrderIdString(String orderId) async {
    try {
      print('[ApiService] Getting store orders for orderId: $orderId');
      final order = await getOrderById(orderId);
      if (order != null) {
        print('[ApiService] Order found: ${order.toJson()}');
        // Convert the main order to store order format for backward compatibility
        return [{
          'storeId': order.storeId,
          'items': order.items,
          'totalPrice': order.totalPrice,
          'status': order.orderStatus,
          'deliveryDetails': {
            'address': order.deliveryAddress,
            'cost': order.deliveryCost,
            'location': order.deliveryLocation,
          },
          'notes': '', // Add notes field if needed
        }];
      }
      print('[ApiService] Order not found for orderId: $orderId');
      return [];
    } catch (e) {
      print('[ApiService] Error getting store orders for orderId $orderId: $e');
      return [];
    }
  }

  // Get store details by store ID and type
  static Future<Map<String, dynamic>?> getStoreDetails(String storeId, String storeType) async {
    try {
      final response = await _makeRequest('$baseUrl/stores/$storeType/$storeId', 'GET');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load store details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching store details: $e');
      return null;
    }
  }

  // ========== UTILITY METHODS ==========

  // Check if order exists
  static Future<bool> orderExists(String orderId) async {
    try {
      await getOrderById(orderId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Get order status
  static Future<String> getOrderStatus(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      return order.orderStatus;
    } catch (e) {
      return '';
    }
  }

  // Update order status
  static Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final order = await getOrderById(orderId);
      final updatedOrder = order.copyWith(
        orderStatus: status,
        updatedAt: DateTime.now(),
      );
      await updateOrder(orderId, updatedOrder);
    } catch (e) {
      throw Exception('Error updating order status: $e');
    }
  }
}

