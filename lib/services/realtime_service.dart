import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../models/delivery_person.dart';

class RealtimeService {
  static const String baseUrl = 'https://backend-jm4h.onrender.com/api';
  static const Duration pollingInterval = Duration(seconds: 10);
  
  static final Map<String, StreamController<dynamic>> _controllers = {};
  static final Map<String, Timer> _timers = {};

  // Generic polling method
  static Stream<T> _createPollingStream<T>(
    String key,
    Future<T> Function() fetchFunction,
  ) {
    if (_controllers.containsKey(key)) {
      _controllers[key]!.close();
    }

    final controller = StreamController<T>();
    _controllers[key] = controller;

    // Initial fetch
    fetchFunction().then((data) {
      if (!controller.isClosed) {
        controller.add(data);
      }
    }).catchError((error) {
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    // Set up periodic polling
    _timers[key] = Timer.periodic(pollingInterval, (_) {
      fetchFunction().then((data) {
        if (!controller.isClosed) {
          controller.add(data);
        }
      }).catchError((error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      });
    });

    return controller.stream;
  }

  // Stream for orders by status and worker
  static Stream<List<Order>> ordersByStatusAndWorker(
    List<String> statuses,
    String deliveryWorkerId,
  ) {
    final key = 'orders_${statuses.join('_')}_$deliveryWorkerId';
    
    return _createPollingStream<List<Order>>(
      key,
      () async {
        final response = await http.get(
          Uri.parse('$baseUrl/orders'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final allOrders = data.map((json) => Order.fromJson(json)).toList();
          
          // Filter by status and delivery worker
          return allOrders.where((order) {
            final hasMatchingStatus = statuses.contains(order.orderStatus);
            final isAssignedToWorker = order.assignedTo == deliveryWorkerId;
            final isDeliveryOrder = order.deliveryOption == 'delivery';
            
            return hasMatchingStatus && isAssignedToWorker && isDeliveryOrder;
          }).toList();
        } else {
          throw Exception('Failed to load orders: ${response.statusCode}');
        }
      },
    );
  }

  // Stream for delivery worker status
  static Stream<DeliveryPerson?> deliveryWorkerStatus(String userId) {
    final key = 'delivery_worker_$userId';
    
    return _createPollingStream<DeliveryPerson?>(
      key,
      () async {
        final response = await http.get(
          Uri.parse('$baseUrl/delivery-workers/user/$userId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return DeliveryPerson.fromJson(data);
        } else if (response.statusCode == 404) {
          return null;
        } else {
          throw Exception('Failed to load delivery worker: ${response.statusCode}');
        }
      },
    );
  }

  // Stream for available delivery workers
  static Stream<List<DeliveryPerson>> availableDeliveryWorkers() {
    const key = 'available_delivery_workers';
    
    return _createPollingStream<List<DeliveryPerson>>(
      key,
      () async {
        final response = await http.get(
          Uri.parse('$baseUrl/delivery-workers/available'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => DeliveryPerson.fromJson(json)).toList();
        } else {
          throw Exception('Failed to load available delivery workers: ${response.statusCode}');
        }
      },
    );
  }

  // Stream for order count
  static Stream<int> orderCount(
    List<String> statuses,
    String deliveryWorkerId,
  ) {
    final key = 'order_count_${statuses.join('_')}_$deliveryWorkerId';
    
    return _createPollingStream<int>(
      key,
      () async {
        final response = await http.get(
          Uri.parse('$baseUrl/orders'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final allOrders = data.map((json) => Order.fromJson(json)).toList();
          
          // Filter and count
          return allOrders.where((order) {
            final hasMatchingStatus = statuses.contains(order.orderStatus);
            final isAssignedToWorker = order.assignedTo == deliveryWorkerId;
            final isDeliveryOrder = order.deliveryOption == 'delivery';
            
            return hasMatchingStatus && isAssignedToWorker && isDeliveryOrder;
          }).length;
        } else {
          throw Exception('Failed to load orders: ${response.statusCode}');
        }
      },
    );
  }

  // Dispose all streams and timers
  static void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();

    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  // Dispose specific stream
  static void disposeStream(String key) {
    _controllers[key]?.close();
    _controllers.remove(key);
    
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  // Update polling interval
  static void updatePollingInterval(Duration newInterval) {
    // Cancel existing timers
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    // Recreate timers with new interval
    for (final key in _controllers.keys) {
      _timers[key] = Timer.periodic(newInterval, (_) {
        // This will be handled by the individual stream implementations
      });
    }
  }
} 