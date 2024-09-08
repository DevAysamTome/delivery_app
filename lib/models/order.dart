import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String orderId;
  final String orderStatus;
  final String storeId;
  final String userId;
  final double totalPrice;
  final DateTime orderEndTime;
  final List<Map<String, dynamic>> items;
  final List<double> restaurantLocation;
  final List<double> userLocation;
  final String placeName;
  final List<String> selectedAddOns;

  Order({
    required this.orderId,
    required this.orderStatus,
    required this.storeId,
    required this.userId,
    required this.totalPrice,
    required this.orderEndTime,
    required this.items,
    required this.restaurantLocation,
    required this.userLocation,
    required this.placeName,
    required this.selectedAddOns,
  });

  factory Order.fromFirestore(Map<String, dynamic> data) {
    return Order(
      orderId: data['orderId'] ?? '',
      orderStatus: data['orderStatus'] ?? '',
      storeId: data['storeId'] ?? '',
      userId: data['userId'] ?? '',
      totalPrice: data['totalPrice']?.toDouble() ?? 0.0,
      orderEndTime: (data['orderEndTime'] as Timestamp).toDate(),
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      restaurantLocation: List<double>.from(data['restaurantLocation'] ?? []),
      userLocation: List<double>.from(data['userLocation'] ?? []),
      placeName: data['placeName'] ?? '',
      selectedAddOns: List<String>.from(data['selectedAddOns'] ?? []),
    );
  }
}
