import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order.dart';
import '../models/delivery_person.dart';
import '../models/store_order.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'https://backend-jm4h.onrender.com/api';
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Helper method for making HTTP requests with retry logic
  static Future<String?> getToken() async {
    // Try Firebase token first
    final firebaseToken = await AuthService.getFirebaseToken();
    if (firebaseToken != null) {
      return firebaseToken;
    }
    
    // Fallback to custom token
    final customToken = await AuthService.getCustomToken();
    return customToken;
  }

  static Future<http.Response> _makeRequest(
    String url,
    String method, {
    Map<String, dynamic>? body,
  }) async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      // Temporarily remove authentication to test backend
      // if (token != null) 'Authorization': 'Bearer $token',
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
        print('[ApiService] Response body: ${response.body}');
        
        if (response.statusCode == 401) {
          print('[ApiService] 401 Unauthorized - Token might be invalid or missing');
          // For now, let's continue with the request even if we get 401
          // This will help us test if the backend works without authentication
        }

        // Handle 502 Bad Gateway specifically
        if (response.statusCode == 502) {
          print('[ApiService] 502 Bad Gateway - Backend server issue detected');
          if (retryCount < maxRetries - 1) {
            retryCount++;
            print('[ApiService] Retrying in ${retryCount * 3} seconds... (attempt ${retryCount}/${maxRetries})');
            await Future.delayed(Duration(seconds: retryCount * 3)); // Longer delay for 502
            continue;
          } else {
            print('[ApiService] Max retries reached for 502 error');
            throw Exception('Backend server is temporarily unavailable (502). Please try again later.');
          }
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          return response;
        } else if (response.statusCode >= 500 && retryCount < maxRetries - 1) {
          // Retry on server errors
          retryCount++;
          print('[ApiService] Server error ${response.statusCode}, retrying in ${retryCount * 2} seconds... (attempt ${retryCount}/${maxRetries})');
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          continue;
        } else {
          return response;
        }
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          retryCount++;
          print('[ApiService] Network error, retrying in ${retryCount * 2} seconds... (attempt ${retryCount}/${maxRetries})');
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }
        throw Exception('Network error: $e');
      }
    }
    
    throw Exception('Max retries exceeded');
  }

  // Backend health check method
  static Future<Map<String, dynamic>> checkBackendHealth() async {
    try {
      print('[ApiService] Checking backend health...');
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 10));

      print('[ApiService] Health check status: ${response.statusCode}');
      print('[ApiService] Health check body: ${response.body}');

      return {
        'status': response.statusCode,
        'healthy': response.statusCode == 200,
        'body': response.body,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('[ApiService] Health check failed: $e');
      return {
        'status': 'error',
        'healthy': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Test backend connection with detailed logging
  static Future<Map<String, dynamic>> testBackendConnection() async {
    try {
      print('[ApiService] Testing backend connection...');
      
      // Test basic connectivity
      final response = await http.get(
        Uri.parse('$baseUrl/order'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 15));

      print('[ApiService] Connection test status: ${response.statusCode}');
      print('[ApiService] Connection test headers: ${response.headers}');
      print('[ApiService] Connection test body length: ${response.body.length}');

      return {
        'status': response.statusCode,
        'connected': response.statusCode < 500,
        'bodyLength': response.body.length,
        'headers': response.headers,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('[ApiService] Connection test failed: $e');
      return {
        'status': 'error',
        'connected': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // ========== ORDER METHODS ==========

  // Get all orders
  static Future<List<Order>> getOrders() async {
    try {
           final response = await _makeRequest('$baseUrl/order', 'GET');

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = json.decode(response.body);
        return ordersJson.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching orders: $e');
    }
  }
  // Get nearby orders for delivery workers (temporary solution)
  static Future<List<Order>> getNearbyOrders({
    required double latitude,
    required double longitude,
    double radiusInKm = 5.0,
    String? deliveryWorkerId,
    String? status, // Status parameter (will be used when backend is updated)
  }) async {
    try {
      print('[ApiService] Getting nearby orders for location: $latitude, $longitude, radius: ${radiusInKm}km, worker: $deliveryWorkerId, status: $status');
      
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radiusInKm': radiusInKm.toString(),
      };

      // TODO: Add status parameter when backend is updated
      // if (status != null) {
      //   queryParams['status'] = status;
      // }

      final uri = Uri.parse('$baseUrl/order/nearby-orders').replace(queryParameters: queryParams);
      final response = await _makeRequest(uri.toString(), 'GET');

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = json.decode(response.body);
        final allOrders = ordersJson.map((json) => Order.fromJson(json)).toList();
        
        // Filter orders by delivery worker
        final filteredOrders = allOrders.where((order) {
          // Show orders that are either:
          // 1. Not assigned to anyone (unassigned orders)
          // 2. Assigned to the current delivery worker
          final isUnassigned = order.assignedTo == null;
          final isAssignedToMe = deliveryWorkerId != null && order.assignedTo == deliveryWorkerId;
          
          return isUnassigned || isAssignedToMe;
        }).toList();
        
        // TODO: Filter by status when backend supports it
        // For now, we'll filter by status on the client side
        List<Order> statusFilteredOrders = filteredOrders;
        if (status != null) {
          statusFilteredOrders = filteredOrders.where((order) => order.orderStatus == status).toList();
          print('[ApiService] Filtered by status "$status": ${filteredOrders.length} -> ${statusFilteredOrders.length} orders');
        }
        
        print('[ApiService] Found ${allOrders.length} nearby orders, filtered to ${filteredOrders.length} for worker $deliveryWorkerId, status filtered to ${statusFilteredOrders.length}');
        return statusFilteredOrders;
      } else {
        throw Exception('Failed to load nearby orders: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Error fetching nearby orders: $e');
      throw Exception('Error fetching nearby orders: $e');
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
      final response = await _makeRequest('$baseUrl/order/byOrderId/$orderId', 'GET');
      
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
        '$baseUrl/order',
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
      final response = await _makeRequest('$baseUrl/order/$id', 'DELETE');
      
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
      final response = await _makeRequest('$baseUrl/order/user/$userId', 'GET');
      
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

  // Get orders by status and worker (updated to use nearby orders)
  static Future<List<Order>> getOrdersByStatusAndWorker(
    List<String> statuses,
    String deliveryWorkerId, {
    double? latitude,
    double? longitude,
    double radiusInKm = 5.0,
  }) async {
    try {
      // If location is provided, use nearby orders endpoint
      if (latitude != null && longitude != null) {
        print('[ApiService] Using nearby orders endpoint for worker: $deliveryWorkerId');
        
        // Use the first status from the list, or fallback to 'قيد الانتظار'
        final status = statuses.isNotEmpty ? statuses.first : 'قيد الانتظار';
        
        return await getNearbyOrders(
          latitude: latitude,
          longitude: longitude,
          radiusInKm: radiusInKm,
          deliveryWorkerId: deliveryWorkerId,
          status: status,
        );
      }

      // Fallback to regular orders endpoint
      print('[ApiService] Using regular orders endpoint for worker: $deliveryWorkerId');
      final response = await _makeRequest('$baseUrl/order', 'GET');

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = json.decode(response.body);
        final allOrders = ordersJson.map((json) => Order.fromJson(json)).toList();
        
        // Filter by status and worker
        return allOrders.where((order) {
          final statusMatch = statuses.contains(order.orderStatus);
          final workerMatch = order.assignedTo == deliveryWorkerId || order.assignedTo == null;
          return statusMatch && workerMatch;
        }).toList();
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('[ApiService] Error fetching orders by status and worker: $e');
      throw Exception('Error fetching orders by status and worker: $e');
    }
  }

  // Get orders for delivery (not assigned or assigned to specific worker)
  static Future<List<Order>> getDeliveryOrders(String? deliveryWorkerId) async {
    try {
      final allOrders = await getOrders();
      
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
  static Future<Map<String, dynamic>?> getDeliveryWorkerById(String id) async {
    try {
      print('[ApiService] Making GET request to: $baseUrl/deliveryworkers/$id');
      final response = await _makeRequest('$baseUrl/deliveryworkers/$id', 'GET');
      
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

  // Debug method to test nearby orders endpoint
  static Future<void> debugNearbyOrders({
    required double latitude,
    required double longitude,
    double radiusInKm = 5.0,
  }) async {
    try {
      print('[ApiService] DEBUG: Testing nearby orders endpoint');
      
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radiusInKm': radiusInKm.toString(),
      };

      final uri = Uri.parse('$baseUrl/order/nearby-orders').replace(queryParameters: queryParams);
      print('[ApiService] DEBUG: Requesting URL: $uri');
      
      final response = await _makeRequest(uri.toString(), 'GET');

      print('[ApiService] DEBUG: Response status: ${response.statusCode}');
      print('[ApiService] DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = json.decode(response.body);
        print('[ApiService] DEBUG: Found ${ordersJson.length} orders from backend');
        
        for (int i = 0; i < ordersJson.length; i++) {
          final order = ordersJson[i];
          print('[ApiService] DEBUG: Order $i - ID: ${order['orderId']}, Status: ${order['orderStatus']}, AssignedTo: ${order['assignedTo']}');
        }
      }
    } catch (e) {
      print('[ApiService] DEBUG: Error testing nearby orders: $e');
    }
  }
 
}

